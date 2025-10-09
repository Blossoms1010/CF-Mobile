import Foundation

/// Generic AI translation client via OpenAI-compatible chat/completions proxy.
/// Translates English paragraphs to Simplified Chinese.
struct AITranslator {
    struct TranslationError: Error { let message: String }

    static func translateENtoZH(_ texts: [String], model: String, proxyAPI: String, apiKey: String?) async -> [String] {
        let modelId = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = proxyAPI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelId.isEmpty, !endpoint.isEmpty, let url = URL(string: endpoint) else { return texts }
        var output: [String] = []
        output.reserveCapacity(texts.count)

        for text in texts {
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
                output.append(text)
            }
            // Light throttle to be friendly to APIs
            try? await Task.sleep(nanoseconds: 120_000_000)
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
        ? "你是专业的翻译引擎。必须只用简体中文输出译文。除非是代码、变量名、网址、数学符号或专有名词，否则不要出现英文单词。保留原有格式、数字、符号、代码和数学公式，不要添加解释或引号。"
        : "You are a professional translation engine. Translate the user's text into Simplified Chinese only. Preserve formatting, numbers, symbols, code, and math expressions verbatim when appropriate. Do not add explanations or quotes."
        let user = strict
        ? "将以下文本翻译为简体中文，只输出译文，不要解释：\n\n\(query)"
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
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TranslationError(message: "bad http response")
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


