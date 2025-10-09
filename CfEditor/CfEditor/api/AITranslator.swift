import Foundation

/// Generic AI translation client via OpenAI-compatible chat/completions proxy.
/// Translates English paragraphs to Simplified Chinese.
struct AITranslator {
    struct TranslationError: Error { let message: String }

    static func translateENtoZH(_ texts: [String], model: String, proxyAPI: String, apiKey: String?) async throws -> [String] {
        let modelId = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = proxyAPI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelId.isEmpty, !endpoint.isEmpty, let url = URL(string: endpoint) else { 
            throw TranslationError(message: "API configuration incomplete")
        }
        var output: [String] = []
        output.reserveCapacity(texts.count)
        var firstError: Error? = nil

        for (index, text) in texts.enumerated() {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                output.append(text)
                continue
            }
            do {
                // Protect LaTeX with placeholders so the model won't alter them
                let (masked, map) = maskLatexSegments(in: trimmed)
                // First attempt
                var zh = try await requestChatTranslate(query: masked, model: modelId, url: url, apiKey: apiKey, strict: false)
                zh = restoreLatexPlaceholders(in: zh, with: map)
                // If the model returned no Chinese and the source likely needs translation, retry with stricter prompt
                if !containsChinese(zh) && containsLatinLetters(trimmed) {
                    if let strictZhMasked = try? await requestChatTranslate(query: masked, model: modelId, url: url, apiKey: apiKey, strict: true) {
                        let s = restoreLatexPlaceholders(in: strictZhMasked, with: map)
                        if containsChinese(s) { zh = s }
                    }
                }
                output.append(zh)
            } catch {
                // Save first error, throw immediately for first paragraph
                if index == 0 {
                    throw error
                }
                // For non-first paragraphs, record error but continue (avoid total failure)
                if firstError == nil {
                    firstError = error
                }
                output.append(text)
            }
            // Light throttle to be friendly to APIs
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
        
        // If there's an error from non-first paragraph, throw at the end
        if let error = firstError {
            throw error
        }
        
        return output
    }

    private static func requestChatTranslate(query: String, model: String, url: URL, apiKey: String?, strict: Bool) async throws -> String {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let trimmedKey = (apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            req.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        }

        let system = strict
        ? "You are a professional translation engine. You must output the translation in Simplified Chinese only. Do not include English words unless they are code, variable names, URLs, mathematical symbols, or proper nouns. Preserve formatting, numbers, symbols, code, and mathematical formulas. Do not add explanations or quotes."
        : "You are a professional translation engine. Translate the user's text into Simplified Chinese only. Preserve formatting, numbers, symbols, code, and math expressions verbatim when appropriate. Do not add explanations or quotes."
        let user = strict
        ? "Translate the following text to Simplified Chinese. Output only the translation without explanations:\n\n\(query)"
        : "Translate the following text to Simplified Chinese. Keep the meaning accurate and concise.\n\n\(query)"

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "temperature": 0,
            "max_tokens": 1024
        ]

        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        
        // Detailed HTTP error handling
        guard let http = resp as? HTTPURLResponse else {
            throw TranslationError(message: "Invalid HTTP response")
        }
        
        guard (200..<300).contains(http.statusCode) else {
            // Try to parse error message
            var errorDetail = "HTTP \(http.statusCode)"
            if let errorObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let errorMsg = errorObj["error"] as? [String: Any],
                   let message = errorMsg["message"] as? String {
                    errorDetail += ": \(message)"
                } else if let message = errorObj["message"] as? String {
                    errorDetail += ": \(message)"
                } else if let detail = String(data: data, encoding: .utf8) {
                    errorDetail += ": \(detail.prefix(200))"
                }
            }
            print("❌ Translation API Error: \(errorDetail)")
            print("   Request URL: \(url.absoluteString)")
            print("   Model: \(model)")
            throw TranslationError(message: errorDetail)
        }

        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = obj["choices"] as? [[String: Any]],
           let first = choices.first,
           let message = first["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return query
    }

    private static func containsChinese(_ s: String) -> Bool {
        return s.range(of: "[\\u4E00-\\u9FFF]", options: .regularExpression) != nil
    }

    private static func containsLatinLetters(_ s: String) -> Bool {
        return s.range(of: "[A-Za-z]", options: .regularExpression) != nil
    }

    // MARK: - LaTeX Protection
    private struct PlaceholderMap {
        let tokenToOriginal: [String: String]
    }

    private static func maskLatexSegments(in text: String) -> (masked: String, map: PlaceholderMap) {
        // Combined regex matching common LaTeX notations: \( \), \[ \], \begin..\end, $$..$$, $..$
        let pattern = #"\\\((?:[\s\S]*?)\\\)|\\\[(?:[\s\S]*?)\\\]|\\begin\{[^}]+\}[\s\S]*?\\end\{[^}]+\}|\$\$(?:[\s\S]*?)\$\$|\$(?:[^$]|\\\$)+\$"#
        let ns = text as NSString
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else {
            return (text, PlaceholderMap(tokenToOriginal: [:]))
        }
        let allMatches = re.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        // Build a non-overlapping list of ranges (regex could theoretically return overlapping groups)
        var ranges: [NSRange] = []
        var lastEnd = 0
        for m in allMatches {
            let r = m.range
            if r.location >= lastEnd {
                ranges.append(r)
                lastEnd = r.location + r.length
            }
        }
        var masked = ""
        var cursor = 0
        var mapping: [String: String] = [:]
        for (i, r) in ranges.enumerated() {
            if cursor < r.location {
                masked += ns.substring(with: NSRange(location: cursor, length: r.location - cursor))
            }
            let original = ns.substring(with: r)
            let token = "[[TEX" + String(i) + "]]"
            masked += token
            mapping[token] = original
            cursor = r.location + r.length
        }
        if cursor < ns.length {
            masked += ns.substring(with: NSRange(location: cursor, length: ns.length - cursor))
        }
        return (masked, PlaceholderMap(tokenToOriginal: mapping))
    }

    private static func restoreLatexPlaceholders(in text: String, with map: PlaceholderMap) -> String {
        var res = text
        for (token, original) in map.tokenToOriginal { res = res.replacingOccurrences(of: token, with: original) }
        return res
    }
}

// MARK: - AI Model Tester
/// Tests AI model API connectivity by sending a simple "hello" request
struct AIModelTester {
    enum TestError: Error, LocalizedError {
        case invalidURL
        case badResponse(Int, String?)
        case networkError(String)
        case noResponse
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API endpoint"
            case .badResponse(let code, let detail):
                var msg = "HTTP Error: \(code)"
                if code == 404 {
                    msg += "\n\n❌ 404 error means the endpoint path does not exist\n\nCommon causes:"
                    msg += "\n• API endpoint should end with /v1/chat/completions"
                    msg += "\n• Example: https://api.openai.com/v1/chat/completions"
                    msg += "\n• If using a proxy, verify the proxy URL is correct"
                    msg += "\n\nCheck current endpoint for typos or missing paths"
                } else if code == 401 {
                    msg += "\n\nAuthentication failed, check if API Key is correct"
                } else if code == 403 {
                    msg += "\n\nAccess denied, check API Key permissions"
                } else if code == 429 {
                    msg += "\n\nRate limited, please try again later"
                } else if code == 500 {
                    msg += "\n\nServer error, check if model name is correct"
                }
                if let detail = detail {
                    msg += "\n\nDetails: \(detail)"
                }
                return msg
            case .networkError(let msg):
                return "Network error: \(msg)"
            case .noResponse:
                return "API did not return a valid response"
            }
        }
    }
    
    static func testModel(model: String, apiEndpoint: String, apiKey: String) async throws -> String {
        let modelId = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = apiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !modelId.isEmpty, !endpoint.isEmpty else {
            throw TestError.invalidURL
        }
        
        guard let url = URL(string: endpoint) else {
            throw TestError.invalidURL
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 10
        
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            req.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "model": modelId,
            "messages": [
                ["role": "user", "content": "Say 'hello' in one word"]
            ],
            "temperature": 0,
            "max_tokens": 10
        ]
        
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            
            guard let http = resp as? HTTPURLResponse else {
                throw TestError.noResponse
            }
            
            guard (200..<300).contains(http.statusCode) else {
                // Try to parse error details
                var errorDetail: String? = nil
                if let errorObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let errorMsg = errorObj["error"] as? [String: Any],
                       let message = errorMsg["message"] as? String {
                        errorDetail = message
                    } else if let message = errorObj["message"] as? String {
                        errorDetail = message
                    } else if let detail = String(data: data, encoding: .utf8), !detail.isEmpty {
                        errorDetail = String(detail.prefix(200))
                    }
                }
                
                // Print debug info
                print("❌ API Test Failed:")
                print("   Status Code: \(http.statusCode)")
                print("   URL: \(endpoint)")
                print("   Model: \(modelId)")
                if let detail = errorDetail {
                    print("   Details: \(detail)")
                }
                
                throw TestError.badResponse(http.statusCode, errorDetail)
            }
            
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = obj["choices"] as? [[String: Any]],
               let first = choices.first,
               let message = first["message"] as? [String: Any],
               let content = message["content"] as? String {
                let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                print("✅ API Test Successful")
                return trimmedContent.isEmpty ? "✓ API Available" : trimmedContent
            }
            
            throw TestError.noResponse
        } catch let error as TestError {
            throw error
        } catch {
            throw TestError.networkError(error.localizedDescription)
        }
    }
}


