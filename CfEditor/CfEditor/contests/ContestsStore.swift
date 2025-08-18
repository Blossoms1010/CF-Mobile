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

    // —— “唯一真源” —— //
    @Published var problemCache: [Int: [CFProblem]] = [:] // contestId -> problems
    @Published var solvedMap: [Int: Int] = [:]            // contestId -> solved count
    @Published var loadingContestIds: Set<Int> = []       // 行内加载指示
    @Published var problemErrorMap: [Int: String] = [:]   // 行内错误文案
    @Published var problemAttemptMap: [ProblemKey: ProblemAttemptState] = [:] // 单题做题状态
    @Published var problemAttemptByName: [String: ProblemAttemptState] = [:]   // 跨场同题（按名称归并）

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
                    return ContestVM(id: c.id, name: c.name, startTime: start)
                }.sorted { ($0.startTime ?? .distantPast) > ($1.startTime ?? .distantPast) }
                self.allItems = items
                self.vms = Array(items.prefix(pageSize))
                self.hasMore = items.count > self.vms.count
                // 首屏预取（缓存版）当前页所有场次题目
                let ids = self.vms.map { $0.id }
                for cid in ids {
                    Task { [weak self] in
                        await self?.ensureProblemsLoaded(contestId: cid)
                    }
                }
            }

            // 并行：完整比赛列表 + （如已登录）最近提交
            async let contestsTask: [CFContest] = CFAPI.shared.allFinishedContests(forceRefresh: force)

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
                return ContestVM(id: c.id, name: c.name, startTime: start)
            }.sorted { ($0.startTime ?? .distantPast) > ($1.startTime ?? .distantPast) }

            // 会话校验后上屏
            guard newToken == sessionToken else { return }
            self.allItems = items
            self.vms = Array(items.prefix(pageSize))
            self.hasMore = items.count > self.vms.count
            // 更新磁盘缓存（裁剪一下体积，比如最多保留 1000 条）
            let trimmed = Array(contests.prefix(1000))
            self.saveContestsToDisk(trimmed)

            // 首屏预取（网络版）当前页所有场次题目
            let onlineIds = self.vms.map { $0.id }
            for cid in onlineIds {
                Task { [weak self] in
                    await self?.ensureProblemsLoaded(contestId: cid)
                }
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
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
