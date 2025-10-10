//
//  ProfileViewSheets.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import SwiftUI

// MARK: - 所有提交 Sheet

struct AllSubmissionsSheet: View {
    let handle: String
    
    @State private var submissions: [CFSubmission] = []
    @State private var isLoading: Bool = false
    @State private var isRefreshing: Bool = false
    @State private var error: String?
    @State private var nextFrom: Int = 1
    private let pageSize: Int = 100

    var body: some View {
        List {
            if let error { 
                Text(error).foregroundStyle(.orange) 
            }
            
            ForEach(submissions) { s in
                VStack(spacing: 4) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(colorForVerdict(CFVerdict.from(s.verdict)))
                            .frame(width: 8, height: 8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(problemTitle(s))
                                .font(.subheadline).bold()
                                .lineLimit(2)
                            
                            // 提交编号
                            Text("#\(s.id)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            // 判题状态单独一行
                            Text(CFVerdict.from(s.verdict).textWithTestInfo(passedTests: s.passedTestCount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            // 语言、时间、内存一行
                            HStack(spacing: 6) {
                                if let lang = s.programmingLanguage, !lang.isEmpty {
                                    Text(lang)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                
                                if let timeMs = s.timeConsumedMillis {
                                    Text("\(timeMs) ms")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                if let memoryBytes = s.memoryConsumedBytes {
                                    Text("\(memoryBytes / 1024) KB")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Text(shortTime(from: s.creationTimeSeconds))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if isLoading {
                HStack { 
                    Spacer()
                    ProgressView()
                    Spacer() 
                }
                .listRowSeparator(.hidden)
            } else if !submissions.isEmpty {
                Color.clear.frame(height: 1)
                    .onAppear { Task { await loadMore() } }
            }
        }
        .listStyle(.plain)
        .task { await initialLoad() }
        .refreshable { await refresh() }
    }

    private func initialLoad() async { 
        await refresh() 
    }

    private func refresh() async {
        await MainActor.run { 
            isRefreshing = true
            error = nil
            submissions = []
            nextFrom = 1 
        }
        
        do {
            let first = try await CFAPI.shared.userSubmissionsPage(handle: handle, from: nextFrom, count: pageSize, forceRefresh: true)
            await MainActor.run {
                submissions = first
                nextFrom = first.count + 1
                isRefreshing = false
            }
        } catch {
            await MainActor.run { 
                self.error = error.localizedDescription
                self.isRefreshing = false 
            }
        }
    }

    private func loadMore() async {
        guard !isLoading else { return }
        await MainActor.run { isLoading = true; error = nil }
        
        do {
            let more = try await CFAPI.shared.userSubmissionsPage(handle: handle, from: nextFrom, count: pageSize)
            await MainActor.run {
                if !more.isEmpty {
                    submissions.append(contentsOf: more)
                    nextFrom += more.count
                }
                isLoading = false
            }
        } catch {
            await MainActor.run { 
                self.error = error.localizedDescription
                self.isLoading = false 
            }
        }
    }

    private func colorForVerdict(_ v: CFVerdict) -> Color {
        switch v {
        case .ok: return .green
        case .wrongAnswer: return .red
        case .timeLimit, .memoryLimit, .runtimeError, .compilationError, .presentationError: return .orange
        case .testing, .idlen: return .gray
        default: return .gray
        }
    }

    private func problemTitle(_ s: CFSubmission) -> String {
        let idx = s.problem.index
        let name = s.problem.name
        if let cid = s.contestId ?? s.problem.contestId {
            return "\(cid) \(idx) · \(name)"
        } else {
            return "\(idx) · \(name)"
        }
    }

    private func shortTime(from epoch: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epoch))
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: date)
    }
}

// MARK: - 所有比赛 Sheet

struct AllContestsSheet: View {
    let contests: [ContestRecord]
    
    var body: some View {
        List {
            if contests.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("暂无比赛记录")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
            } else {
                ForEach(contests) { contest in
                    ContestRecordRow(contest: contest)
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - 单个题目提交记录 Sheet

struct ProblemSubmissionsSheet: View {
    let contestId: Int
    let problemIndex: String
    let problemName: String
    let handle: String
    
    @State private var submissions: [CFSubmission] = []
    @State private var isLoading: Bool = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // 未输入 handle，显示提示
                VStack(spacing: 20) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 60))
                        .foregroundStyle(.orange)
                    
                    Text("需要输入 Handle")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("请在\"我的\"页面输入你的 Codeforces Handle 以查看提交记录")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("知道了")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .cornerRadius(10)
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else {
                // 已输入 handle，显示提交记录
                List {
                    if let error {
                        Section {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if isLoading && submissions.isEmpty {
                        Section {
                            ForEach(0..<5, id: \.self) { _ in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(width: 8, height: 8)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.secondary.opacity(0.2))
                                            .frame(height: 16)
                                        
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.secondary.opacity(0.15))
                                            .frame(width: 150, height: 12)
                                    }
                                }
                                .shimmer()
                            }
                        }
                    } else if submissions.isEmpty && !isLoading {
                        Section {
                            VStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                Text("暂无提交记录")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        }
                    } else {
                        Section {
                            ForEach(submissions) { submission in
                                ProblemSubmissionRow(submission: submission)
                            }
                        } header: {
                            HStack {
                                Text("题目: \(problemName)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("共 \(submissions.count) 次提交")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .task { await loadSubmissions() }
                .refreshable { await loadSubmissions(forceRefresh: true) }
            }
        }
    }
    
    private func loadSubmissions(forceRefresh: Bool = false) async {
        await MainActor.run { 
            isLoading = true
            error = nil
        }
        
        do {
            // 使用 CFStatusAPI 的 submissionsFor 方法获取当前题目的提交
            let problemIdentifier = CFProblemIdentifier(
                contestId: contestId,
                index: problemIndex,
                name: problemName
            )
            let problemSubmissions = try await CFStatusAPI.submissionsFor(
                problem: problemIdentifier,
                handle: handle,
                limit: 1000
            )
            
            await MainActor.run {
                submissions = problemSubmissions
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = "加载失败: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

// MARK: - 题目提交记录行

struct ProblemSubmissionRow: View {
    let submission: CFSubmission
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Circle()
                    .fill(colorForVerdict(CFVerdict.from(submission.verdict)))
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    // 提交编号
                    Text("#\(submission.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // 判题状态 - 允许换行显示
                    Text(CFVerdict.from(submission.verdict).textWithTestInfo(passedTests: submission.passedTestCount))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // 语言和性能指标
                    HStack(spacing: 6) {
                        if let lang = submission.programmingLanguage, !lang.isEmpty {
                            Text(lang)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        
                        if let timeMs = submission.timeConsumedMillis {
                            Text("\(timeMs) ms")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let memoryBytes = submission.memoryConsumedBytes {
                            Text("\(memoryBytes / 1024) KB")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Text(shortTime(from: submission.creationTimeSeconds))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 6)
    }
    
    private func colorForVerdict(_ v: CFVerdict) -> Color {
        switch v {
        case .ok: return .green
        case .wrongAnswer: return .red
        case .timeLimit, .memoryLimit, .runtimeError, .compilationError, .presentationError: return .orange
        case .testing, .idlen: return .gray
        default: return .gray
        }
    }
    
    private func shortTime(from epoch: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epoch))
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) 分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) 小时前"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days) 天前"
        } else {
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .short
            return df.string(from: date)
        }
    }
}

