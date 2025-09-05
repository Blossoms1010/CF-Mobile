import Foundation
import CryptoKit

extension String {
    var sha256: String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

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

struct CFSubmissionAuthor: Decodable, Sendable {
    let contestId: Int?
    let members: [CFSubmissionMember]
    let participantType: String?
    let ghost: Bool?
    let room: Int?
    let startTimeSeconds: Int?
}

struct CFSubmissionMember: Decodable, Sendable {
    let handle: String
    let name: String?
}

struct CFSubmission: Decodable, Identifiable, Sendable {
    let id: Int
    let contestId: Int?
    let creationTimeSeconds: Int
    let problem: CFProblem
    let author: CFSubmissionAuthor?
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

// MARK: - Disk Cache for Long-term Storage

actor CFDiskCache {
    private let cacheDir: URL
    private let maxCacheSizeMB = 100 // 最大磁盘缓存 100MB
    
    init() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDir = dir.appendingPathComponent("cf_api_cache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    
    func get(_ key: String) async -> Data? {
        let fileURL = cacheDir.appendingPathComponent(key.sha256)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            // 更新文件访问时间用于 LRU 清理
            try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
            return data
        } catch {
            return nil
        }
    }
    
    func set(_ key: String, data: Data) async {
        let fileURL = cacheDir.appendingPathComponent(key.sha256)
        
        do {
            try data.write(to: fileURL)
            await cleanupIfNeeded()
        } catch {
            // 静默失败，磁盘缓存不是关键功能
        }
    }
    
    func clear() async {
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    
    private func cleanupIfNeeded() async {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { return }
        
        let totalSize = files.compactMap { url -> Int? in
            try? fm.attributesOfItem(atPath: url.path)[.size] as? Int
        }.reduce(0, +)
        
        if totalSize > maxCacheSizeMB * 1024 * 1024 {
            // 按修改时间排序，删除最旧的文件直到大小合适
            let sortedFiles = files.compactMap { url -> (URL, Date)? in
                guard let date = try? fm.attributesOfItem(atPath: url.path)[.modificationDate] as? Date else { return nil }
                return (url, date)
            }.sorted { $0.1 < $1.1 }
            
            var currentSize = totalSize
            for (fileURL, _) in sortedFiles {
                if currentSize <= maxCacheSizeMB * 1024 * 1024 { break }
                
                if let fileSize = try? fm.attributesOfItem(atPath: fileURL.path)[.size] as? Int {
                    try? fm.removeItem(at: fileURL)
                    currentSize -= fileSize
                }
            }
        }
    }
}

// MARK: - Performance Monitoring

actor CFPerformanceMonitor {
    private var requestStats: [String: RequestStats] = [:]
    private var totalRequests = 0
    private var cacheHits = 0
    
    struct RequestStats {
        var count: Int = 0
        var totalTime: TimeInterval = 0
        var cacheHitRate: Double = 0
        var lastRequestTime: Date?
        
        var averageTime: TimeInterval {
            count > 0 ? totalTime / Double(count) : 0
        }
    }
    
    func recordRequest(method: String, duration: TimeInterval, fromCache: Bool) {
        totalRequests += 1
        if fromCache { cacheHits += 1 }
        
        if requestStats[method] == nil {
            requestStats[method] = RequestStats()
        }
        
        requestStats[method]!.count += 1
        requestStats[method]!.totalTime += duration
        requestStats[method]!.lastRequestTime = Date()
        
        // 更新缓存命中率
        let methodCacheHits = fromCache ? (requestStats[method]!.cacheHitRate * Double(requestStats[method]!.count - 1) + 1) : (requestStats[method]!.cacheHitRate * Double(requestStats[method]!.count - 1))
        requestStats[method]!.cacheHitRate = methodCacheHits / Double(requestStats[method]!.count)
    }
    
    func getStats() -> (totalRequests: Int, totalCacheHitRate: Double, methodStats: [String: RequestStats]) {
        let totalCacheHitRate = totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) : 0
        return (totalRequests, totalCacheHitRate, requestStats)
    }
    
    func reset() {
        requestStats.removeAll()
        totalRequests = 0
        cacheHits = 0
    }
}

// MARK: - Memory Cache with TTL

actor CFMemoryCache {
    private var store: [String: (data: Data, expiry: Date, lastAccess: Date)] = [:]
    private let maxItems = 1000 // 最大缓存项数
    private let maxMemoryMB = 50 // 最大内存使用 50MB
    
    func get(_ key: String) -> Data? {
        guard let (data, expiry, _) = store[key], expiry > Date() else {
            store[key] = nil
            return nil
        }
        // 更新访问时间用于 LRU
        store[key] = (data, expiry, Date())
        return data
    }

    func set(_ key: String, data: Data, ttl: TimeInterval) {
        guard ttl > 0 else { return }
        
        // 清理过期项
        cleanupExpired()
        
        // 检查内存使用和数量限制
        if store.count >= maxItems || estimatedMemoryUsageMB() > maxMemoryMB {
            performLRUCleanup()
        }
        
        store[key] = (data, Date().addingTimeInterval(ttl), Date())
    }

    func clear() { store.removeAll() }
    
    // MARK: - 私有清理方法
    
    private func cleanupExpired() {
        let now = Date()
        store = store.filter { $0.value.expiry > now }
    }
    
    private func performLRUCleanup() {
        // 按最后访问时间排序，移除最久未访问的 20%
        let sorted = store.sorted { $0.value.lastAccess < $1.value.lastAccess }
        let removeCount = max(1, sorted.count / 5)
        
        for i in 0..<removeCount {
            store.removeValue(forKey: sorted[i].key)
        }
    }
    
    private func estimatedMemoryUsageMB() -> Int {
        let totalBytes = store.values.reduce(0) { $0 + $1.data.count }
        return totalBytes / (1024 * 1024)
    }
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
    private let diskCache = CFDiskCache()
    private let perfMonitor = CFPerformanceMonitor()

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
        await diskCache.clear()
        inflight.removeAll()
        apiKey = nil
        apiSecret = nil
    }
    
    // 清理所有缓存（保留账号信息）
    func clearAllCache() async {
        await cache.clear()
        await diskCache.clear()
        inflight.removeAll()
    }
    
    // 获取性能统计
    func getPerformanceStats() async -> (totalRequests: Int, totalCacheHitRate: Double, methodStats: [String: CFPerformanceMonitor.RequestStats]) {
        return await perfMonitor.getStats()
    }
    
    // 重置性能统计
    func resetPerformanceStats() async {
        await perfMonitor.reset()
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
    
    // MARK: - Problemset APIs
    
    /// 获取题库中的题目列表（支持标签和难度过滤）
    func problemsetProblems(tags: [String] = [], minRating: Int? = nil, maxRating: Int? = nil, forceRefresh: Bool = false) async throws -> (problems: [CFProblem], statistics: [String: Int]) {
        struct ProblemsetResult: Decodable {
            let problems: [CFProblem]
            let problemStatistics: [ProblemStatistic]?
        }
        
        struct ProblemStatistic: Decodable {
            let contestId: Int?
            let index: String
            let solvedCount: Int
        }
        
        var params: [String: String] = [:]
        
        if !tags.isEmpty {
            params["tags"] = tags.joined(separator: ";")
        }
        
        if let min = minRating {
            params["minRating"] = String(min)
        }
        
        if let max = maxRating {
            params["maxRating"] = String(max)
        }
        
        let result: ProblemsetResult = try await get(method: "problemset.problems", params: params, forceRefresh: forceRefresh)
        
        // 构建统计信息映射 (problemId -> solvedCount)
        var statisticsMap: [String: Int] = [:]
        if let stats = result.problemStatistics {
            for stat in stats {
                let problemId = "\(stat.contestId ?? -1)-\(stat.index)"
                statisticsMap[problemId] = stat.solvedCount
            }
        }
        
        return (problems: result.problems, statistics: statisticsMap)
    }
    
    /// 获取题库中最近的提交记录
    func problemsetRecentStatus(count: Int = 100, forceRefresh: Bool = false) async throws -> [CFSubmission] {
        let safeCount = max(1, min(count, 1000))
        return try await get(method: "problemset.recentStatus", params: [
            "count": String(safeCount)
        ], forceRefresh: forceRefresh)
    }

    // MARK: - Generic GET（TTL 策略 + 在飞去重 + 限流 + 重试）

    private func get<T: Decodable>(method: String,
                                   params: [String: String] = [:],
                                   cacheTTL: TimeInterval? = nil,
                                   retry: Int = 3,
                                   forceRefresh: Bool = false) async throws -> T {
        let startTime = Date()
        var fromCache = false
        
        defer {
            let duration = Date().timeIntervalSince(startTime)
            Task { await perfMonitor.recordRequest(method: method, duration: duration, fromCache: fromCache) }
        }
        
        // 1) 计算 TTL（优先使用调用方传入；否则使用默认策略）
        let ttl = (cacheTTL ?? defaultTTL(for: method, params: params))
        // 2) 归一化 key（排除 time/apiSig），用于缓存 & 在飞去重
        let key = normalizedKey(method: method, params: params)

        // 3) 缓存命中（可选跳过）
        if !forceRefresh, let ttl = ttl, ttl > 0 {
            // 优先内存缓存
            if let cached = await cache.get(key) {
                fromCache = true
                return try decodeEnvelope(cached)
            }
            // 其次磁盘缓存（仅对长期稳定数据）
            if shouldUseDiskCache(method: method), let diskCached = await diskCache.get(key) {
                // 从磁盘恢复到内存缓存
                await cache.set(key, data: diskCached, ttl: ttl)
                fromCache = true
                return try decodeEnvelope(diskCached)
            }
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
                    // 明确使用 GET 请求对象，附带合理的 Accept 头，模拟浏览器访问
                    var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
                    req.httpMethod = "GET"
                    req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
                    let (data, resp) = try await session.data(for: req)

                    if let http = resp as? HTTPURLResponse, http.statusCode == 429 {
                        throw CFError.rateLimited
                    }
                    // 预探测 FAILED 的限流文案，命中才重试
                    if let failedComment = try Self.peekFailedComment(in: data),
                       failedComment.localizedCaseInsensitiveContains("limit") ||
                       failedComment.localizedCaseInsensitiveContains("too many") {
                        throw CFError.rateLimited
                    }
                    // Cloudflare/HTML 拦截的健壮性判断（极少见，通常 API 不被 CF 拦截，但保底处理）
                    if let http = resp as? HTTPURLResponse,
                       (http.statusCode == 403 || http.statusCode == 503),
                       let s = String(data: data, encoding: .utf8)?.lowercased(),
                       s.contains("cf-please-wait") || s.contains("checking your browser") || s.contains("just a moment") {
                        throw CFError.network("被 Cloudflare 验证拦截，请稍后重试")
                    }

                    // 成功：写缓存并返回
                    if let ttl, ttl > 0 { 
                        await cache.set(key, data: data, ttl: ttl)
                        // 对长期稳定数据同时写入磁盘缓存
                        if shouldUseDiskCache(method: method) {
                            Task { await diskCache.set(key, data: data) }
                        }
                    }
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

    // MARK: - 缓存策略
    
    /// 判断是否应该使用磁盘缓存（仅对长期稳定数据）
    private func shouldUseDiskCache(method: String) -> Bool {
        switch method {
        case "contest.list", "contest.standings", "user.rating", "problemset.problems":
            return true // 历史数据，很少变化，适合磁盘缓存
        default:
            return false // 动态数据，仅使用内存缓存
        }
    }

    // MARK: - TTL 策略（按端点）

    /// 默认 TTL：nil 表示不缓存；>0 表示内存缓存秒数
    private func defaultTTL(for method: String, params: [String: String]) -> TimeInterval? {
        switch method {
        case "contest.list":
            return 1800 // 30 分钟（历史比赛很少变化）
        case "contest.standings":
            // 这里只拉 problems，题目集基本固定
            return 86_400 // 24 小时
        case "contest.status":
            return 300 // 5 分钟（比赛提交状态）
        case "user.info":
            return 3600 // 1 小时（用户信息变化不频繁）
        case "user.status":
            // 根据请求数量和用途优化缓存时间
            if let countStr = params["count"], let count = Int(countStr) {
                return count > 1000 ? 1800 : 300 // 大量历史数据缓存更久
            }
            return 300 // 默认 5 分钟
        case "user.rating":
            return 31_536_000 // 365 天（rating 历史几乎不变）
        case "problemset.problems":
            return 86_400 // 1 天
        case "problemset.recentStatus":
            return 180 // 3 分钟
        default:
            return 600 // 默认 10 分钟（更积极的缓存）
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
