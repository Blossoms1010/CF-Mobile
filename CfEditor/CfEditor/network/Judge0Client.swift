import Foundation

// Networking client for Judge0 API (CE or self-hosted)
// Supports base64 payloads and simple polling
final class Judge0Client {
    struct Config {
        var baseURL: URL
        var apiKey: String? = nil            // e.g. RapidAPI key when using RapidAPI endpoint
        var extraHeaders: [String: String] = [:]
        var useBase64: Bool = true
        var requestTimeout: TimeInterval = 30
        var pollInterval: TimeInterval = 1.0
        var pollTimeout: TimeInterval = 60.0

        static var `default`: Config {
            // Change baseURL to your own Judge0 instance if needed
            // Examples:
            // - Self-hosted: https://your-judge0.example.com
            // - Official CE (may have rate limits/CORS restrictions): https://ce.judge0.com
            // - RapidAPI: https://judge0-ce.p.rapidapi.com (requires apiKey and specific headers)
            return Config(baseURL: URL(string: "https://ce.judge0.com")!)
        }
    }

    struct Language: Decodable {
        let id: Int
        let name: String
    }

    struct Status: Decodable {
        let id: Int
        let description: String
    }

    struct SubmissionCreateResponse: Decodable {
        let token: String
    }

    struct SubmissionResult: Decodable {
        let stdout: String?
        let stderr: String?
        let compile_output: String?
        let message: String?
        let time: String?           // CPU time (秒)
        let wall_time: String?      // 墙上时间 (秒)
        let memory: Int?
        let status: Status
        
        // 获取最准确的运行时间（毫秒）
        var runTimeMs: Int? {
            // 优先使用 time（CPU时间），它更准确地反映代码执行时间
            // wall_time 包含了 I/O 等待等额外开销
            if let timeStr = time, let timeSec = Double(timeStr) {
                // 向上取整，避免显示 0ms（至少显示 1ms）
                let ms = max(1, Int(ceil(timeSec * 1000)))
                #if DEBUG
                print("Judge0: time=\(timeStr)s -> \(ms)ms")
                #endif
                return ms
            }
            if let wallStr = wall_time, let wallSec = Double(wallStr) {
                // 如果 time 不可用，fallback 到 wall_time
                let ms = max(1, Int(ceil(wallSec * 1000)))
                #if DEBUG
                print("Judge0: wall_time=\(wallStr)s -> \(ms)ms (fallback)")
                #endif
                return ms
            }
            #if DEBUG
            print("Judge0: No valid time data (time=\(time ?? "nil"), wall_time=\(wall_time ?? "nil"))")
            #endif
            return nil
        }
    }

    private let config: Config
    private let session: URLSession
    private var cachedLanguages: [Language] = []

    init(config: Config = .default) {
        self.config = config
        let conf = URLSessionConfiguration.ephemeral
        conf.timeoutIntervalForRequest = config.requestTimeout
        conf.timeoutIntervalForResource = config.requestTimeout + config.pollTimeout + 5
        self.session = URLSession(configuration: conf)
    }
    
    // 便捷初始化：从配置管理器创建
    convenience init(fromManager manager: Judge0ConfigManager = Judge0ConfigManager.shared) {
        self.init(config: manager.getJudge0Config())
    }

    // MARK: - Public API

    func submitAndWait(languageKey: String, sourceCode: String, stdin: String, completion: @escaping (Result<SubmissionResult, Error>) -> Void) {
        resolveLanguageId(for: languageKey) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let languageId):
                self.createSubmission(languageId: languageId, sourceCode: sourceCode, stdin: stdin) { createResult in
                    switch createResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let token):
                        self.pollSubmission(token: token, completion: completion)
                    }
                }
            }
        }
    }

    // MARK: - Language Resolution

    private func resolveLanguageId(for languageKey: String, completion: @escaping (Result<Int, Error>) -> Void) {
        if let match = pickLanguageId(from: cachedLanguages, for: languageKey) {
            completion(.success(match))
            return
        }
        fetchLanguages { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let languages):
                self.cachedLanguages = languages
                if let match = self.pickLanguageId(from: languages, for: languageKey) {
                    completion(.success(match))
                } else {
                    completion(.failure(NSError(domain: "Judge0Client", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported language: \(languageKey)"])) )
                }
            }
        }
    }

    private func pickLanguageId(from languages: [Language], for languageKey: String) -> Int? {
        let lower = languageKey.lowercased()
        // Simple fuzzy match by languageKey
        // cpp → contains "c++"; python → contains "python"; java → contains "java"
        if lower == "cpp" {
            return languages.first(where: { $0.name.lowercased().contains("c++") })?.id
        } else if lower == "python" {
            return languages.first(where: { $0.name.lowercased().contains("python") })?.id
        } else if lower == "java" {
            return languages.first(where: { $0.name.lowercased().contains("java") })?.id
        } else {
            return nil
        }
    }

    private func fetchLanguages(completion: @escaping (Result<[Language], Error>) -> Void) {
        let components = URLComponents(url: config.baseURL.appendingPathComponent("/languages"), resolvingAgainstBaseURL: false)!
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applyHeaders(to: &request)
        session.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "Judge0Client", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty response"])) )
                return
            }
            do {
                let langs = try JSONDecoder().decode([Language].self, from: data)
                completion(.success(langs))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Submissions

    private func createSubmission(languageId: Int, sourceCode: String, stdin: String, completion: @escaping (Result<String, Error>) -> Void) {
        var components = URLComponents(url: config.baseURL.appendingPathComponent("/submissions"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "base64_encoded", value: config.useBase64 ? "true" : "false"),
            URLQueryItem(name: "wait", value: "false")
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        applyHeaders(to: &request)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = {
            if config.useBase64 {
                return [
                    "language_id": languageId,
                    "source_code": sourceCode.data(using: .utf8)?.base64EncodedString() ?? "",
                    "stdin": stdin.data(using: .utf8)?.base64EncodedString() ?? "",
                    "redirect_stderr_to_stdout": true
                ]
            } else {
                return [
                    "language_id": languageId,
                    "source_code": sourceCode,
                    "stdin": stdin,
                    "redirect_stderr_to_stdout": true
                ]
            }
        }()

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

        session.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "Judge0Client", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty response"])) )
                return
            }
            do {
                let res = try JSONDecoder().decode(SubmissionCreateResponse.self, from: data)
                completion(.success(res.token))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func getSubmission(token: String, completion: @escaping (Result<SubmissionResult, Error>) -> Void) {
        var components = URLComponents(url: config.baseURL.appendingPathComponent("/submissions/\(token)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "base64_encoded", value: config.useBase64 ? "true" : "false"),
            // 明确请求时间字段
            URLQueryItem(name: "fields", value: "stdout,stderr,status,compile_output,message,time,wall_time,memory")
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applyHeaders(to: &request)
        session.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "Judge0Client", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty response"])) )
                return
            }
            do {
                let decoder = JSONDecoder()
                var result = try decoder.decode(SubmissionResult.self, from: data)
                if self.config.useBase64 {
                    // Decode textual fields
                    func decodeBase64(_ s: String?) -> String? {
                        guard let s = s, let d = Data(base64Encoded: s) else { return s }
                        return String(data: d, encoding: .utf8)
                    }
                    result = SubmissionResult(
                        stdout: decodeBase64(result.stdout),
                        stderr: decodeBase64(result.stderr),
                        compile_output: decodeBase64(result.compile_output),
                        message: decodeBase64(result.message),
                        time: result.time,
                        wall_time: result.wall_time,
                        memory: result.memory,
                        status: result.status
                    )
                }
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func pollSubmission(token: String, completion: @escaping (Result<SubmissionResult, Error>) -> Void) {
        let deadline = Date().addingTimeInterval(config.pollTimeout)
        func step() {
            self.getSubmission(token: token) { result in
                switch result {
                case .failure(let error): completion(.failure(error))
                case .success(let submission):
                    // Judge0: status.id < 3 means in-queue/processing
                    if submission.status.id < 3 {
                        if Date() > deadline {
                            completion(.failure(NSError(domain: "Judge0Client", code: -2, userInfo: [NSLocalizedDescriptionKey: "Poll timeout"])) )
                            return
                        }
                        DispatchQueue.global().asyncAfter(deadline: .now() + self.config.pollInterval) {
                            step()
                        }
                    } else {
                        completion(.success(submission))
                    }
                }
            }
        }
        step()
    }

    // MARK: - Helpers

    private func applyHeaders(to request: inout URLRequest) {
        // Common headers
        for (k, v) in config.extraHeaders { request.addValue(v, forHTTPHeaderField: k) }
        if let apiKey = config.apiKey, config.baseURL.host?.contains("rapidapi") == true {
            request.addValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
            request.addValue("judge0-ce.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        }
        request.addValue("application/json", forHTTPHeaderField: "Accept")
    }
}
