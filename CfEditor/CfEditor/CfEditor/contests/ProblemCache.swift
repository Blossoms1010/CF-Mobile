//
//  ProblemCache.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import Foundation

// MARK: - Problem Cache Manager

/// 管理题目缓存的类
@MainActor
class ProblemCache: ObservableObject {
    static let shared = ProblemCache()
    
    @Published private(set) var cachedProblems: [String: ProblemStatement] = [:]
    
    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    private let cacheFileName = "problem_cache.json"
    
    private init() {
        // 获取缓存目录
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cachesDirectory.appendingPathComponent("ProblemStatements", isDirectory: true)
        
        // 创建缓存目录
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // 加载缓存
        loadCache()
    }
    
    // MARK: - Public Methods
    
    /// 获取题目（优先从缓存，如果没有则下载）
    func getProblem(contestId: Int, problemIndex: String, forceRefresh: Bool = false) async throws -> ProblemStatement {
        let key = "\(contestId)-\(problemIndex)"
        
        // 如果不强制刷新且缓存存在，返回缓存
        if !forceRefresh, let cached = cachedProblems[key] {
            // 检查缓存是否过期（7天）
            let age = Date().timeIntervalSince(cached.cachedAt)
            let isExpired = age >= 7 * 24 * 60 * 60
            
            if !isExpired {
                return cached
            }
        }
        
        // 下载新数据
        let statement = try await ProblemParser.fetchAndParse(contestId: contestId, problemIndex: problemIndex)
        
        // 保存到缓存
        await saveProblem(statement)
        
        return statement
    }
    
    /// 保存题目到缓存
    func saveProblem(_ problem: ProblemStatement) async {
        cachedProblems[problem.id] = problem
        await saveCache()
    }
    
    /// 删除指定题目的缓存
    func deleteProblem(contestId: Int, problemIndex: String) async {
        let key = "\(contestId)-\(problemIndex)"
        cachedProblems.removeValue(forKey: key)
        await saveCache()
    }
    
    /// 清空所有缓存
    func clearAll() async {
        cachedProblems.removeAll()
        await saveCache()
    }
    
    /// 检查题目是否已缓存
    func isCached(contestId: Int, problemIndex: String) -> Bool {
        let key = "\(contestId)-\(problemIndex)"
        return cachedProblems[key] != nil
    }
    
    /// 获取缓存大小（字节）
    func getCacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
    }
    
    /// 获取缓存大小的可读字符串
    func getCacheSizeString() -> String {
        let bytes = getCacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Private Methods
    
    private func loadCache() {
        let cacheFile = cacheDirectory.appendingPathComponent(cacheFileName)
        
        guard fileManager.fileExists(atPath: cacheFile.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: cacheFile)
            let decoder = JSONDecoder()
            let problems = try decoder.decode([ProblemStatement].self, from: data)
            
            // 转换为字典
            cachedProblems = Dictionary(uniqueKeysWithValues: problems.map { ($0.id, $0) })
        } catch {
            // 忽略加载错误，使用空缓存
        }
    }
    
    private func saveCache() async {
        let cacheFile = cacheDirectory.appendingPathComponent(cacheFileName)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            let problems = Array(cachedProblems.values)
            let data = try encoder.encode(problems)
            
            try data.write(to: cacheFile)
        } catch {
            // 忽略保存错误
        }
    }
}

// MARK: - Cache Statistics

extension ProblemCache {
    /// 获取缓存统计信息
    struct CacheStats {
        let totalProblems: Int
        let totalSize: Int64
        let oldestCache: Date?
        let newestCache: Date?
    }
    
    func getStats() -> CacheStats {
        let problems = Array(cachedProblems.values)
        let dates = problems.map { $0.cachedAt }
        
        return CacheStats(
            totalProblems: problems.count,
            totalSize: getCacheSize(),
            oldestCache: dates.min(),
            newestCache: dates.max()
        )
    }
}

