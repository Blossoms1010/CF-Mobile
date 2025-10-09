//
//  TranslationCache.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import Foundation

// MARK: - Translation Data Model

/// 题面翻译数据
struct ProblemTranslation: Codable {
    let problemId: String // contestId-problemIndex
    let targetLanguage: String // "Chinese", "Japanese", etc.
    let translatedName: String
    let translatedStatement: [ContentElement]
    let translatedInputSpec: [ContentElement]
    let translatedOutputSpec: [ContentElement]
    let translatedNote: [ContentElement]?
    let translatedAt: Date
    let modelUsed: String // 记录使用的翻译模型
}

// MARK: - Translation Cache Manager

/// 管理题面翻译缓存
@MainActor
class TranslationCache: ObservableObject {
    static let shared = TranslationCache()
    
    // Key: "problemId-language", e.g., "2042-A-Chinese"
    @Published private(set) var translations: [String: ProblemTranslation] = [:]
    
    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    private let cacheFileName = "translation_cache.json"
    
    private init() {
        // 获取缓存目录
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cachesDirectory.appendingPathComponent("ProblemTranslations", isDirectory: true)
        
        // 创建缓存目录
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // 加载缓存
        loadCache()
    }
    
    // MARK: - Public Methods
    
    /// 获取翻译（如果存在）
    func getTranslation(problemId: String, language: String) -> ProblemTranslation? {
        let key = "\(problemId)-\(language)"
        
        // 检查翻译是否过期（30天）
        if let translation = translations[key] {
            let age = Date().timeIntervalSince(translation.translatedAt)
            let isExpired = age >= 30 * 24 * 60 * 60
            
            if isExpired {
                // 删除过期翻译
                Task {
                    await deleteTranslation(problemId: problemId, language: language)
                }
                return nil
            }
            
            return translation
        }
        
        return nil
    }
    
    /// 保存翻译
    func saveTranslation(_ translation: ProblemTranslation) async {
        let key = "\(translation.problemId)-\(translation.targetLanguage)"
        translations[key] = translation
        await saveCache()
    }
    
    /// 删除指定翻译
    func deleteTranslation(problemId: String, language: String) async {
        let key = "\(problemId)-\(language)"
        translations.removeValue(forKey: key)
        await saveCache()
    }
    
    /// 清空所有翻译缓存
    func clearAll() async {
        translations.removeAll()
        await saveCache()
    }
    
    /// 检查翻译是否已缓存
    func hasTranslation(problemId: String, language: String) -> Bool {
        return getTranslation(problemId: problemId, language: language) != nil
    }
    
    /// 获取缓存大小（字节）
    func getCacheSize() -> Int64 {
        let cacheFile = cacheDirectory.appendingPathComponent(cacheFileName)
        guard let attributes = try? fileManager.attributesOfItem(atPath: cacheFile.path) else {
            return 0
        }
        return attributes[.size] as? Int64 ?? 0
    }
    
    /// 获取缓存大小的可读字符串
    func getCacheSizeString() -> String {
        let bytes = getCacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// 获取统计信息
    func getStats() -> (totalTranslations: Int, cacheSize: Int64, languages: Set<String>) {
        let languages = Set(translations.values.map { $0.targetLanguage })
        return (translations.count, getCacheSize(), languages)
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
            let translationList = try decoder.decode([ProblemTranslation].self, from: data)
            
            // 转换为字典
            translations = Dictionary(uniqueKeysWithValues: translationList.map {
                ("\($0.problemId)-\($0.targetLanguage)", $0)
            })
        } catch {
            // 忽略加载错误，使用空缓存
            print("⚠️ Failed to load translation cache: \(error)")
        }
    }
    
    private func saveCache() async {
        let cacheFile = cacheDirectory.appendingPathComponent(cacheFileName)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            let translationList = Array(translations.values)
            let data = try encoder.encode(translationList)
            
            try data.write(to: cacheFile)
        } catch {
            print("⚠️ Failed to save translation cache: \(error)")
        }
    }
}

