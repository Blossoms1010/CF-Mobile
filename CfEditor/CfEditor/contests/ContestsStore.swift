//
//  ContestsStore.swift
//  CfEditor
//
//  Created by 赵勃翔 on 2025/8/17.
//

import SwiftUI

// 行视图模型（只承载展示必要字段）
struct ContestVM: Identifiable, Equatable {
    let id: Int
    let name: String
    let startTime: Date?
    let phase: String?
    let durationSeconds: Int?
    
    // 计算属性：从名称推断比赛类型
    var division: ContestDivision {
        return ContestDivision.from(contestName: name)
    }
    
    // 计算属性：将phase字符串转换为枚举
    var contestPhase: ContestPhase? {
        guard let phase = phase else { return nil }
        return ContestPhase(rawValue: phase)
    }
}

// 单题键与状态
struct ProblemKey: Hashable {
    let contestId: Int
    let index: String
}

enum ProblemAttemptState: Equatable {
    case none
    case tried
    case solved
}

@MainActor
final class ContestsStore: ObservableObject {

    // 页面级状态
    @Published var loading = false
    @Published var pageError: String?

    // 列表
    @Published var vms: [ContestVM] = []
    @Published var loadingMore = false
    @Published var hasMore = false
    
    // 过滤器
    @Published var filter = ContestFilter()
    @Published var filteredVms: [ContestVM] = []

    // —— "唯一真源" —— //
    @Published var problemCache: [Int: [CFProblem]] = [:] // contestId -> problems
    @Published var solvedMap: [Int: Int] = [:]            // contestId -> solved count
    @Published var loadingContestIds: Set<Int> = []       // 行内加载指示
    @Published var problemErrorMap: [Int: String] = [:]   // 行内错误文案
    @Published var problemAttemptMap: [ProblemKey: ProblemAttemptState] = [:] // 单题做题状态
    @Published var problemAttemptByName: [String: ProblemAttemptState] = [:]   // 跨场同题（按名称归并）
    @Published var problemStatistics: [String: Int] = [:]  // problemId -> solvedCount（通过人数统计）

    // —— 会话 & 加载策略 —— //
    private var firstLoaded = false
    private var lastLoadedHandle: String = "" // 已加载过的（trim 后）
    private var sessionToken = UUID()
    private let pageSize: Int = 20
    private var allItems: [ContestVM] = []

    // 简易磁盘缓存（首次进入时从磁盘快速上屏，后台再更新）
    private var contestsCacheURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("cf_contests_cache.json")
    }
    private func loadContestsFromDisk() -> [CFContest]? {
        guard let data = try? Data(contentsOf: contestsCacheURL) else { return nil }
        return try? JSONDecoder().decode([CFContest].self, from: data)
    }
    private func saveContestsToDisk(_ contests: [CFContest]) {
        if let data = try? JSONEncoder().encode(contests) {
            try? data.write(to: contestsCacheURL, options: .atomic)
        }
    }

    // 仅在首次进入或应用被重建后，确保加载一次；切 Tab 不会重新加载
    func ensureLoaded(currentHandle: String) async {
        if firstLoaded { return }
        firstLoaded = true
        lastLoadedHandle = currentHandle.trimmed
        await reloadAllNewSession(handle: lastLoadedHandle, reason: .initial)
    }

    // 仅在 handle 发生“真实变化”（登录/退出/切号）时重载
    func handleChanged(to newHandle: String) async {
        let h = newHandle.trimmed
        guard h != lastLoadedHandle else { return }
        lastLoadedHandle = h
        await reloadAllNewSession(handle: h, reason: .handleChanged)
    }

    // 手动刷新（下拉）
    func forceRefresh(currentHandle: String) async {
        let h = currentHandle.trimmed
        lastLoadedHandle = h
        await reloadAllNewSession(handle: h, reason: .manualRefresh)
    }

    // 展开时按需加载题目（带会话校验 + 行内错误）
    func ensureProblemsLoaded(contestId: Int, force: Bool = false) async {
        // 快照：是否已有/正在加载 & 当前会话
        let hasCache = (problemCache[contestId] != nil)
        let isLoading = loadingContestIds.contains(contestId)
        let tokenSnapshot = sessionToken
        if (hasCache && !force) || isLoading { return }

        loadingContestIds.insert(contestId)
        defer { loadingContestIds.remove(contestId) }

        for attempt in 0..<2 {
            do {
                let problems = try await CFAPI.shared.contestProblems(contestId: contestId, forceRefresh: force)
                guard tokenSnapshot == sessionToken else { return }
                self.problemCache[contestId] = problems
                self.problemErrorMap[contestId] = nil

                // ⭐️ 新增：精确补齐该场 AC 数（只在已登录且当前没值/为0时触发）
                let h = lastLoadedHandle
                if !h.isEmpty {
                    if self.solvedMap[contestId] == nil || self.solvedMap[contestId] == 0 {
                        let solved = try await CFAPI.shared.contestSolvedCount(contestId: contestId, handle: h, forceRefresh: force)
                        // 会话校验后再回写
                        guard tokenSnapshot == sessionToken else { return }
                        if self.solvedMap[contestId] != solved {
                            self.solvedMap[contestId] = solved
                        }
                    }
                }

                return
            } catch {
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                }
            }
        }

        guard tokenSnapshot == sessionToken else { return }
        self.problemErrorMap[contestId] = "该场题目加载失败，展开重试或下拉刷新。"
    }
    

    // MARK: - 私有：重载核心（并行加载 + 预取 + 会话隔离）

    private enum ReloadReason: String { case initial, handleChanged, manualRefresh }

    private func reloadAllNewSession(handle: String, reason: ReloadReason) async {
        // 开启新会话；不清空 vms / problemCache，避免切换时白屏
        let newToken = UUID()
        sessionToken = newToken
        // 重要：切换账号/刷新时，先清空与账号绑定的进度映射，避免短时间显示上一个账号的数据
        solvedMap = [:]
        problemAttemptMap = [:]
        problemAttemptByName = [:]
        loading = true
        pageError = nil
        defer { loading = false }

        do {
            let force = (reason != .initial)
            // 先尝试用磁盘缓存填充首屏（如有）
            if let cached = loadContestsFromDisk() {
                let items: [ContestVM] = cached.map { c in
                    let start = c.startTimeSeconds.map { Date(timeIntervalSince1970: TimeInterval($0)) }
                    return ContestVM(id: c.id, name: c.name, startTime: start, phase: c.phase, durationSeconds: c.durationSeconds)
                }.sorted { ($0.startTime ?? .distantPast) > ($1.startTime ?? .distantPast) }
                self.allItems = items
                self.vms = Array(items.prefix(pageSize))
                self.hasMore = items.count > self.vms.count
                // 首屏预取（缓存版）当前页所有场次题目和参与人数
                let ids = self.vms.map { $0.id }
                for cid in ids {
                    Task { [weak self] in
                        await self?.ensureProblemsLoaded(contestId: cid)
                    }
                }
                // 批量加载参与人数
                Task { [weak self] in
                    await self?.batchLoadParticipantCounts(contestIds: ids)
                }
                // 加载题目统计信息
                Task { [weak self] in
                    await self?.loadProblemStatistics()
                }
            }

            // 并行：完整比赛列表（包括未结束的） + （如已登录）最近提交
            async let contestsTask: [CFContest] = CFAPI.shared.allContests(forceRefresh: force)

            var subsTask: Task<[CFSubmission], Error>? = nil
            if !handle.isEmpty {
                subsTask = Task {
                    // 首屏用轻量数量，体感更快；稍后后台再补齐
                    try await CFAPI.shared.userSubmissionsLite(handle: handle, count: 1200, forceRefresh: force)
                }
            }

            // 列表（完整集合，本地分页）
            let contests = try await contestsTask
            let items: [ContestVM] = contests.map { c in
                let start = c.startTimeSeconds.map { Date(timeIntervalSince1970: TimeInterval($0)) }
                return ContestVM(id: c.id, name: c.name, startTime: start, phase: c.phase, durationSeconds: c.durationSeconds)
            }.sorted { ($0.startTime ?? .distantPast) > ($1.startTime ?? .distantPast) }

            // 会话校验后上屏
            guard newToken == sessionToken else { return }
            self.allItems = items
            self.vms = Array(items.prefix(pageSize))
            self.hasMore = items.count > self.vms.count
            // 更新磁盘缓存（裁剪一下体积，比如最多保留 1000 条）
            let trimmed = Array(contests.prefix(1000))
            self.saveContestsToDisk(trimmed)

            // 首屏预取（网络版）当前页所有场次题目和参与人数
            let onlineIds = self.vms.map { $0.id }
            for cid in onlineIds {
                Task { [weak self] in
                    await self?.ensureProblemsLoaded(contestId: cid)
                }
            }
            // 批量加载参与人数
            Task { [weak self] in
                await self?.batchLoadParticipantCounts(contestIds: onlineIds)
            }
            // 加载题目统计信息
            Task { [weak self] in
                await self?.loadProblemStatistics()
            }

            // 进度（如登录）
            if let subsTask {
                let subs = try await subsTask.value
                guard newToken == sessionToken else { return }
                self.solvedMap = buildSolvedMap(from: subs)
                self.problemAttemptMap = buildAttemptMap(from: subs)
                self.problemAttemptByName = buildAttemptByNameMap(from: subs)

                // 背景补齐到 3000（不阻塞 UI）
                let tokenSnapshot = sessionToken
                Task {
                    do {
                        let more = try await CFAPI.shared.userSubmissionsLite(handle: handle, count: 3000, forceRefresh: true)
                        await MainActor.run {
                            guard tokenSnapshot == self.sessionToken else { return }
                            let moreMap = self.buildSolvedMap(from: more)
                            if moreMap != self.solvedMap { self.solvedMap = moreMap }
                            let moreAttemptMap = self.buildAttemptMap(from: more)
                            if moreAttemptMap != self.problemAttemptMap { self.problemAttemptMap = moreAttemptMap }
                            let moreAttemptByName = self.buildAttemptByNameMap(from: more)
                            if moreAttemptByName != self.problemAttemptByName { self.problemAttemptByName = moreAttemptByName }
                        }
                    } catch { /* 静默即可 */ }
                }
            } else {
                self.solvedMap = [:]
                self.problemAttemptMap = [:]
                self.problemAttemptByName = [:]
            }

            // 预取最近 2 场题目（不阻塞）
            for cid in items.prefix(2).map({ $0.id }) {
                let tokenSnapshot = sessionToken
                Task { [weak self] in
                    guard let self else { return }
                    await self.ensureProblemsLoaded(contestId: cid)
                    // ensureProblemsLoaded 内部已有会话校验
                    _ = tokenSnapshot // 仅为语义提醒
                }
            }
        } catch {
            guard newToken == sessionToken else { return }
            self.pageError = error.localizedDescription
        }
    }

    // 底部出现时加载更多（本地分页，不触发网络）
    func loadMoreIfNeeded() {
        guard !loadingMore, hasMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        let current = vms.count
        let nextEnd = min(current + pageSize, allItems.count)
        if nextEnd > current {
            let more = allItems[current..<nextEnd]
            vms.append(contentsOf: more)
            hasMore = vms.count < allItems.count
            // 为新页队列预取题目和参与人数
            let newIds = more.map { $0.id }
            for cid in newIds {
                Task { [weak self] in
                    await self?.ensureProblemsLoaded(contestId: cid)
                }
            }
            // 批量加载新页面的参与人数
            Task { [weak self] in
                await self?.batchLoadParticipantCounts(contestIds: newIds)
            }
        } else {
            hasMore = false
        }
    }

    // MARK: - 工具

    private func buildSolvedMap(from subs: [CFSubmission]) -> [Int: Int] {
        var map: [Int: Set<String>] = [:]
        for s in subs where s.verdict == "OK" {
            guard let cid = s.problem.contestId else { continue }
            var set = map[cid] ?? Set<String>()
            set.insert(s.problem.index)
            map[cid] = set
        }
        return map.mapValues { $0.count }
    }

    private func buildAttemptMap(from subs: [CFSubmission]) -> [ProblemKey: ProblemAttemptState] {
        var map: [ProblemKey: ProblemAttemptState] = [:]
        for s in subs {
            guard let cid = s.problem.contestId else { continue }
            let key = ProblemKey(contestId: cid, index: s.problem.index)
            if s.verdict == "OK" {
                map[key] = .solved
            } else {
                if map[key] != .solved {
                    map[key] = .tried
                }
            }
        }
        return map
    }

    private func buildAttemptByNameMap(from subs: [CFSubmission]) -> [String: ProblemAttemptState] {
        var map: [String: ProblemAttemptState] = [:]
        for s in subs {
            let norm = normalizeProblemName(s.problem.name)
            if s.verdict == "OK" {
                map[norm] = .solved
            } else {
                if map[norm] != .solved {
                    map[norm] = .tried
                }
            }
        }
        return map
    }

    private func normalizeProblemName(_ name: String) -> String {
        let lowered = name.lowercased()
        let trimmed = lowered.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsedSpaces = trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return collapsedSpaces
    }
    
    // MARK: - 过滤器方法
    
    func applyFilters() {
        filteredVms = filterContests(allItems)
        
        // 重新分页显示过滤后的结果
        vms = Array(filteredVms.prefix(pageSize))
        hasMore = filteredVms.count > vms.count
    }
    
    private func filterContests(_ contests: [ContestVM]) -> [ContestVM] {
        var filtered = contests
        
        // 搜索文本过滤 - 改进匹配算法
        if !filter.searchText.trimmed.isEmpty {
            let searchText = filter.searchText.trimmed.lowercased()
            filtered = filtered.filter { vm in
                let contestName = vm.name.lowercased()
                let contestId = String(vm.id)
                
                // 优先匹配：完整单词匹配或ID精确匹配
                if contestName.contains(searchText) || contestId.contains(searchText) {
                    return true
                }
                
                // 分词匹配：搜索词包含多个单词时，每个单词都要在比赛名称中找到
                let searchWords = searchText.components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                
                if searchWords.count > 1 {
                    return searchWords.allSatisfy { word in
                        contestName.contains(word)
                    }
                }
                
                return false
            }
        }
        
        // 比赛类型过滤 - 只有当不是所有类型都选中时才过滤
        if filter.selectedDivisions != Set(ContestDivision.allCases) {
            filtered = filtered.filter { vm in
                filter.selectedDivisions.contains(vm.division)
            }
        }
        
        // 参与情况过滤 - 只有当不是所有情况都选中时才过滤
        if filter.selectedParticipations != Set(ParticipationStatus.allCases) {
            filtered = filtered.filter { vm in
                let hasParticipated = (solvedMap[vm.id] ?? 0) > 0 || hasTriedProblems(in: vm.id)
                
                if hasParticipated {
                    return filter.selectedParticipations.contains(.participated)
                } else {
                    return filter.selectedParticipations.contains(.notParticipated)
                }
            }
        }
        
        // 已参与过滤
        if filter.showOnlyParticipated {
            filtered = filtered.filter { vm in
                (solvedMap[vm.id] ?? 0) > 0 || hasTriedProblems(in: vm.id)
            }
        }
        
        // 已评级过滤（这里我们假设评级比赛都有rating相关信息，具体实现可能需要调整）
        if filter.showOnlyRated {
            // 通常Div1, Div2, Div3, Div4都是评级比赛
            filtered = filtered.filter { vm in
                vm.division != .other && vm.division != .educational
            }
        }
        
        // 未评级过滤
        if filter.showOnlyUnrated {
            filtered = filtered.filter { vm in
                vm.division == .other || vm.division == .educational
            }
        }
        
        // 时间范围过滤
        if let timeRange = filter.timeRange.dateRange {
            filtered = filtered.filter { vm in
                guard let startTime = vm.startTime else { return false }
                return timeRange.contains(startTime)
            }
        }
        
        // 排序
        filtered = sortContests(filtered, by: filter.sortOrder)
        
        return filtered
    }
    
    private func hasTriedProblems(in contestId: Int) -> Bool {
        // 检查是否在该比赛中尝试过任何题目
        return problemAttemptMap.keys.contains { $0.contestId == contestId }
    }
    
    private func sortContests(_ contests: [ContestVM], by order: ContestSortOrder) -> [ContestVM] {
        switch order {
        case .newest:
            return contests.sorted { ($0.startTime ?? .distantPast) > ($1.startTime ?? .distantPast) }
        case .oldest:
            return contests.sorted { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) }
        case .nameAsc:
            return contests.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .nameDesc:
            return contests.sorted { $0.name.localizedCompare($1.name) == .orderedDescending }
        case .idAsc:
            return contests.sorted { $0.id < $1.id }
        case .idDesc:
            return contests.sorted { $0.id > $1.id }
        }
    }
    
    // 获取显示的比赛列表（如果有过滤器激活则返回过滤结果，否则返回原始列表）
    var displayedContests: [ContestVM] {
        return filter.hasActiveFilters ? filteredVms : allItems
    }
    
    // 加载更多过滤后的结果
    func loadMoreFilteredIfNeeded() {
        guard !loadingMore, hasMore else { return }
        guard filter.hasActiveFilters else {
            loadMoreIfNeeded()
            return
        }
        
        loadingMore = true
        defer { loadingMore = false }
        
        let current = vms.count
        let nextEnd = min(current + pageSize, filteredVms.count)
        if nextEnd > current {
            let more = filteredVms[current..<nextEnd]
            vms.append(contentsOf: more)
            hasMore = vms.count < filteredVms.count
            
            // 为新页队列预取题目
            let newIds = more.map { $0.id }
            for cid in newIds {
                Task { [weak self] in
                    await self?.ensureProblemsLoaded(contestId: cid)
                }
            }
        } else {
            hasMore = false
        }
    }
    
    // MARK: - 批量加载参与人数
    
    private func batchLoadParticipantCounts(contestIds: [Int]) async {
        // 这里可以实现批量加载参与人数的逻辑
        // 由于 Codeforces API 没有直接的批量获取参与人数的接口
        // 这个方法暂时为空实现，避免编译错误
        // 未来可以根据需要添加具体实现
        for contestId in contestIds {
            // 可以在这里添加单个比赛参与人数的获取逻辑
            // 例如通过 contest.standings API 获取参与人数
            _ = contestId // 避免未使用变量警告
        }
    }
    
    // MARK: - 加载题目统计信息
    
    private func loadProblemStatistics() async {
        do {
            // 从 problemset.problems API 获取所有题目和统计信息
            let result = try await CFAPI.shared.problemsetProblems(forceRefresh: false)
            await MainActor.run {
                self.problemStatistics = result.statistics
            }
        } catch {
            print("Failed to load problem statistics: \(error)")
        }
    }
}

