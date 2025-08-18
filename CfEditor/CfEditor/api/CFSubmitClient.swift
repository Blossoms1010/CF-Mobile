import Foundation

enum CFSubmitError: LocalizedError {
    case notLoggedIn
    case invalidProblem
    case failedToLoadSubmitPage
    case missingCsrf
    case missingLanguage
    case network(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn: return "未登录 Codeforces。"
        case .invalidProblem: return "无法识别题号（需要 contestId 和 index）。"
        case .failedToLoadSubmitPage: return "加载提交页失败。"
        case .missingCsrf: return "无法获取 CSRF，可能未登录。"
        case .missingLanguage: return "无法匹配提交语言。"
        case .network(let s): return "网络错误：\(s)"
        case .server(let s): return s
        }
    }
}

enum CFSubmitClient {
    // MARK: - Session with Safari-like UA
    private static let uaDesktopSafari = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    private static let uaMobileSafari = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    private static let preferredUA = uaDesktopSafari

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.httpCookieStorage = HTTPCookieStorage.shared
        cfg.httpShouldSetCookies = true
        cfg.httpCookieAcceptPolicy = .always
        cfg.waitsForConnectivity = true
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 45
        cfg.httpAdditionalHeaders = [
            "User-Agent": preferredUA,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7"
        ]
        return URLSession(configuration: cfg)
    }()

    // MARK: - Retry helpers
    private static func sleep(seconds: Double) async {
        let ns = UInt64(seconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: ns)
    }

    private static func performRequestWithRetries(_ build: @escaping () -> URLRequest,
                                                  acceptableStatus: Range<Int> = 200..<400,
                                                  maxAttempts: Int = 3,
                                                  classify429AsRetry: Bool = true) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error?
        var attempt = 0
        while attempt < maxAttempts {
            attempt += 1
            await CFCookieBridge.shared.syncFromWKToHTTPCookieStorage()
            do {
                let req = build()
                let (data, resp) = try await session.data(for: req)
                guard let http = resp as? HTTPURLResponse else { throw CFSubmitError.network("无效响应") }

                // Handle 429 with Retry-After when allowed
                if http.statusCode == 429 && classify429AsRetry && attempt < maxAttempts {
                    let retryAfterSec: Double = {
                        if let v = http.value(forHTTPHeaderField: "Retry-After"), let s = Double(v) { return min(max(s, 1.0), 10.0) }
                        return 2.0
                    }()
                    await sleep(seconds: retryAfterSec + Double.random(in: 0.2...0.6))
                    continue
                }

                // Retry on 5xx server errors
                if (500..<600).contains(http.statusCode) && attempt < maxAttempts {
                    await sleep(seconds: Double(attempt))
                    continue
                }

                if acceptableStatus.contains(http.statusCode) {
                    return (data, http)
                }
                // For non acceptable status and no more retries
                if http.statusCode == 429 {
                    throw CFSubmitError.network("提交过于频繁，请稍后再试。")
                }
                throw CFSubmitError.server("HTTP \(http.statusCode)")
            } catch {
                lastError = error
                // Retry on transient network errors
                if let urlError = error as? URLError {
                    let transientCodes: Set<URLError.Code> = [.timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed, .notConnectedToInternet]
                    if transientCodes.contains(urlError.code) && attempt < maxAttempts {
                        await sleep(seconds: 0.6 * pow(1.6, Double(attempt-1)) + Double.random(in: 0.0...0.3))
                        continue
                    }
                }
                break
            }
        }
        if let e = lastError { throw e }
        throw CFSubmitError.network("网络异常")
    }

    // MARK: - Helpers
    private static func isLoginHTML(_ html: String) -> Bool {
        let lowered = html.lowercased()
        return lowered.contains("/enter") || lowered.contains("name=\"handleoremail\"") || lowered.contains("id=\"enterform\"")
    }

    private static func isCloudflareChallenge(_ html: String) -> Bool {
        let lowered = html.lowercased()
        if lowered.contains("cf-please-wait") { return true }
        if lowered.contains("checking your browser before accessing") { return true }
        if lowered.contains("just a moment") { return true }
        return false
    }

    // 将响应二进制尽力解码为 HTML 文本
    private static func decodeHTML(_ data: Data) -> String? {
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .windowsCP1251) { return s }
        if let s = String(data: data, encoding: .isoLatin1) { return s }
        return nil
    }

    // 提交后，页面返回的常见错误解析（返回用户可读的错误信息）
    private static func extractSubmitError(from html: String) -> String? {
        let lowered = html.lowercased()
        // 未登录/登录过期
        if isLoginHTML(html) { return "未登录 Codeforces。" }
        if isCloudflareChallenge(html) { return "需要先通过 Cloudflare 验证。请在内置浏览器打开 Codeforces 任意页面等待验证完成后再试。" }

        // 过于频繁 / 限流
        if lowered.contains("too many") || lowered.contains("too frequent") || lowered.contains("too fast") {
            return "提交过于频繁，请稍后再试。"
        }
        if lowered.contains("rate limit") { return "提交过于频繁，请稍后再试。" }

        // 与上一次完全相同的代码
        if lowered.contains("submitted exactly the same") || lowered.contains("exactly the same solution") {
            return "与上一份代码完全相同，Codeforces 拒绝重复提交。请稍作修改或等待一段时间后再试。"
        }

        // 源码长度等表单错误提示（提取常见 error 容器）
        if let msg = firstMatch("<span[^>]*class=(?:\\\"|')(?=[^>]*error)[^>]*>([\\\\s\\\\S]*?)</span>", in: html) {
            let t = msg.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        if let msg = firstMatch("<div[^>]*class=(?:\\\"|')(?=[^>]*alert)(?=[^>]*danger)[^>]*>([\\\\s\\\\S]*?)</div>", in: html) {
            let t = msg.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        return nil
    }

    private static func getSubmitPageHTML(contestId: Int, index: String) async throws -> String {
        let normalizedIndex = index.uppercased()
        await CFCookieBridge.shared.syncFromWKToHTTPCookieStorage()
        guard let submitURL = URL(string: "https://codeforces.com/contest/\(contestId)/submit?submittedProblemIndex=\(normalizedIndex)") else {
            throw CFSubmitError.invalidProblem
        }
        let build: () -> URLRequest = {
            var req = URLRequest(url: submitURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            req.setValue("https://codeforces.com/contest/\(contestId)/problem/\(normalizedIndex)", forHTTPHeaderField: "Referer")
            req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            return req
        }
        do {
            let (data, _) = try await performRequestWithRetries(build, acceptableStatus: 200..<400, maxAttempts: 3)
            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251) else {
                throw CFSubmitError.failedToLoadSubmitPage
            }
            if isCloudflareChallenge(html) {
                throw CFSubmitError.network("需要先通过 Cloudflare 验证。请在内置浏览器打开 Codeforces 任意页面等待验证完成后再试。")
            }
            if isLoginHTML(html) {
                throw CFSubmitError.notLoggedIn
            }
            return html
        } catch let e as CFSubmitError {
            throw e
        } catch {
            throw CFSubmitError.network(error.localizedDescription)
        }
    }
    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        if let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
            let range = NSRange(location: 0, length: (text as NSString).length)
            if let m = re.firstMatch(in: text, options: [], range: range), m.numberOfRanges >= 2 {
                let r = m.range(at: 1)
                if let swiftRange = Range(r, in: text) { return String(text[swiftRange]) }
            }
        }
        return nil
    }

    private static func programTypeId(from html: String, contestId: Int, index: String, languageKey: String) -> String? {
        // 抓取 <select name="programTypeId"> 内所有 <option value="ID">文本</option>
        // 兼容单/双引号与任意换行/空白
        guard let selectHTML = firstMatch("(<select[^>]*name=(?:\\\"|')programTypeId(?:\\\"|')[\\s\\S]*?</select>)", in: html) else {
            return nil
        }
        let optionRegex = try? NSRegularExpression(pattern: "<option[^>]*value=(?:\\\"|')(\\d+)(?:\\\"|')[^>]*>\\s*([\\s\\S]*?)\\s*</option>", options: [.caseInsensitive])
        let ns = selectHTML as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = optionRegex?.matches(in: selectHTML, options: [], range: range) ?? []
        var options: [(id: String, text: String)] = []
        for m in matches {
            if m.numberOfRanges >= 3 {
                let id = ns.substring(with: m.range(at: 1))
                let text = ns.substring(with: m.range(at: 2))
                options.append((id, text))
            }
        }
        if options.isEmpty { return nil }

        func score(_ text: String) -> Int {
            let t = text.lowercased()
            switch languageKey {
            case "cpp":
                var s = 0
                if t.contains("c++") || t.contains("g++") { s += 6 }
                if t.contains("gnu") { s += 3 }
                if t.contains("20") { s += 4 }
                else if t.contains("17") { s += 3 }
                else if t.contains("11") { s += 1 }
                if t.contains("64") { s += 1 }
                if t.contains("clang") { s -= 4 }
                if t.contains("mingw") { s -= 2 }
                return s
            case "python":
                var s = 0
                if t.contains("python") || t.contains("pypy") { s += 6 }
                if t.contains("3") { s += 4 }
                if t.contains("pypy") { s += 2 }
                if t.contains("64") { s += 1 }
                if t.contains("2") { s -= 8 }
                return s
            case "java":
                var s = 0
                if t.contains("java") { s += 6 }
                if t.contains("21") { s += 4 }
                else if t.contains("17") { s += 3 }
                else if t.contains("11") { s += 2 }
                if t.contains("openjdk") || t.contains("jdk") { s += 1 }
                return s
            default:
                return 0
            }
        }

        // 如果有历史偏好，优先使用且确保仍在可选项中
        if let preferred = preferredProgramTypeId(contestId: contestId, index: index, languageKey: languageKey), options.contains(where: { $0.id == preferred }) {
            return preferred
        }

        let chosen = options.max(by: { score($0.text) < score($1.text) })?.id
        if let cid = chosen {
            savePreferredProgramTypeId(cid, contestId: contestId, index: index, languageKey: languageKey)
        }
        return chosen
    }

    private static func preferredKey(contestId: Int, index: String, languageKey: String) -> String {
        "CF.pref.programTypeId.\(contestId).\(index.uppercased()).\(languageKey)"
    }
    private static func savePreferredProgramTypeId(_ id: String, contestId: Int, index: String, languageKey: String) {
        let key = preferredKey(contestId: contestId, index: index, languageKey: languageKey)
        UserDefaults.standard.set(id, forKey: key)
    }
    private static func preferredProgramTypeId(contestId: Int, index: String, languageKey: String) -> String? {
        let key = preferredKey(contestId: contestId, index: index, languageKey: languageKey)
        return UserDefaults.standard.string(forKey: key)
    }

    private static func extractTokens(from html: String) -> (csrf: String?, ftaa: String?, bfaa: String?) {
        let csrf = firstMatch("<meta[^>]+name=\\\"X-Csrf-Token\\\"[^>]+content=\\\"([^\\\"]+)\\\"", in: html)
            ?? firstMatch("name=\\\"csrf_token\\\"[^>]*value=\\\"([^\\\"]+)\\\"", in: html)
        let ftaa = firstMatch("name=\\\"ftaa\\\"[^>]*value=\\\"([^\\\"]*)\\\"", in: html)
        let bfaa = firstMatch("name=\\\"bfaa\\\"[^>]*value=\\\"([^\\\"]*)\\\"", in: html)
        return (csrf, ftaa, bfaa)
    }

    static func submit(contestId: Int, index: String, sourceCode: String, languageKey: String) async throws {
        do {
            let html = try await getSubmitPageHTML(contestId: contestId, index: index)
            let tokens = extractTokens(from: html)
            guard let csrf = tokens.csrf, !csrf.isEmpty else { throw CFSubmitError.missingCsrf }
            guard let progId = programTypeId(from: html, contestId: contestId, index: index, languageKey: languageKey) else { throw CFSubmitError.missingLanguage }

            // POST 提交
            let normalizedIndex = index.uppercased()
            guard let postURL = URL(string: "https://codeforces.com/contest/\(contestId)/submit?csrf_token=\(csrf)") else {
                throw CFSubmitError.invalidProblem
            }
            var comps = URLComponents()
            comps.queryItems = [
                URLQueryItem(name: "csrf_token", value: csrf),
                URLQueryItem(name: "ftaa", value: tokens.ftaa ?? ""),
                URLQueryItem(name: "bfaa", value: tokens.bfaa ?? ""),
                URLQueryItem(name: "contestId", value: String(contestId)),
                URLQueryItem(name: "submittedProblemIndex", value: normalizedIndex),
                URLQueryItem(name: "programTypeId", value: progId),
                URLQueryItem(name: "source", value: sourceCode),
                URLQueryItem(name: "tabSize", value: "4")
            ]
            let body = comps.percentEncodedQuery?.data(using: .utf8) ?? Data()
            let build: () -> URLRequest = {
                var postReq = URLRequest(url: postURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
                postReq.httpMethod = "POST"
                postReq.httpBody = body
                postReq.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
                postReq.setValue("https://codeforces.com/contest/\(contestId)/submit?submittedProblemIndex=\(normalizedIndex)", forHTTPHeaderField: "Referer")
                postReq.setValue("https://codeforces.com", forHTTPHeaderField: "Origin")
                postReq.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                return postReq
            }
            let (postData, http2) = try await performRequestWithRetries(build, acceptableStatus: 200..<400, maxAttempts: 3)
            // 提交后服务器通常会重定向到提交页或状态页；若最终页面含错误提示，显示给用户
            if let html = decodeHTML(postData), let msg = extractSubmitError(from: html) {
                throw CFSubmitError.server(msg)
            }
        } catch let e as CFSubmitError { throw e } catch { throw CFSubmitError.network(error.localizedDescription) }
    }

    // 直接按 programTypeId 提交（绕过语言匹配），用于用户从提交页精确选择的场景
    static func submit(contestId: Int, index: String, sourceCode: String, programTypeId: String) async throws {
        do {
            let html = try await getSubmitPageHTML(contestId: contestId, index: index)
            let tokens = extractTokens(from: html)
            guard let csrf = tokens.csrf, !csrf.isEmpty else { throw CFSubmitError.missingCsrf }

            let normalizedIndex = index.uppercased()
            guard let postURL = URL(string: "https://codeforces.com/contest/\(contestId)/submit?csrf_token=\(csrf)") else {
                throw CFSubmitError.invalidProblem
            }
            var comps = URLComponents()
            comps.queryItems = [
                URLQueryItem(name: "csrf_token", value: csrf),
                URLQueryItem(name: "ftaa", value: tokens.ftaa ?? ""),
                URLQueryItem(name: "bfaa", value: tokens.bfaa ?? ""),
                URLQueryItem(name: "contestId", value: String(contestId)),
                URLQueryItem(name: "submittedProblemIndex", value: normalizedIndex),
                URLQueryItem(name: "programTypeId", value: programTypeId),
                URLQueryItem(name: "source", value: sourceCode),
                URLQueryItem(name: "tabSize", value: "4")
            ]
            let body = comps.percentEncodedQuery?.data(using: .utf8) ?? Data()
            let build: () -> URLRequest = {
                var postReq = URLRequest(url: postURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
                postReq.httpMethod = "POST"
                postReq.httpBody = body
                postReq.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
                postReq.setValue("https://codeforces.com/contest/\(contestId)/submit?submittedProblemIndex=\(normalizedIndex)", forHTTPHeaderField: "Referer")
                postReq.setValue("https://codeforces.com", forHTTPHeaderField: "Origin")
                postReq.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                return postReq
            }
            let (postData, http2) = try await performRequestWithRetries(build, acceptableStatus: 200..<400, maxAttempts: 3)
            if let html = decodeHTML(postData), let msg = extractSubmitError(from: html) {
                throw CFSubmitError.server(msg)
            }
        } catch let e as CFSubmitError { throw e } catch { throw CFSubmitError.network(error.localizedDescription) }
    }

    // 读取提交页上语言下拉列表，返回 (id, 文本)
    static func fetchLanguageOptions(contestId: Int, index: String) async throws -> [(id: String, text: String)] {
        let html = try await getSubmitPageHTML(contestId: contestId, index: index)
        guard let selectHTML = firstMatch("(<select[^>]*name=(?:\\\"|')programTypeId(?:\\\"|')[\\s\\S]*?</select>)", in: html) else {
            throw CFSubmitError.missingLanguage
        }
        let optionRegex = try? NSRegularExpression(pattern: "<option[^>]*value=(?:\\\"|')(\\d+)(?:\\\"|')[^>]*>\\s*([\\s\\S]*?)\\s*</option>", options: [.caseInsensitive])
        let ns = selectHTML as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = optionRegex?.matches(in: selectHTML, options: [], range: range) ?? []
        var results: [(id: String, text: String)] = []
        for m in matches {
            if m.numberOfRanges >= 3 {
                let id = ns.substring(with: m.range(at: 1))
                let text = ns.substring(with: m.range(at: 2))
                results.append((id, text))
            }
        }
        if results.isEmpty { throw CFSubmitError.missingLanguage }
        return results
    }
}


