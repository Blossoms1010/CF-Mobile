import Foundation
import SwiftUI

// MARK: - 题库过滤条件
struct ProblemsetFilter: Equatable {
    var tags: [String] = []
    var minRating: Int? = nil
    var maxRating: Int? = nil
    var searchText: String = ""
    var hideSolved: Bool = false
    var showUnsolvedTags: Bool = true
    
    var hasActiveFilters: Bool {
        !tags.isEmpty || minRating != nil || maxRating != nil || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hideSolved
    }
}

// MARK: - 题库Store
@MainActor
class ProblemsetStore: ObservableObject {
    // 数据状态
    @Published var problems: [CFProblem] = []
    @Published var filteredProblems: [CFProblem] = []
    @Published var problemStatistics: [String: Int] = [:]  // problemId -> solvedCount
    @Published var loading: Bool = false
    @Published var error: String?
    @Published var hasLoaded: Bool = false
    
    // 过滤和搜索
    @Published var filter: ProblemsetFilter = ProblemsetFilter()
    @Published var currentPage: Int = 0
    private let itemsPerPage: Int = 50
    
    // 分页状态
    @Published var hasMore: Bool = true
    @Published var loadingMore: Bool = false
    
    // 用户解题状态缓存 (类似ContestsStore的逻辑)
    @Published var userSolvedProblems: Set<String> = []
    @Published var userTriedProblems: Set<String> = []
    private var currentHandle: String = ""
    
    // Codeforces 官方完整标签列表
    let allTags = [
        "2-sat", "binary search", "bitmasks", "brute force", "chinese remainder theorem",
        "combinatorics", "constructive algorithms", "data structures", "dfs and similar",
        "divide and conquer", "dp", "dsu", "expression parsing", "fft",
        "flows", "games", "geometry", "graph matchings", "graphs", "greedy",
        "hashing", "implementation", "interactive", "math", "matrices",
        "meet-in-the-middle", "number theory", "probabilities", "schedules", "shortest paths",
        "sortings", "string suffix structures", "strings", "ternary search", "trees",
        "two pointers"
    ]
    
    // 常用标签列表（用于快速选择）
    let commonTags = [
        "implementation", "math", "greedy", "dp", "data structures",
        "brute force", "constructive algorithms", "graphs", "sortings",
        "binary search", "dfs and similar", "trees", "strings", "number theory",
        "combinatorics", "geometry", "bitmasks", "two pointers", "hashing"
    ]
    
    var displayedProblems: [CFProblem] {
        let endIndex = min((currentPage + 1) * itemsPerPage, filteredProblems.count)
        return Array(filteredProblems.prefix(endIndex))
    }
    
    var canLoadMore: Bool {
        return !loadingMore && displayedProblems.count < filteredProblems.count
    }
    
    // MARK: - 初始加载
    func ensureLoaded(currentHandle: String) async {
        guard !loading else { return }
        
        if hasLoaded && self.currentHandle == currentHandle && !problems.isEmpty {
            return
        }
        
        self.currentHandle = currentHandle
        await loadProblems(forceRefresh: false)
        
        if !currentHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await loadUserSolvedStatus(handle: currentHandle)
        }
    }
    
    // MARK: - 强制刷新
    func forceRefresh(currentHandle: String) async {
        self.currentHandle = currentHandle
        await loadProblems(forceRefresh: true)
        
        if !currentHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await loadUserSolvedStatus(handle: currentHandle)
        }
    }
    
    // MARK: - 处理用户切换
    func handleChanged(to newHandle: String) async {
        let trimmed = newHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if currentHandle != trimmed {
            currentHandle = trimmed
            userSolvedProblems.removeAll()
            userTriedProblems.removeAll()
            
            if !trimmed.isEmpty {
                await loadUserSolvedStatus(handle: trimmed)
            }
        }
    }
    
    // MARK: - 数据加载
    private func loadProblems(forceRefresh: Bool) async {
        loading = true
        error = nil
        
        do {
            let result = try await CFAPI.shared.problemsetProblems(
                tags: filter.tags,
                minRating: filter.minRating,
                maxRating: filter.maxRating,
                forceRefresh: forceRefresh
            )
            
            // 按rating降序排序，rating相同的按contestId和index排序
            let sorted = result.problems.sorted { lhs, rhs in
                if let r1 = lhs.rating, let r2 = rhs.rating, r1 != r2 {
                    return r1 > r2
                }
                if let c1 = lhs.contestId, let c2 = rhs.contestId, c1 != c2 {
                    return c1 > c2
                }
                return lhs.index < rhs.index
            }
            
            problems = sorted
            problemStatistics = result.statistics
            applyFilters()
            hasLoaded = true
        } catch {
            self.error = error.localizedDescription
        }
        
        loading = false
    }
    
    private func loadUserSolvedStatus(handle: String) async {
        do {
            // 获取用户的所有提交记录来判断解题状态
            let submissions = try await CFAPI.shared.userSubmissionsLite(handle: handle, count: 3000)
            
            var solved: Set<String> = []
            var tried: Set<String> = []
            
            for submission in submissions {
                let problemId = submission.problem.id
                tried.insert(problemId)
                
                if submission.verdict == "OK" {
                    solved.insert(problemId)
                }
            }
            
            userSolvedProblems = solved
            userTriedProblems = tried
        } catch {
            // 静默失败，不影响题目显示
        }
    }
    
    // MARK: - 过滤逻辑
    func applyFilters() {
        var result = problems
        
        // 搜索文本过滤
        let searchText = filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !searchText.isEmpty {
            result = result.filter { problem in
                problem.name.localizedCaseInsensitiveContains(searchText) ||
                problem.index.localizedCaseInsensitiveContains(searchText) ||
                (problem.tags?.joined(separator: " ").localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // 隐藏已解决题目过滤
        if filter.hideSolved {
            result = result.filter { problem in
                getProblemStatus(for: problem) != .solved
            }
        }
        
        // 分数范围过滤
        if filter.minRating != nil || filter.maxRating != nil {
            let minRating = filter.minRating ?? 0
            let maxRating = filter.maxRating ?? 4000
            
            // 如果最大分数小于最小分数，则返回空结果
            if maxRating < minRating {
                result = []
            } else {
                result = result.filter { problem in
                    guard let rating = problem.rating, rating > 0 else {
                        // 没有评分的题目不包含在结果中
                        return false
                    }
                    return rating >= minRating && rating <= maxRating
                }
            }
        }
        
        filteredProblems = result
        currentPage = 0
        hasMore = filteredProblems.count > itemsPerPage
    }
    
    func updateFilter(_ newFilter: ProblemsetFilter) {
        let oldFilter = filter
        filter = newFilter
        
        // 如果影响API调用的参数发生改变，需要重新加载数据
        let needsReload = oldFilter.tags != newFilter.tags || 
                         oldFilter.minRating != newFilter.minRating || 
                         oldFilter.maxRating != newFilter.maxRating
        
        if needsReload {
            Task { @MainActor in
                await loadProblems(forceRefresh: false)
            }
        } else {
            // 只是本地过滤参数改变，直接应用过滤
            applyFilters()
        }
    }
    
    // MARK: - 分页加载更多
    func loadMoreIfNeeded() {
        guard canLoadMore else { return }
        
        loadingMore = true
        
        // 模拟延迟以避免过快加载
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.currentPage += 1
            self.loadingMore = false
            self.hasMore = self.displayedProblems.count < self.filteredProblems.count
        }
    }
    
    // MARK: - 获取题目状态
    func getProblemStatus(for problem: CFProblem) -> ProblemAttemptState {
        let problemId = problem.id
        
        if userSolvedProblems.contains(problemId) {
            return .solved
        } else if userTriedProblems.contains(problemId) {
            return .tried
        } else {
            return .none
        }
    }
    
    // MARK: - 重置状态
    func reset() {
        problems = []
        filteredProblems = []
        loading = false
        error = nil
        hasLoaded = false
        filter = ProblemsetFilter()
        currentPage = 0
        hasMore = true
        loadingMore = false
        userSolvedProblems.removeAll()
        userTriedProblems.removeAll()
        currentHandle = ""
    }
}

