import SwiftUI

struct ContentView: View {
    @AppStorage("cfHandle") private var cfHandle: String = ""
    @State private var lastCfHandle: String = ""

    enum Tab: String, Hashable { 
        case contests, editor, oiwiki, profile 
        
        var displayName: String {
            switch self {
            case .contests: return "Practice"
            case .editor: return "Editor"
            case .oiwiki: return "OI Wiki"
            case .profile: return "Me"
            }
        }
        
        var iconName: String {
            switch self {
            case .contests: return "list.bullet"
            case .editor: return "chevron.left.forwardslash.chevron.right"
            case .oiwiki: return "book.closed"
            case .profile: return "person.crop.circle"
            }
        }
    }

    // 持久化当前所选 Tab（下次打开仍在上次的页面）
    @SceneStorage("tabSelection") private var selectionRaw: String = Tab.contests.rawValue
    private var selection: Binding<Tab> {
        Binding(
            get: { Tab(rawValue: selectionRaw) ?? .contests },
            set: { 
                // 添加触觉反馈
                #if canImport(UIKit)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                #endif
                selectionRaw = $0.rawValue 
            }
        )
    }

    // 让 Contests 的数据"跨 Tab 不丢"
    @StateObject private var contestsStore = ContestsStore()
    // 跨 Tab 打开编辑器文件的载体
    @State private var pendingOpenURL: URL? = nil

    @Environment(\.scenePhase) private var scenePhase   // ✅ 用于退到后台时收起键盘

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: selection) {
                navTab(tag: .contests) {
                    ContestsView(store: contestsStore)
                        .environmentObject(contestsStore) // ✅ 注入，子树可用 @EnvironmentObject
                }

                navTab(tag: .editor) {
                    CodeEditorView()
                        .onReceive(NotificationCenter.default.publisher(for: .openEditorFileRequested)) { note in
                            if let url = note.object as? URL {
                                pendingOpenURL = url
                                selection.wrappedValue = .editor
                            }
                        }
                }

                navTab(tag: .oiwiki) {
                    OIWikiView()
                }

                navTab(tag: .profile) {
                    ProfileView()
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .animation(.easeInOut(duration: 0.2), value: selection.wrappedValue)
            .onAppear {
                // 隐藏系统默认的 Tab Bar
                #if canImport(UIKit)
                let appearance = UITabBarAppearance()
                appearance.configureWithTransparentBackground()
                appearance.backgroundColor = .clear
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
                UITabBar.appearance().isHidden = true
                #endif
            }
            
            // 自定义 Tab Bar - 始终在最上层
            CustomTabBar(selection: selection)
                .zIndex(999)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // 首次进入：若未登录/未设置 handle，则自动定位到"我的"页
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

            // 登录后保持在"我的"页，便于立即看到 Profile 详情
            if isLoggingOut {
                selection.wrappedValue = .profile
            }
            lastCfHandle = newHandle

            // 新增：无论当前是否在"比赛"页，只要 Handle 发生变化，立刻刷新比赛进度数据
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

    // 统一封装每个 Tab：NavigationStack 包裹
    @ViewBuilder
    private func navTab<Content: View>(
        tag: Tab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack { content() }
            .tag(tag)
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        #endif
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selection: ContentView.Tab
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var animation
    
    private let tabs: [ContentView.Tab] = [.contests, .editor, .oiwiki, .profile]
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部分隔线
            Divider()
            
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    TabBarButton(
                        tab: tab,
                        isSelected: selection == tab,
                        namespace: animation
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selection = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .background(
                Color(UIColor.systemBackground)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
}

struct TabBarButton: View {
    let tab: ContentView.Tab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // 图标
                Image(systemName: tab.iconName)
                    .font(.system(size: isSelected ? 24 : 22, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected 
                            ? Color.accentColor 
                            : Color.secondary
                    )
                    .scaleEffect(isPressed ? 0.85 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isPressed)
                
                // 标签文字
                Text(tab.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .contentShape(Rectangle())
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(TabButtonStyle(isPressed: $isPressed))
    }
}

// 自定义按钮样式处理按压效果
struct TabButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { pressed in
                isPressed = pressed
            }
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

// MARK: - GitHub 风格颜色（基于提交数和AC数的绿色渐变）
func colorForGitHubStyle(submissionCount: Int, acCount: Int) -> Color {
    // Normal 模式配色方案：
    // - 有提交但没AC：最多到第二级绿色
    // - 有AC才能达到更深的绿色
    
    if submissionCount == 0 {
        return Color(red: 0.921, green: 0.929, blue: 0.941)  // #ebedf0 无提交
    }
    
    if acCount == 0 {
        // 有提交但没AC：最多到第二级绿色
        if submissionCount >= 4 {
            return Color(red: 0.251, green: 0.769, blue: 0.388)  // #40c463 中绿（最多）
        } else {
            return Color(red: 0.365, green: 0.835, blue: 0.502)  // #5dd580 中浅绿
        }
    } else {
        // 有AC：根据AC数量加深
        switch acCount {
        case 1...2:
            return Color(red: 0.251, green: 0.769, blue: 0.388)  // #40c463 中绿
        case 3...5:
            return Color(red: 0.188, green: 0.631, blue: 0.306)  // #30a14e 深绿
        default:
            return Color(red: 0.137, green: 0.549, blue: 0.267)  // #228c44 最深绿（调浅）
        }
    }
}
