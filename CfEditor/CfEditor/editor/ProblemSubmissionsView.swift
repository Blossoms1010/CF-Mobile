import SwiftUI

struct ProblemSubmissionsView: View {
    let problem: CFProblemIdentifier
    let handle: String
    
    @State private var submissions: [CFSubmission] = []
    @State private var userInfos: [String: CFUserInfo] = [:]
    @State private var isLoading: Bool = false
    @State private var error: String?
    
    var body: some View {
        Group {
            if isLoading && submissions.isEmpty {
                loadingView
            } else if let error = error {
                errorView(error)
            } else if submissions.isEmpty {
                emptyView
            } else {
                submissionsList
            }
        }
        .task {
            await loadSubmissions()
        }
        .refreshable {
            await loadSubmissions()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载中...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("加载失败")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                Task { await loadSubmissions() }
            }
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("暂无提交记录")
                .font(.headline)
            Text("这道题还没有提交记录")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var submissionsList: some View {
        List {
            ForEach(submissions) { submission in
                submissionRow(submission)
            }
        }
        .listStyle(.plain)
    }
    
    private func submissionRow(_ submission: CFSubmission) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // 状态指示
                Circle()
                    .fill(verdictColor(submission.verdict))
                    .frame(width: 10, height: 10)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(verdictDisplayText(submission.verdict))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(verdictColor(submission.verdict))
                        
                        Spacer()
                        
                        if let lang = submission.programmingLanguage {
                            Text(lang)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack {
                        if let time = submission.timeConsumedMillis {
                            Text("\(time) ms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let memory = submission.memoryConsumedBytes {
                            Text("/ \(memory / 1024) KB")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(formatSubmissionTime(submission.creationTimeSeconds))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 提交编号和用户信息行
            HStack {
                // 提交编号
                Text("# \(submission.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 用户信息
                if let author = submission.author,
                   let firstMember = author.members.first {
                    let userInfo = userInfos[firstMember.handle]
                    
                    Text(firstMember.handle)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ratingColor(userInfo?.rating))
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func verdictColor(_ verdict: String?) -> Color {
        switch verdict {
        case "OK": return .green
        case "WRONG_ANSWER": return .red
        case "TIME_LIMIT_EXCEEDED": return .orange
        case "MEMORY_LIMIT_EXCEEDED": return .purple
        case "RUNTIME_ERROR": return .red
        case "COMPILATION_ERROR": return .gray
        case "PARTIAL": return .yellow
        case "TESTING": return .blue
        case "SKIPPED": return .gray
        default: return .secondary
        }
    }
    
    private func verdictDisplayText(_ verdict: String?) -> String {
        switch verdict {
        case "OK": return "AC"
        case "WRONG_ANSWER": return "WA"
        case "TIME_LIMIT_EXCEEDED": return "TLE"
        case "MEMORY_LIMIT_EXCEEDED": return "MLE"
        case "RUNTIME_ERROR": return "RE"
        case "COMPILATION_ERROR": return "CE"
        case "PARTIAL": return "部分正确"
        case "TESTING": return "评测中"
        case "SKIPPED": return "跳过"
        default: return verdict ?? "未知"
        }
    }
    
    private func formatSubmissionTime(_ timeSeconds: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timeSeconds))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func ratingColor(_ rating: Int?) -> Color {
        guard let rating = rating else { return .secondary }
        
        switch rating {
        case ..<1200: return .gray
        case 1200..<1400: return .green
        case 1400..<1600: return Color.cyan
        case 1600..<1900: return .blue
        case 1900..<2100: return .purple
        case 2100..<2300: return Color.orange
        case 2300..<2400: return Color.orange
        case 2400..<2600: return .red
        case 2600..<3000: return .red
        default: return .red
        }
    }
    
    private func ratingTitle(_ rating: Int?) -> String {
        guard let rating = rating else { return "未定级" }
        
        switch rating {
        case ..<1200: return "Newbie"
        case 1200..<1400: return "Pupil"
        case 1400..<1600: return "Specialist"
        case 1600..<1900: return "Expert"
        case 1900..<2100: return "Candidate Master"
        case 2100..<2300: return "Master"
        case 2300..<2400: return "International Master"
        case 2400..<2600: return "Grandmaster"
        case 2600..<3000: return "International Grandmaster"
        default: return "Legendary Grandmaster"
        }
    }
    
    private func loadSubmissions() async {
        isLoading = true
        error = nil
        
        do {
            let result: [CFSubmission]
            
            // 如果没有提供handle，则获取该题的所有公开提交记录
            if handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result = try await CFStatusAPI.publicSubmissionsFor(problem: problem, limit: 50)
            } else {
                result = try await CFStatusAPI.submissionsFor(problem: problem, handle: handle, limit: 50)
            }
            
            // 获取所有提交者的用户信息
            let uniqueHandles = Set(result.compactMap { submission in
                submission.author?.members.first?.handle
            })
            
            var fetchedUserInfos: [String: CFUserInfo] = [:]
            
            if !uniqueHandles.isEmpty {
                do {
                    let userInfoList = try await CFAPI.shared.userInfos(handles: Array(uniqueHandles))
                    for userInfo in userInfoList {
                        fetchedUserInfos[userInfo.handle] = userInfo
                    }
                } catch {
                    // 如果获取用户信息失败，不影响提交记录的显示
                    print("获取用户信息失败: \(error)")
                }
            }
            
            await MainActor.run {
                submissions = result
                userInfos = fetchedUserInfos
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
}
