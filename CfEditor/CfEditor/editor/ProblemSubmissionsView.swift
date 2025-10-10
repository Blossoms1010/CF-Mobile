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
            
            Text("Loading Submissions")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }
    
    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Failed to Load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task { await loadSubmissions() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }
    
    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Submissions", systemImage: "clock.badge.questionmark")
        } description: {
            if handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("No public submissions found for this problem")
            } else {
                Text("\(handle) has not submitted this problem yet")
            }
        } actions: {
            Button("Refresh") {
                Task { await loadSubmissions() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
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
        VStack(alignment: .leading, spacing: 6) {
            // 第一行：判定结果
            HStack {
                Image(systemName: verdictIcon(submission.verdict))
                    .foregroundColor(verdictColor(submission.verdict))
                    .font(.system(size: 13))
                
                Text(verdictDisplayText(submission.verdict, passedTests: submission.passedTestCount))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(verdictColor(submission.verdict))
                
                Spacer()
                
                if let lang = submission.programmingLanguage {
                    Text(lang)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // 第二行：性能指标
            HStack(spacing: 12) {
                if let time = submission.timeConsumedMillis {
                    Text("\(time) ms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let memory = submission.memoryConsumedBytes {
                    Text("\(memory / 1024) KB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // 第三行：提交信息
            HStack(spacing: 12) {
                Text("#\(submission.id)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(formatSubmissionTime(submission.creationTimeSeconds))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let author = submission.author,
                   let firstMember = author.members.first {
                    let userInfo = userInfos[firstMember.handle]
                    
                    Text(firstMember.handle)
                        .font(.caption2)
                        .foregroundColor(ratingColor(userInfo?.rating))
                }
            }
        }
        .padding(.vertical, 6)
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
    
    private func verdictIcon(_ verdict: String?) -> String {
        switch verdict {
        case "OK": return "checkmark.circle.fill"
        case "WRONG_ANSWER": return "xmark.circle.fill"
        case "TIME_LIMIT_EXCEEDED": return "clock.badge.exclamationmark.fill"
        case "MEMORY_LIMIT_EXCEEDED": return "memorychip.fill"
        case "RUNTIME_ERROR": return "exclamationmark.triangle.fill"
        case "COMPILATION_ERROR": return "hammer.fill"
        case "PARTIAL": return "circle.lefthalf.filled"
        case "TESTING": return "ellipsis.circle.fill"
        case "SKIPPED": return "forward.fill"
        default: return "questionmark.circle.fill"
        }
    }
    
    private func verdictDisplayText(_ verdict: String?, passedTests: Int?) -> String {
        let baseText: String
        switch verdict {
        case "OK": baseText = "Accepted"
        case "WRONG_ANSWER": baseText = "Wrong answer"
        case "TIME_LIMIT_EXCEEDED": baseText = "Time limit exceeded"
        case "MEMORY_LIMIT_EXCEEDED": baseText = "Memory limit exceeded"
        case "RUNTIME_ERROR": baseText = "Runtime error"
        case "COMPILATION_ERROR": baseText = "Compilation error"
        case "PARTIAL": baseText = "部分正确"
        case "TESTING": baseText = "评测中"
        case "SKIPPED": baseText = "跳过"
        default: baseText = verdict ?? "未知"
        }
        
        // 对于需要显示测试点的情况
        switch verdict {
        case "TIME_LIMIT_EXCEEDED", "MEMORY_LIMIT_EXCEEDED", "WRONG_ANSWER", "RUNTIME_ERROR":
            if let passed = passedTests {
                return "\(baseText) on test \(passed + 1)"
            }
            return baseText
        default:
            return baseText
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
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
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
            
            // 只有在有提交记录时才获取用户信息
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
                // 如果指定了用户，进一步验证提交记录确实属于该用户
                if !handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let targetHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let validSubmissions = result.filter { submission in
                        guard let authorHandle = submission.author?.members.first?.handle else { return false }
                        return authorHandle.lowercased() == targetHandle
                    }
                    self.submissions = validSubmissions
                } else {
                    self.submissions = result
                }
                
                self.userInfos = fetchedUserInfos
                self.isLoading = false
                self.error = nil // 确保清除之前的错误
            }
        } catch {
            await MainActor.run {
                self.submissions = [] // 确保清空提交记录
                self.userInfos = [:]
                self.error = self.formatError(error)
                self.isLoading = false
            }
        }
    }
    
    // 格式化错误信息，提供更友好的错误提示
    private func formatError(_ error: Error) -> String {
        let errorDescription = error.localizedDescription
        
        // 检查是否是网络错误
        if errorDescription.contains("network") || errorDescription.contains("连接") {
            return "网络连接失败，请检查网络设置后重试"
        }
        
        // 检查是否是用户不存在的错误
        if errorDescription.contains("not found") || errorDescription.contains("不存在") {
            return "用户不存在或用户名有误"
        }
        
        // 检查是否是比赛不存在的错误
        if errorDescription.contains("contest") && errorDescription.contains("not found") {
            return "比赛不存在或已被删除"
        }
        
        // 其他错误返回原始描述
        return errorDescription
    }
}
