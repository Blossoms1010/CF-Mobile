import Foundation
import Combine

final class SubmissionStatusViewModel: ObservableObject {
    struct TrackedItem: Identifiable, Equatable {
        let id: Int
        let runId: Int
        let sourceContestId: Int
        let problem: CFProblemIdentifier
        let language: String?
        let createdAt: Date
        var verdict: CFVerdict
        var passedTests: Int
        var timeMs: Int
        var memBytes: Int

        static func == (lhs: TrackedItem, rhs: TrackedItem) -> Bool { lhs.id == rhs.id }
    }

    @Published private(set) var items: [TrackedItem] = []
    @Published var isPolling: Bool = false
    @Published var isLoadingAll: Bool = false
    @Published var errorMessage: String?
    @Published var submitterInfo: CFUserInfo?

    private var cancellables = Set<AnyCancellable>()
    private var pollingTask: Task<Void, Never>?

    // 将最新项放在列表顶部，并去重 runId
    private func upsert(_ item: TrackedItem) {
        if let idx = items.firstIndex(where: { $0.runId == item.runId }) {
            items[idx] = item
        } else {
            items.insert(item, at: 0)
        }
    }

    func clearError() { errorMessage = nil }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
    }

    // 加载某题的全部历史提交
    func loadAll(for problem: CFProblemIdentifier, handle: String) async {
        await MainActor.run {
            self.isLoadingAll = true
            self.items = []
            self.errorMessage = nil
        }
        do {
            async let subsTask: [CFSubmission] = CFStatusAPI.submissionsFor(problem: problem, handle: handle, limit: 1000)
            async let infoTask: CFUserInfo = CFAPI.shared.userInfo(handle: handle)

            let subs = try await subsTask
            let info = try? await infoTask
            // 过滤掉 CANCELLED 的提交
            let mapped = subs.compactMap { s -> TrackedItem? in
                let v = CFVerdict.from(s.verdict)
                if v == .cancelled { return nil }
                return self.item(from: s, problem: problem)
            }
            await MainActor.run {
                self.items = mapped
                self.submitterInfo = info
                self.isLoadingAll = false
            }
        } catch is CancellationError {
            await MainActor.run { self.isLoadingAll = false }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoadingAll = false
            }
        }
    }

    // 启动对指定题目的最新一次提交的跟踪；若无法找到最近提交，则不启动轮询
    func startTrackingLatest(for problem: CFProblemIdentifier, handle: String) {
        stopPolling()
        isPolling = true
        pollingTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                // 首轮等待 1s，给 CF 入库一点时间
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let sub = try await CFStatusAPI.latestSubmission(for: problem, handle: handle) else {
                    await MainActor.run {
                        self.errorMessage = "未找到最近的提交"
                        self.isPolling = false
                    }
                    return
                }
                let sourceContestId = sub.problem.contestId ?? problem.contestId
                await self.track(runId: sub.id, sourceContestId: sourceContestId, of: problem, handle: handle, seed: sub)
            } catch is CancellationError { return }
            catch {
                await MainActor.run { self.errorMessage = error.localizedDescription; self.isPolling = false }
            }
        }
    }

    func track(runId: Int, sourceContestId: Int, of problem: CFProblemIdentifier, handle: String, seed: CFSubmission? = nil) async {
        // 先用 seed 更新一次
        if let s = seed { await MainActor.run { self.upsert(self.item(from: s, problem: problem)) } }
        var lastVerdict: CFVerdict = seed.map { CFVerdict.from($0.verdict) } ?? .unknown
        var attempts = 0
        let hardStopAt = Date().addingTimeInterval(60) // 最多轮询 60s
        // 终止条件：拿到终判、超时 60s、或取消任务
        while !Task.isCancelled {
            do {
                // 轮询频率 2s
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let sub = try await CFStatusAPI.fetchByRunId(contestId: sourceContestId, handle: handle, runId: runId) else {
                    attempts += 1
                    if attempts >= 8 || Date() > hardStopAt { // 最多等 ~16s 或超时
                        await MainActor.run { self.isPolling = false }
                        break
                    }
                    continue
                }
                // 忽略 CANCELLED 的提交项
                let current = self.item(from: sub, problem: problem)
                if current.verdict == .cancelled {
                    continue
                }
                await MainActor.run { self.upsert(current) }
                lastVerdict = current.verdict
                if lastVerdict.isTerminal {
                    await MainActor.run { self.isPolling = false }
                    break
                }
            } catch is CancellationError { break }
            catch {
                await MainActor.run { self.errorMessage = error.localizedDescription; self.isPolling = false }
                break
            }
        }
    }

    private func item(from sub: CFSubmission, problem: CFProblemIdentifier) -> TrackedItem {
        TrackedItem(
            id: sub.id,
            runId: sub.id,
            sourceContestId: sub.contestId ?? sub.problem.contestId ?? problem.contestId,
            problem: problem,
            language: sub.programmingLanguage,
            createdAt: Date(timeIntervalSince1970: TimeInterval(sub.creationTimeSeconds)),
            verdict: CFVerdict.from(sub.verdict),
            passedTests: sub.passedTestCount ?? 0,
            timeMs: sub.timeConsumedMillis ?? 0,
            memBytes: sub.memoryConsumedBytes ?? 0
        )
    }
}


