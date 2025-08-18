import Foundation
import CryptoKit

// MARK: - Error

enum CFError: LocalizedError, Sendable {
    case api(String)                // CF 返回 status=FAILED
    case badData                    // 解码失败
    case rateLimited                // 命中限流
    case network(String)            // 传输错误/超时
    case badURL

    var errorDescription: String? {
        switch self {
        case .api(let msg):     return "Codeforces API 错误：\(msg)"
        case .badData:          return "收到的数据格式不符合预期。"
        case .rateLimited:      return "请求太频繁，请稍后再试。"
        case .network(let msg): return "网络错误：\(msg)"
        case .badURL:           return "URL 构造失败。"
        }
    }
}

// MARK: - Wire Models

struct CFResponse<T: Decodable>: Decodable {
    let status: String
    let comment: String?
    let result: T?
}

// 你已有模型（补上 Sendable 以便并发友好）
struct CFContest: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let phase: String?
    let startTimeSeconds: Int?
}

struct CFProblem: Identifiable, Decodable, Sendable, Hashable {
    var id: String { "\(contestId ?? -1)-\(index)" }
    let contestId: Int?
    let index: String
    let name: String
    let type: String?
    let rating: Int?
    let tags: [String]?
}

struct CFSubmission: Decodable, Identifiable, Sendable {
    let id: Int
    let contestId: Int?
    let creationTimeSeconds: Int
    let problem: CFProblem
    let verdict: String?
    // Optional fields used by status view; present in contest.status/user.status payloads
    let relativeTimeSeconds: Int?
    let programmingLanguage: String?
    let testset: String?
    let passedTestCount: Int?
    let timeConsumedMillis: Int?
    let memoryConsumedBytes: Int?
}

struct CFUserInfo: Decodable, Sendable {
    let handle: String
    let rating: Int?
    let maxRating: Int?
    let rank: String?
    let maxRank: String?
    let avatar: String?
    let titlePhoto: String?
}

struct CFRatingUpdate: Decodable, Identifiable, Sendable {
    var id: Int { contestId }
    let contestId: Int
    let contestName: String
    let handle: String
    let rank: Int
    let ratingUpdateTimeSeconds: Int
    let oldRating: Int
    let newRating: Int
}

struct CFStandings: Decodable, Sendable {
    let problems: [CFProblem]
}

struct ContestSummary: Sendable {
    let problems: [CFProblem]
    let solved: Int
}

// MARK: - Small Helpers

private extension URL {
    static func cfAPIBase() -> URL { URL(string: "https://codeforces.com/api/")! }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Rate Limiter (2s/req)

actor CFRateLimiter {
    private var last: Date = .distantPast
    private let minInterval: TimeInterval = 2

    func waitIfNeeded() async {
        let gap = Date().timeIntervalSince(last)
        if gap < minInterval {
            try? await Task.sleep(nanoseconds: UInt64((minInterval - gap) * 1_000_000_000))
        }
        last = Date()
    }
}

// MARK: - Memory Cache with TTL

actor CFMemoryCache {
    private var store: [String: (data: Data, expiry: Date)] = [:]

    func get(_ key: String) -> Data? {
        guard let (data, expiry) = store[key], expiry > Date() else {
            store[key] = nil
            return nil
        }
        return data
    }

    func set(_ key: String, data: Data, ttl: TimeInterval) {
        guard ttl > 0 else { return }
        store[key] = (data, Date().addingTimeInterval(ttl))
    }

    func clear() { store.removeAll() }
}

// MARK: - API Core

actor CFAPI {
    static let shared = CFAPI()

    private let base = URL.cfAPIBase()
    private let decoder = JSONDecoder()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 30
        cfg.waitsForConnectivity = true
        cfg.httpCookieStorage = HTTPCookieStorage.shared
        cfg.httpCookieAcceptPolicy = .always
        cfg.httpShouldSetCookies = true
        cfg.httpAdditionalHeaders = [
            "User-Agent": "CF-iOS-Client/1.0 (+ios; SwiftUI)"
        ]
        return URLSession(configuration: cfg)
    }()

    private let limiter = CFRateLimiter()
    private let cache = CFMemoryCache()

    // 在飞请求去重：key -> Task<Data, Error>
    private var inflight: [String: Task<Data, Error>] = [:]

    // 可选签名
    private var apiKey: String?
    private var apiSecret: String?

    func configure(apiKey: String?, apiSecret: String?) {
        self.apiKey = apiKey?.trimmed.isEmpty == false ? apiKey : nil
        self.apiSecret = apiSecret?.trimmed.isEmpty == false ? apiSecret : nil
    }

    // 清理所有易变状态（切换账号/软重启前调用）
    func resetSession() async {
        await cache.clear()
        inflight.removeAll()
        apiKey = nil
        apiSecret = nil
    }

    // MARK: - Public Endpoints（与原方法名保持一致）
    
    // 精确获取某场比赛的 AC 数（去重按题号）
    func contestSolvedCount(contestId: Int, handle: String, forceRefresh: Bool = false) async throws -> Int {
        let submissions: [CFSubmission] = try await get(method: "contest.status", params: [
            "contestId": String(contestId),
            "handle": handle
        ], forceRefresh: forceRefresh)
        let accepted = submissions.filter { $0.verdict == "OK" }
        return Set(accepted.map { $0.problem.index }).count
    }
    

    func recentContests(limit: Int = 20) async throws -> [CFContest] {
        let all = try await allFinishedContests()
        return Array(all.prefix(limit))
    }

    // 新增：获取所有 FINISHED 的比赛列表（用于分页展示的本地分页）
    func allFinishedContests(forceRefresh: Bool = false) async throws -> [CFContest] {
        let all: [CFContest] = try await get(method: "contest.list", forceRefresh: forceRefresh)
        return all.filter { $0.phase == "FINISHED" }
    }

    func userAllSubmissions(handle: String, forceRefresh: Bool = false) async throws -> [CFSubmission] {
        try await get(method: "user.status", params: [
            "handle": handle,
            "from": "1",
            "count": "5000"
        ], forceRefresh: forceRefresh)
    }

    func userSubmissionsLite(handle: String, count: Int = 3000, forceRefresh: Bool = false) async throws -> [CFSubmission] {
        let capped = max(1, min(count, 10000))
        return try await get(method: "user.status", params: [
            "handle": handle,
            "from": "1",
            "count": String(capped)
        ], forceRefresh: forceRefresh)
    }

    // 分页获取用户提交：CF 支持 from(1-based) + count 参数
    func userSubmissionsPage(handle: String, from: Int, count: Int, forceRefresh: Bool = false) async throws -> [CFSubmission] {
        let safeFrom = max(1, from)
        let safeCount = max(1, min(count, 1000)) // 单页不宜过大，避免响应过慢
        return try await get(method: "user.status", params: [
            "handle": handle,
            "from": String(safeFrom),
            "count": String(safeCount)
        ], forceRefresh: forceRefresh)
    }

    func contestProblems(contestId: Int, forceRefresh: Bool = false) async throws -> [CFProblem] {
        let standings: CFStandings = try await get(method: "contest.standings", params: [
            "contestId": String(contestId),
            "from": "1",
            "count": "1",
            "showUnofficial": "false"
        ], forceRefresh: forceRefresh)
        return standings.problems.map { p in
            CFProblem(contestId: contestId, index: p.index, name: p.name,
                      type: p.type, rating: p.rating, tags: p.tags)
        }
    }

    func contestSummary(contestId: Int, handle: String) async throws -> ContestSummary {
        async let problemsTask: [CFProblem] = {
            let s: CFStandings = try await get(method: "contest.standings", params: [
                "contestId": String(contestId),
                "from": "1",
                "count": "1",
                "showUnofficial": "false"
            ])
            return s.problems.map { p in
                CFProblem(contestId: contestId, index: p.index, name: p.name,
                          type: p.type, rating: p.rating, tags: p.tags)
            }
        }()

        async let solvedTask: Int = {
            let submissions: [CFSubmission] = try await get(method: "contest.status", params: [
                "contestId": String(contestId),
                "handle": handle
            ])
            let accepted = submissions.filter { $0.verdict == "OK" }
            return Set(accepted.map { $0.problem.index }).count
        }()

        return try await ContestSummary(problems: problemsTask, solved: solvedTask)
    }

    func userInfo(handle: String) async throws -> CFUserInfo {
        let users: [CFUserInfo] = try await get(method: "user.info", params: [
            "handles": handle
        ])
        guard let u = users.first else { throw CFError.api("用户未找到") }
        return u
    }

    // 新增：批量 user.info（自动分批、合并）
    func userInfos(handles: [String]) async throws -> [CFUserInfo] {
        let nonEmpty = handles.map { $0.trimmed }.filter { !$0.isEmpty }
        guard !nonEmpty.isEmpty else { return [] }

        // 按 100 个一批更稳妥（CF 文档并未写死，但这样更安全）
        let chunks = stride(from: 0, to: nonEmpty.count, by: 100).map {
            Array(nonEmpty[$0..<min($0+100, nonEmpty.count)])
        }

        var results: [CFUserInfo] = []
        for group in chunks {
            let joined = group.joined(separator: ";")
            let part: [CFUserInfo] = try await get(method: "user.info", params: [
                "handles": joined
            ])
            results.append(contentsOf: part)
        }
        return results
    }

    func userRating(handle: String) async throws -> [CFRatingUpdate] {
        try await get(method: "user.rating", params: [
            "handle": handle
        ])
    }

    // MARK: - Generic GET（TTL 策略 + 在飞去重 + 限流 + 重试）

    private func get<T: Decodable>(method: String,
                                   params: [String: String] = [:],
                                   cacheTTL: TimeInterval? = nil,
                                   retry: Int = 3,
                                   forceRefresh: Bool = false) async throws -> T {
        // 1) 计算 TTL（优先使用调用方传入；否则使用默认策略）
        let ttl = (cacheTTL ?? defaultTTL(for: method, params: params))
        // 2) 归一化 key（排除 time/apiSig），用于缓存 & 在飞去重
        let key = normalizedKey(method: method, params: params)

        // 3) 缓存命中（可选跳过）
        if !forceRefresh, let ttl = ttl, ttl > 0, let cached = await cache.get(key) {
            return try decodeEnvelope(cached)
        }

        // 4) 在飞去重：如有相同 key 的请求正在进行，复用它
        if let task = inflight[key] {
            let data = try await task.value
            // 命中后也写缓存（以免上层还没读，下一次又 miss）
            if let ttl, ttl > 0 { await cache.set(key, data: data, ttl: ttl) }
            return try decodeEnvelope(data)
        }

        // 5) 创建真正的网络任务
        let task = Task<Data, Error> {
            // 重试回路（指数退避 + 抖动）
            var attempts = 0
            var delay: Double = 0.6
            while true {
                attempts += 1
                do {
                    // 在发请求前，同步 WKWebView 的 Cookie 到 URLSession，以便携带登录态
                    await CFCookieBridge.shared.syncFromWKToHTTPCookieStorage()
                    // 构造带签名的 URL（签名时要加入 time/apiSig，但 key 不能包含它们）
                    let url = try buildSignedURL(method: method, params: params)
                    await limiter.waitIfNeeded() // 2s 限流
                    let (data, resp) = try await session.data(from: url)

                    if let http = resp as? HTTPURLResponse, http.statusCode == 429 {
                        throw CFError.rateLimited
                    }
                    // 预探测 FAILED 的限流文案，命中才重试
                    if let failedComment = try Self.peekFailedComment(in: data),
                       failedComment.localizedCaseInsensitiveContains("limit") ||
                       failedComment.localizedCaseInsensitiveContains("too many") {
                        throw CFError.rateLimited
                    }

                    // 成功：写缓存并返回
                    if let ttl, ttl > 0 { await cache.set(key, data: data, ttl: ttl) }
                    return data
                } catch let e as CFError {
                    if attempts >= retry || !(e.isRateLimited || Self.isNetwork(e)) {
                        throw e
                    }
                    let jitter = Double.random(in: 0...0.3)
                    try? await Task.sleep(nanoseconds: UInt64((delay + jitter) * 1_000_000_000))
                    delay *= 2
                } catch {
                    if attempts >= retry {
                        throw CFError.network(error.localizedDescription)
                    }
                    let jitter = Double.random(in: 0...0.3)
                    try? await Task.sleep(nanoseconds: UInt64((delay + jitter) * 1_000_000_000))
                    delay *= 2
                }
            }
        }

        inflight[key] = task
        defer { inflight[key] = nil }

        let data = try await task.value
        return try decodeEnvelope(data)
    }

    // MARK: - TTL 策略（按端点）

    /// 默认 TTL：nil 表示不缓存；>0 表示内存缓存秒数
    private func defaultTTL(for method: String, params: [String: String]) -> TimeInterval? {
        switch method {
        case "contest.list":
            return 600 // 10 分钟
        case "contest.standings":
            // 这里只拉 problems，题目集基本固定
            return 86_400 // 24 小时
        case "contest.status":
            return 60 // 1 分钟（用户在看单场时的提交）
        case "user.info":
            return 1_800 // 30 分钟
        case "user.status":
            // 作为“最近提交”使用时：1 分钟；你也可以在调用处覆盖
            return 60
        case "user.rating":
            return 31_536_000 // 365 天
        case "problemset.problems":
            return 86_400 // 1 天
        case "problemset.recentStatus":
            return 60 // 1 分钟
        default:
            return nil
        }
    }

    // MARK: - URL 构建 / 签名 / 解码

    private func buildSignedURL(method: String, params: [String: String]) throws -> URL {
        var p = params
        if let key = apiKey, let secret = apiSecret {
            p["apiKey"] = key
            p["time"] = String(Int(Date().timeIntervalSince1970))
            let rand = Self.randomAlphaNumeric(6)
            p["apiSig"] = try Self.sign(rand: rand, method: method, params: p, secret: secret)
        }
        // 用排序后的 query 构建 URL，确保稳定性
        var comps = URLComponents(url: base.appendingPathComponent(method), resolvingAgainstBaseURL: false)!
        comps.queryItems = p.sorted {
            $0.key == $1.key ? ($0.value < $1.value) : ($0.key < $1.key)
        }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = comps.url else { throw CFError.badURL }
        return url
    }

    private func normalizedKey(method: String, params: [String: String]) -> String {
        // 排除 time/apiSig 等易变参数，保证缓存/去重命中
        let filtered = params.filter { k, _ in k != "time" && k != "apiSig" }
        let sorted = filtered.sorted {
            $0.key == $1.key ? ($0.value < $1.value) : ($0.key < $1.key)
        }.map { "\($0.key)=\($0.value)" }
         .joined(separator: "&")
        return sorted.isEmpty ? method : "\(method)?\(sorted)"
    }

    private func decodeEnvelope<T: Decodable>(_ data: Data) throws -> T {
        do {
            let envelope = try decoder.decode(CFResponse<T>.self, from: data)
            guard envelope.status == "OK", let result = envelope.result else {
                throw CFError.api(envelope.comment ?? "未知错误")
            }
            return result
        } catch is DecodingError {
            throw CFError.badData
        } catch let e as CFError {
            throw e
        } catch {
            throw CFError.network(error.localizedDescription)
        }
    }

    private static func isNetwork(_ e: CFError) -> Bool { if case .network = e { return true } else { return false } }

    // 签名（SHA-512 非 HMAC）
    private static func sign(rand: String, method: String, params: [String: String], secret: String) throws -> String {
        let query = params.sorted { $0.key == $1.key ? ($0.value < $1.value) : ($0.key < $1.key) }
                          .map { "\($0.key)=\($0.value)" }
                          .joined(separator: "&")
        let src = "\(rand)/\(method)?\(query)#\(secret)"
        let digest = SHA512.hash(data: Data(src.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return rand + hex
    }

    private static func randomAlphaNumeric(_ n: Int) -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<n).compactMap { _ in chars.randomElement() })
    }

    private static func peekFailedComment(in data: Data) throws -> String? {
        struct Probe: Decodable { let status: String; let comment: String? }
        let p = try JSONDecoder().decode(Probe.self, from: data)
        return p.status == "FAILED" ? (p.comment ?? "FAILED") : nil
    }
}

// 放在文件里任意位置（比如 CFError 定义后）
private extension CFError {
    var isRateLimited: Bool {
        if case .rateLimited = self { return true }
        return false
    }
}
