import Foundation

// 轻量 Codeforces 状态查询接口（不与现有 CFAPI 冲突）
// 说明：API 限流约 ~5 rps；本应用轮询频率较低（~0.5Hz），无需特殊节流

// MARK: - API 模型
struct CFProblemShort: Codable {
    let contestId: Int?
    let index: String
    let name: String?
}

private struct CFAPIResponse<T: Decodable>: Decodable {
    let status: String
    let comment: String?
    let result: T?
}

enum CFAPIError: Error, LocalizedError {
    case invalidURL
    case badResponse
    case serverComment(String)
    case noResult

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .badResponse: return "网络响应异常"
        case .serverComment(let c): return c
        case .noResult: return "服务器未返回结果"
        }
    }
}

// MARK: - 便捷枚举与工具
enum CFVerdict: String {
    case ok = "OK"
    case failed = "FAILED"
    case partial = "PARTIAL"
    case compilationError = "COMPILATION_ERROR"
    case runtimeError = "RUNTIME_ERROR"
    case wrongAnswer = "WRONG_ANSWER"
    case presentationError = "PRESENTATION_ERROR"
    case timeLimit = "TIME_LIMIT_EXCEEDED"
    case memoryLimit = "MEMORY_LIMIT_EXCEEDED"
    case idlen = "IDLEN"
    case securityViolated = "SECURITY_VIOLATED"
    case crashed = "CRASHED"
    case inputPrepCrashed = "INPUT_PREPARATION_CRASHED"
    case challenged = "CHALLENGED"
    case skipped = "SKIPPED"
    case testing = "TESTING"
    case rejected = "REJECTED"
    case cancelled = "CANCELLED"
    case unknown

    static func from(_ raw: String?) -> CFVerdict {
        guard let sRaw = raw else { return .unknown }
        if let v = CFVerdict(rawValue: sRaw) { return v }
        let s = sRaw.uppercased()
        if s.contains("CANCEL") { return .cancelled }
        return .unknown
    }

    var isTerminal: Bool {
        switch self {
        case .testing, .idlen: return false
        default: return true
        }
    }

    var displayText: String {
        switch self {
        case .ok: return "通过"
        case .wrongAnswer: return "错误答案"
        case .timeLimit: return "超时"
        case .memoryLimit: return "超内存"
        case .runtimeError: return "运行时错误"
        case .compilationError: return "编译错误"
        case .presentationError: return "格式错误"
        case .partial: return "部分通过"
        case .failed: return "失败"
        case .rejected: return "已拒绝"
        case .skipped: return "跳过"
        case .challenged: return "被 Hack"
        case .securityViolated: return "安全违规"
        case .crashed: return "崩溃"
        case .inputPrepCrashed: return "输入准备崩溃"
        case .testing, .idlen: return "测试中…"
        case .cancelled: return "已取消"
        case .unknown: return "未知"
        }
    }
    
    var englishText: String {
        switch self {
        case .ok: return "Accepted"
        case .wrongAnswer: return "Wrong Answer"
        case .timeLimit: return "Time Limit Exceeded"
        case .memoryLimit: return "Memory Limit Exceeded"
        case .runtimeError: return "Runtime Error"
        case .compilationError: return "Compilation Error"
        case .presentationError: return "Presentation Error"
        case .partial: return "Partial"
        case .failed: return "Failed"
        case .rejected: return "Rejected"
        case .skipped: return "Skipped"
        case .challenged: return "Hacked"
        case .securityViolated: return "Security Violated"
        case .crashed: return "Crashed"
        case .inputPrepCrashed: return "Input Preparation Crashed"
        case .testing, .idlen: return "Testing"
        case .cancelled: return "Cancelled"
        case .unknown: return "Unknown"
        }
    }
}

struct CFProblemIdentifier: Hashable {
    let contestId: Int
    let index: String
    let name: String?
}

// MARK: - API 客户端
enum CFStatusAPI {
    private static let base = "https://codeforces.com/api"

    static func userStatus(handle: String, from: Int = 1, count: Int = 30) async throws -> [CFSubmission] {
        guard var comps = URLComponents(string: "\(base)/user.status") else { throw CFAPIError.invalidURL }
        comps.queryItems = [
            URLQueryItem(name: "handle", value: handle),
            URLQueryItem(name: "from", value: String(from)),
            URLQueryItem(name: "count", value: String(count))
        ]
        guard let url = comps.url else { throw CFAPIError.invalidURL }
        return try await request(url)
    }

    static func contestStatus(contestId: Int, handle: String, from: Int = 1, count: Int = 30) async throws -> [CFSubmission] {
        guard var comps = URLComponents(string: "\(base)/contest.status") else { throw CFAPIError.invalidURL }
        comps.queryItems = [
            URLQueryItem(name: "contestId", value: String(contestId)),
            URLQueryItem(name: "handle", value: handle),
            URLQueryItem(name: "from", value: String(from)),
            URLQueryItem(name: "count", value: String(count))
        ]
        guard let url = comps.url else { throw CFAPIError.invalidURL }
        return try await request(url)
    }
    
    // 获取比赛所有公开提交记录（不需要指定用户）
    static func publicContestStatus(contestId: Int, from: Int = 1, count: Int = 30) async throws -> [CFSubmission] {
        guard var comps = URLComponents(string: "\(base)/contest.status") else { throw CFAPIError.invalidURL }
        comps.queryItems = [
            URLQueryItem(name: "contestId", value: String(contestId)),
            URLQueryItem(name: "from", value: String(from)),
            URLQueryItem(name: "count", value: String(count))
        ]
        guard let url = comps.url else { throw CFAPIError.invalidURL }
        return try await request(url)
    }

    // 获取某题的所有提交（按时间倒序）。优先从 contest.status 获取，兜底 user.status
    static func submissionsFor(problem: CFProblemIdentifier, handle: String, limit: Int = 1000) async throws -> [CFSubmission] {
        // 先尝试 contest.status（数据量更小且只含该场比赛）
        do {
            let subs = try await contestStatus(contestId: problem.contestId, handle: handle, from: 1, count: limit)
            let filtered = subs.filter { sub in
                (sub.problem.contestId ?? problem.contestId) == problem.contestId &&
                sub.problem.index.uppercased() == problem.index.uppercased()
            }
            // 如果本场有记录，直接返回；否则进入跨 Div 兜底
            if !filtered.isEmpty { 
                return filtered.sorted(by: { $0.creationTimeSeconds > $1.creationTimeSeconds }) 
            }
        } catch {
            // 如果 contest.status 失败（比如用户没有参加该比赛），继续尝试其他方法
            print("Contest status failed for user \(handle) in contest \(problem.contestId): \(error)")
        }
        
        // 退路 A：若提供了题目名，则按题目名在所有提交中匹配（跨 Div）
        if let name = problem.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do {
                let subs = try await userStatus(handle: handle, from: 1, count: limit)
                let target = normalizeName(name)
                let matchedByName = subs.filter { s in
                    normalizeName(s.problem.name) == target
                }
                if !matchedByName.isEmpty {
                    return matchedByName.sorted(by: { $0.creationTimeSeconds > $1.creationTimeSeconds })
                }
            } catch {
                print("User status failed for handle \(handle): \(error)")
                // 继续尝试最后的退路
            }
        }
        
        // 退路 B：按 contestId 和 index 精确匹配
        do {
            let subs = try await userStatus(handle: handle, from: 1, count: limit)
            let matchedByContestAndIndex = subs.filter { s in 
                (s.problem.contestId ?? 0) == problem.contestId &&
                s.problem.index.caseInsensitiveCompare(problem.index) == .orderedSame 
            }
            return matchedByContestAndIndex.sorted(by: { $0.creationTimeSeconds > $1.creationTimeSeconds })
        } catch {
            print("Final user status attempt failed for handle \(handle): \(error)")
            // 如果所有方法都失败了，返回空数组而不是抛出错误
            return []
        }
    }

    // 获取某题的公开提交记录（不需要登录）
    static func publicSubmissionsFor(problem: CFProblemIdentifier, limit: Int = 1000) async throws -> [CFSubmission] {
        do {
            // 使用公开的 contest.status API 获取该比赛的所有提交记录
            let subs = try await publicContestStatus(contestId: problem.contestId, from: 1, count: limit)
            let filtered = subs.filter { sub in
                (sub.problem.contestId ?? problem.contestId) == problem.contestId &&
                sub.problem.index.uppercased() == problem.index.uppercased()
            }
            return filtered.sorted(by: { $0.creationTimeSeconds > $1.creationTimeSeconds })
        } catch {
            print("Public contest status failed for contest \(problem.contestId), problem \(problem.index): \(error)")
            // 如果获取公开提交记录失败，返回空数组而不是抛出错误
            return []
        }
    }

    // 查找某题最近一次提交（优先 contest.status，兜底 user.status）
    static func latestSubmission(for problem: CFProblemIdentifier, handle: String) async throws -> CFSubmission? {
        // 尝试 contest.status 以减少数据量
        if let subs = try? await contestStatus(contestId: problem.contestId, handle: handle, from: 1, count: 50) {
            let filtered = subs.filter { sub in
                (sub.problem.contestId ?? problem.contestId) == problem.contestId && sub.problem.index.uppercased() == problem.index.uppercased()
            }
            if let latest = filtered.sorted(by: { $0.creationTimeSeconds > $1.creationTimeSeconds }).first {
                return latest
            }
        }
        // 退路 A：按题目名匹配（跨 Div）
        if let name = problem.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let subs = try await userStatus(handle: handle, from: 1, count: 300)
            let target = normalizeName(name)
            let matchedByName = subs.filter { s in normalizeName(s.problem.name) == target }
            return matchedByName.sorted(by: { $0.creationTimeSeconds > $1.creationTimeSeconds }).first
        }
        // 退路 B：按 index 近似匹配
        let subs = try await userStatus(handle: handle, from: 1, count: 300)
        let matchedByIndex = subs.filter { s in s.problem.index.caseInsensitiveCompare(problem.index) == .orderedSame }
        return matchedByIndex.sorted(by: { $0.creationTimeSeconds > $1.creationTimeSeconds }).first
    }

    // 轮询更新：返回指定 runId 的 Submission（从 contest.status 获取）
    static func fetchByRunId(contestId: Int, handle: String, runId: Int) async throws -> CFSubmission? {
        // contest.status 没有按 runId 查询，只能拿一段最近提交再过滤
        let subs = try await contestStatus(contestId: contestId, handle: handle, from: 1, count: 50)
        return subs.first(where: { $0.id == runId })
    }

    // MARK: - 基础请求
    private static func request<T: Decodable>(_ url: URL) async throws -> T {
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CFAPIError.badResponse
        }
        let decoded = try JSONDecoder().decode(CFAPIResponse<T>.self, from: data)
        guard decoded.status == "OK" else {
            throw CFAPIError.serverComment(decoded.comment ?? "API 返回失败")
        }
        guard let result = decoded.result else { throw CFAPIError.noResult }
        return result
    }

    // MARK: - 工具
    private static func normalizeName(_ name: String) -> String {
        let lowered = name.lowercased()
        let trimmed = lowered.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return collapsed
    }
}
 

