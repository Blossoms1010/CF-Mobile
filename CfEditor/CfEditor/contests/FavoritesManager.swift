//
//  FavoritesManager.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//  收藏题目管理器
//

import Foundation
import SwiftUI

// MARK: - 收藏的题目数据模型

struct FavoriteProblem: Codable, Identifiable, Equatable {
    let id: String  // contestId-problemIndex，例如 "2042-A"
    let contestId: Int
    let problemIndex: String
    let name: String
    let rating: Int?
    let tags: [String]
    let addedAt: Date
    
    init(contestId: Int, problemIndex: String, name: String, rating: Int?, tags: [String]) {
        self.id = "\(contestId)-\(problemIndex)"
        self.contestId = contestId
        self.problemIndex = problemIndex
        self.name = name
        self.rating = rating
        self.tags = tags
        self.addedAt = Date()
    }
    
    // 从 CFProblem 创建
    init(from problem: CFProblem) {
        self.id = problem.id
        self.contestId = problem.contestId ?? 0
        self.problemIndex = problem.index
        self.name = problem.name
        self.rating = problem.rating
        self.tags = problem.tags ?? []
        self.addedAt = Date()
    }
}

// MARK: - 收藏管理器

@MainActor
class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    @Published private(set) var favorites: [FavoriteProblem] = []
    @Published private(set) var favoriteIds: Set<String> = []
    
    private let favoritesKey = "cf_favorites_problems"
    
    private init() {
        loadFavorites()
    }
    
    // MARK: - Public Methods
    
    /// 添加收藏
    func addFavorite(_ problem: FavoriteProblem) {
        // 避免重复
        guard !favoriteIds.contains(problem.id) else { return }
        
        favorites.insert(problem, at: 0)  // 最新的在前面
        favoriteIds.insert(problem.id)
        saveFavorites()
    }
    
    /// 从 CFProblem 添加收藏
    func addFavorite(from problem: CFProblem) {
        let favorite = FavoriteProblem(from: problem)
        addFavorite(favorite)
    }
    
    /// 移除收藏
    func removeFavorite(id: String) {
        favorites.removeAll { $0.id == id }
        favoriteIds.remove(id)
        saveFavorites()
    }
    
    /// 切换收藏状态
    func toggleFavorite(_ problem: CFProblem) {
        let id = problem.id
        if favoriteIds.contains(id) {
            removeFavorite(id: id)
        } else {
            addFavorite(from: problem)
        }
    }
    
    /// 检查是否已收藏
    func isFavorite(id: String) -> Bool {
        favoriteIds.contains(id)
    }
    
    /// 清空所有收藏
    func clearAll() {
        favorites.removeAll()
        favoriteIds.removeAll()
        saveFavorites()
    }
    
    // MARK: - Private Methods
    
    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: favoritesKey) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            favorites = try decoder.decode([FavoriteProblem].self, from: data)
            favoriteIds = Set(favorites.map { $0.id })
        } catch {
            print("Failed to load favorites: \(error)")
            favorites = []
            favoriteIds = []
        }
    }
    
    private func saveFavorites() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(favorites)
            UserDefaults.standard.set(data, forKey: favoritesKey)
        } catch {
            print("Failed to save favorites: \(error)")
        }
    }
}

// MARK: - 统计信息扩展

extension FavoritesManager {
    /// 获取收藏统计信息
    struct Stats {
        let total: Int
        let byRating: [Int: Int]  // rating -> count
        let byTag: [String: Int]  // tag -> count
    }
    
    func getStats() -> Stats {
        var byRating: [Int: Int] = [:]
        var byTag: [String: Int] = [:]
        
        for fav in favorites {
            // 统计难度分布
            if let rating = fav.rating {
                let rounded = (rating / 100) * 100  // 四舍五入到百位
                byRating[rounded, default: 0] += 1
            }
            
            // 统计标签分布
            for tag in fav.tags {
                byTag[tag, default: 0] += 1
            }
        }
        
        return Stats(
            total: favorites.count,
            byRating: byRating,
            byTag: byTag
        )
    }
}

