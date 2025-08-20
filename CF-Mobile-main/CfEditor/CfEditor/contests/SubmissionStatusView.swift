import SwiftUI

struct SubmissionStatusView: View {
    @ObservedObject var vm: SubmissionStatusViewModel
    let problem: CFProblemIdentifier
    let handle: String
    let onClose: () -> Void
    
    @State private var presentedURL: IdentifiedURL? = nil

    var body: some View {
        VStack(spacing: 8) {
            Capsule().fill(Color.secondary.opacity(0.5)).frame(width: 38, height: 5).padding(.top, 6)
            HStack {
                Text("判题状态").font(.headline)
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark") }
            }
            .padding(.horizontal, 12)

            if let err = vm.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
                    Text(err).foregroundColor(.orange)
                    Spacer()
                    Button("重试") { vm.clearError() }
                }
                .padding(.horizontal, 12)
            }

            List {
                ForEach(vm.items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Button {
                                openSubmissionWeb(for: item)
                            } label: {
                                Text("#\(item.runId)")
                                    .font(.subheadline)
                                    .foregroundStyle(.tint)
                            }
                            Text(format(item.createdAt)).font(.subheadline).foregroundColor(.secondary)
                            Spacer()
                            Text(item.verdict.displayText)
                                .fontWeight(item.verdict == .ok ? .semibold : .regular)
                                .foregroundColor(color(for: item.verdict))
                        }
                        if let u = vm.submitterInfo {
                            HStack(spacing: 6) {
                                Text("提交者:").foregroundColor(.secondary)
                                Text(u.handle)
                                    .font(.subheadline).bold()
                                    .foregroundStyle(colorForRank(u.rank))
                            }
                            .font(.caption)
                        }
                        HStack(spacing: 12) {
                            Text("题目: #\(item.sourceContestId) \(item.problem.index)")
                            if let lang = item.language { Text(lang).foregroundColor(.secondary).lineLimit(1) }
                        }
                        .font(.caption)
                        HStack(spacing: 12) {
                            Text("通过: \(item.passedTests)")
                            Text("时间: \(item.timeMs)ms")
                            Text("内存: \(formatBytes(item.memBytes))")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)

            HStack(spacing: 12) {
                if vm.isLoadingAll {
                    ProgressView().controlSize(.small)
                    Text("正在加载历史提交…").font(.footnote).foregroundColor(.secondary)
                    Spacer()
                } else if vm.isPolling {
                    ProgressView().controlSize(.small)
                    Text("正在查询最新提交…").font(.footnote).foregroundColor(.secondary)
                    Spacer()
                    Button("停止") { vm.stopPolling() }
                } else {
                    Image(systemName: "checkmark.circle").foregroundColor(.green)
                    Text("已停止轮询").font(.footnote).foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .presentationDetents([.fraction(0.25), .fraction(0.5), .large])
        .presentationDragIndicator(.visible)
        .sheet(item: $presentedURL) { item in
            NavigationStack {
                SubmissionWebView(url: item.url, targetURLString: item.targetURLString)
                    .navigationTitle("查看提交")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("刷新") { NotificationCenter.default.post(name: .init("SubmissionWebView.ReloadRequested"), object: nil) } } }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task {
            let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                vm.errorMessage = "未配置 Handle，无法获取你的提交状态"
            } else {
                await vm.loadAll(for: problem, handle: trimmed)
                vm.startTrackingLatest(for: problem, handle: trimmed)
            }
        }
        .onDisappear { vm.stopPolling() }
    }

    private func openSubmissionWeb(for item: SubmissionStatusViewModel.TrackedItem) {
        let cid = item.sourceContestId
        let runId = item.runId
        let path = "/contest/\(cid)/submission/\(runId)"
        let target = "https://codeforces.com\(path)"
        if let url = URL(string: target) {
            self.presentedURL = IdentifiedURL(url: url, targetURLString: target)
        }
    }

    private func color(for v: CFVerdict) -> Color {
        switch v {
        case .ok: return .green
        case .wrongAnswer, .runtimeError, .compilationError: return .red
        case .timeLimit, .memoryLimit: return .orange
        case .testing, .idlen: return .blue
        default: return .primary
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1<<20 { return String(format: "%.1fMB", Double(bytes)/1048576.0) }
        if bytes >= 1<<10 { return String(format: "%.1fKB", Double(bytes)/1024.0) }
        return "\(bytes)B"
    }

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    private func format(_ date: Date) -> String {
        SubmissionStatusView.df.string(from: date)
    }
}

// MARK: - 提交详情 WebView（底部弹出，可上拉展开）
private struct SubmissionWebView: View {
    let url: URL
    let targetURLString: String
    @StateObject private var web = WebViewModel()
    @State private var didAutoRedirect: Bool = false
    @State private var loginRetryCount: Int = 0
    @State private var submissionRedirectRetryCount: Int = 0
    
    var body: some View {
        WebView(model: web)
            .onAppear {
                if !web.hasLoadedOnce {
                    web.load(urlString: url.absoluteString)
                }
            }
            // 登录流守卫：确保成功登录后最终落在提交详情页
            .onChange(of: web.isLoading) { _, loading in
                guard !loading else { return }
                guard let wv = web.webView, let cur = wv.url else { return }
                let host = (cur.host ?? "").lowercased()
                let path = cur.path.lowercased()
                if host.contains("codeforces.com") {
                    let isSubmission = path.contains("/submission/")
                    let isLoginPage = path.contains("/enter")
                    let isProfile = path.contains("/profile/")
                    Task {
                        let handle = await CFCookieBridge.shared.readCurrentCFHandleFromWK()
                        let loggedIn = !(handle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                        if loggedIn {
                            if isSubmission {
                                submissionRedirectRetryCount = 0
                                didAutoRedirect = false
                                loginRetryCount = 0
                            } else if isProfile || !isSubmission {
                                if submissionRedirectRetryCount < 4 {
                                    submissionRedirectRetryCount += 1
                                    web.load(urlString: targetURLString)
                                }
                            }
                        } else {
                            if !isSubmission && !isLoginPage && loginRetryCount < 3 {
                                loginRetryCount += 1
                                web.load(urlString: targetURLString)
                            }
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("SubmissionWebView.ReloadRequested"))) { _ in
                web.reloadFromOrigin()
            }
    }
}

// 便于使用 .sheet(item:) 的可识别 URL 容器
private struct IdentifiedURL: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let targetURLString: String
}


