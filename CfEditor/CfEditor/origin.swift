import SwiftUI

struct ContentView: View {
    @AppStorage("cfHandle") private var cfHandle: String = ""
    @State private var lastCfHandle: String = ""

    enum Tab: String, Hashable { case contests, editor, profile }

    // 持久化当前所选 Tab（下次打开仍在上次的页面）
    @SceneStorage("tabSelection") private var selectionRaw: String = Tab.contests.rawValue
    private var selection: Binding<Tab> {
        Binding(
            get: { Tab(rawValue: selectionRaw) ?? .contests },
            set: { selectionRaw = $0.rawValue }
        )
    }

    // 让 Contests 的数据“跨 Tab 不丢”
    @StateObject private var contestsStore = ContestsStore()
    // 跨 Tab 打开编辑器文件的载体
    @State private var pendingOpenURL: URL? = nil

    @Environment(\.scenePhase) private var scenePhase   // ✅ 用于退到后台时收起键盘

    var body: some View {
        TabView(selection: selection) {
            navTab(title: "比赛", systemImage: "list.bullet", tag: .contests) {
                ContestsView(store: contestsStore)
                    .environmentObject(contestsStore) // ✅ 注入，子树可用 @EnvironmentObject
            }

            navTab(title: "编辑器", systemImage: "curlybraces", tag: .editor) {
                CodeEditorView()
                    .onReceive(NotificationCenter.default.publisher(for: .openEditorFileRequested)) { note in
                        if let url = note.object as? URL {
                            pendingOpenURL = url
                            selection.wrappedValue = .editor
                        }
                    }
            }

            navTab(title: "我的", systemImage: "person.crop.circle", tag: .profile) {
                ProfileView()
            }
        }
        // 首次进入：若未登录/未设置 handle，则自动定位到“我的”页
        .task {
            lastCfHandle = cfHandle
            if cfHandle.trimmed.isEmpty {
                selection.wrappedValue = .profile
            }
        }
        // 登录/登出切换 Tab
        .onChange(of: cfHandle) { newHandle in
            let wasLoggedOut = lastCfHandle.trimmed.isEmpty
            let isLoggedIn = !newHandle.trimmed.isEmpty
            let isLoggingOut = !wasLoggedOut && !isLoggedIn

            // 登录后保持在“我的”页，便于立即看到 Profile 详情
            if isLoggingOut {
                selection.wrappedValue = .profile
            }
            lastCfHandle = newHandle

            // 新增：无论当前是否在“比赛”页，只要 Handle 发生变化，立刻刷新比赛进度数据
            Task {
                await contestsStore.handleChanged(to: newHandle)
                // 若已经有可见的比赛列表，主动刷新当前页题目与进度
                let ids = contestsStore.vms.map { $0.id }
                for cid in ids { await contestsStore.ensureProblemsLoaded(contestId: cid, force: true) }
            }
        }
        // ✅ 切换 Tab 时自动收起键盘，避免编辑器工具条残留
        .onChange(of: selectionRaw) { _ in
            dismissKeyboard()
        }
        // ✅ 退到后台时也收起键盘
        .onChange(of: scenePhase) { phase in
            if phase != .active { dismissKeyboard() }
        }
        // 去掉键盘工具条，扩大代码区域
        .onChange(of: pendingOpenURL) { _, url in
            // 传递给编辑器通过 UserDefaults（编辑器 onAppear 恢复时读取）
            if let u = url { UserDefaults.standard.set(u.path, forKey: "CodeEditorView.lastFilePath") }
        }
    }

    // 统一封装每个 Tab：NavigationStack 包裹 + 标签
    @ViewBuilder
    private func navTab<Content: View>(
        title: String,
        systemImage: String,
        tag: Tab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack { content() }
            .tabItem { Label(title, systemImage: systemImage) }
            .tag(tag)
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        #endif
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Color utilities for rating
func colorForRating(_ rating: Int) -> Color {
    let darkRed = Color(red: 0.7, green: 0, blue: 0)
    switch rating {
    case ..<1200: return .gray
    case 1200..<1400: return .green
    case 1400..<1600: return .cyan
    case 1600..<1900: return .blue
    case 1900..<2100: return .purple
    case 2100..<2300: return .yellow
    case 2300..<2400: return .orange
    case 2400..<2600: return .red
    case 2600..<3000: return darkRed
    default: return darkRed
    }
}
