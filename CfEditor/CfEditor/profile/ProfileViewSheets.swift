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
                                .lineLimit(1)
                            
                            HStack(spacing: 6) {
                                Text(CFVerdict.from(s.verdict).textWithTestInfo(passedTests: s.passedTestCount))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
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
            return "#\(cid) \(idx) · \(name)"
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

