import SwiftUI
import CryptoKit

struct ContestsView: View {
    @AppStorage("cfHandle") private var handle: String = ""
    @StateObject var store: ContestsStore

    // 仅在本视图内维护展开状态（如需跨页持久，可换成 SceneStorage 自行序列化）
    @State private var expanded: Set<Int> = []
    // 用于导航到题面页面，避免每个条目提前构建目的视图导致“全开”
    @State private var selectedProblem: CFProblem?

    var body: some View {
        listView
            .navigationTitle("比赛")
            // 初次进入只 ensure 一次（Store 会判断是否真的去打网）
            .task { await store.ensureLoaded(currentHandle: handle) }
            // 切换账号/退出登录才触发重载
            .onChange(of: handle.lowercased()) { _ in
                Task {
                    await store.handleChanged(to: handle)
                    // 主动刷新当前可见页的题目与进度
                    let ids = store.vms.map { $0.id }
                    for cid in ids { await store.ensureProblemsLoaded(contestId: cid, force: true) }
                }
            }
            // 手动下拉刷新
            .refreshable {
                await store.forceRefresh(currentHandle: handle)
                let ids = store.vms.map { $0.id }
                for cid in ids { await store.ensureProblemsLoaded(contestId: cid, force: true) }
            }
            // 仅在选择了某个题目时才构建并跳转目的视图
            .navigationDestination(item: $selectedProblem) { p in
                ProblemWebPage(problem: p)
            }
    }

    private var listView: some View {
        List {
            // 未登录提示
            if handle.trimmed.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("未填写 Handle，展示公共比赛列表")
                        Text("去“我的”页输入 Handle 后，可显示你的做题进度。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            // 页面级 loading / error
            if store.loading && store.vms.isEmpty {
                Section { HStack { ProgressView(); Text("加载中…") } }
            } else if let err = store.pageError {
                Section { Text(err).foregroundColor(.red) }
            }

            // 比赛列表
            ForEach(store.vms) { vm in
                Section {
                    DisclosureGroup(isExpanded: Binding(
                        get: { expanded.contains(vm.id) },
                        set: { isExpanding in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if isExpanding { _ = expanded.insert(vm.id) }
                                else { expanded.remove(vm.id) }
                            }
                            if isExpanding {
                                Task { await store.ensureProblemsLoaded(contestId: vm.id) }
                            }
                        }
                    )) {
                        // 展开内容：题目 / 行内错误 / 占位
                        if let err = store.problemErrorMap[vm.id] {
                            Text(err).foregroundColor(.red)
                        } else if let problems = store.problemCache[vm.id], !problems.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(problems, id: \.index) { p in
                                    Button {
                                        performLightHaptic()
                                        selectedProblem = p
                                    } label: {
                                        HStack { // 让“气泡”在行内水平居中
                                            Spacer(minLength: 0)
                                            HStack(spacing: 6) {
                                                HStack(spacing: 6) {
                                                    Text(p.index).bold()
                                                    Text(p.name).lineLimit(2)
                                                }
                                                .foregroundColor(colorForProblemRating(p.rating))
                                                Spacer(minLength: 8)
                                                Text(p.rating.map { "★\($0)" } ?? "★NULL")
                                                    .foregroundColor(colorForProblemRating(p.rating))
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(bubbleBackgroundColor(for: problemStateForDisplay(vmId: vm.id, p: p)))
                                            )
                                            Spacer(minLength: 0)
                                        }
                                    }
                                    .buttonStyle(PressScaleStyle())
                                }
                            }
                            .padding(.vertical, 6)
                        } else if store.loadingContestIds.contains(vm.id) {
                            HStack { ProgressView(); Text("加载题目…") }
                        } else {
                            Text("展开加载题目").foregroundColor(.secondary)
                        }
                    } label: {
                        rowHeader(vm)
                    }
                }
                .task { await store.ensureProblemsLoaded(contestId: vm.id) }
            }

            // 底部加载更多（类似“上拉加载”体验）
            if store.hasMore {
                Section {
                    HStack { Spacer(); ProgressView(); Text("正在加载更多…"); Spacer() }
                        .onAppear { store.loadMoreIfNeeded() }
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: expanded)
        .animation(.default, value: store.vms)
    }

    private func problemStateForDisplay(vmId: Int, p: CFProblem) -> ProblemAttemptState {
        // 先按 contestId+index 精确命中
        let key = ProblemKey(contestId: p.contestId ?? vmId, index: p.index)
        if let s = store.problemAttemptMap[key] { return s }
        // 退化到“按题名归并”的跨场匹配（处理 Div1/Div2 同题）
        let norm = normalizeProblemName(p.name)
        return store.problemAttemptByName[norm] ?? .none
    }

    private func normalizeProblemName(_ name: String) -> String {
        let lowered = name.lowercased()
        let trimmed = lowered.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsedSpaces = trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return collapsedSpaces
    }

    @ViewBuilder private func rowHeader(_ vm: ContestVM) -> some View {
        let trimmed = handle.trimmed
        let solved: Int = {
            if let probs = store.problemCache[vm.id] {
                return probs.reduce(0) { acc, p in
                    acc + (problemStateForDisplay(vmId: vm.id, p: p) == .solved ? 1 : 0)
                }
            } else {
                return store.solvedMap[vm.id] ?? 0
            }
        }()
        let total  = store.problemCache[vm.id]?.count ?? 0
        let isLoadingRow = store.loadingContestIds.contains(vm.id)

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.name).font(.body)
                HStack(spacing: 6) {
                    if trimmed.isEmpty {
                        Text("登录后显示做题进度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if total > 0 {
                        Text("已解决 \(solved) / \(total)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("已解决 \(solved)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if isLoadingRow { ProgressView().controlSize(.mini) }
                }
            }
            Spacer()
            if let t = vm.startTime {
                Text(Self.friendlyDate(t))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private static func friendlyDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 999
        if abs(days) <= 7 {
            let fmt = RelativeDateTimeFormatter()
            fmt.unitsStyle = .short
            return fmt.localizedString(for: date, relativeTo: Date())
        } else {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: date)
        }
    }
}

// MARK: - 题面 Web 页面
private struct ProblemWebPage: View {
    let problem: CFProblem
    @StateObject private var web = WebViewModel()
    @Environment(\.dismiss) private var dismiss
    @AppStorage("cfHandle") private var handle: String = ""
    @StateObject private var statusVM = SubmissionStatusViewModel()
    @State private var showStatusSheet: Bool = false
    @State private var cookieHandle: String? = nil

    private var urlString: String {
        let cid = problem.contestId ?? 0
        let idx = problem.index
        return "https://codeforces.com/contest/\(cid)/problem/\(idx)"
    }

    var body: some View {
        VStack(spacing: 0) {
            WebView(model: web)
                .onAppear {
                    // 只在首次进入时加载，避免从编辑器返回时页面被刷新
                    if !web.hasLoadedOnce {
                        web.load(urlString: urlString)
                    }
                    // 页面加载完成后，基于 Cookie 刷新当前登录 handle（实时反映登录/登出）
                    web.onDidFinishLoad = { _ in
                        Task { @MainActor in
                            self.cookieHandle = await CFCookieBridge.shared.readCurrentCFHandleFromWK()
                        }
                    }
                }
                .task {
                    // 仅依据实际 Cookie 判断是否已登录
                    cookieHandle = await CFCookieBridge.shared.readCurrentCFHandleFromWK()
                }
            toolbar
        }
        .navigationTitle("\(problem.index) · \(problem.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                let t = (cookieHandle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                Text(t.isEmpty ? "未登入 Codeforces 账号" : t)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .sheet(isPresented: $showStatusSheet) {
            SubmissionStatusView(
                vm: statusVM,
                problem: CFProblemIdentifier(contestId: problem.contestId ?? 0, index: problem.index, name: problem.name),
                handle: handle
            ) { showStatusSheet = false }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button(action: { web.goBack() }) {
                Image(systemName: "chevron.backward")
            }.disabled(!web.canGoBack)

            Button(action: { web.goForward() }) {
                Image(systemName: "chevron.forward")
            }.disabled(!web.canGoForward)

            Spacer()

            if web.isLoading {
                ProgressView(value: web.progress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 160)
            } else {
                Button(action: { web.reload() }) { Image(systemName: "arrow.clockwise") }
            }

            // 生成到编辑器：自动新建文件并导入样例
            Button(action: generateToEditor) {
                Image(systemName: "square.and.arrow.down.on.square")
            }

            // 判题状态：打开底部可拖拽 sheet 并开始跟踪当前题目最近一次提交
            Button(action: openStatusAndTrack) {
                Image(systemName: "list.bullet.rectangle")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .border(Color(UIColor.separator), width: 0.5)
    }

    private func generateToEditor() {
        let contestId = problem.contestId ?? 0
        let index = problem.index
        let fileName = "\(contestId)\(index).cpp"
        // 1) 抓样例
        web.extractCodeforcesSamples { pairs in
            // 2) 写文件到 Documents
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let target = dir.appendingPathComponent(fileName)
            let template = "#include <bits/stdc++.h>\n#define cy {cout << \\\"YES\\\" << endl; return;}\n#define cn {cout << \\\"NO\\\" << endl; return;}\n#define inf 0x3f3f3f3f\n#define llinf 0x3f3f3f3f3f3f3f3f\n// #define int long long\n#define db(a) cout << #a << \\\" = \\\" << a << endl\\n\nusing namespace std;\n\ntypedef pair<int, int> PII;\ntypedef tuple<int, int, int, int> St;\ntypedef long long ll;\n\nint T = 1;\nconst int N = 2e5 + 10, MOD = 998244353;\nint dx[] = {1, -1, 0, 0}, dy[] = {0, 0, 1, -1};\n\nvoid solve() {\n    \n}\n\nsigned main() {\n    ios::sync_with_stdio(false);\n    cin.tie(nullptr);\n\n    cin >> T;\n    while (T -- ) {\n        solve();\n    }\n    return 0;\n}\n"
            if !FileManager.default.fileExists(atPath: target.path) {
                try? template.data(using: .utf8)?.write(to: target)
            }

            // 3) 写入样例到编辑器的持久化（哈希路径规则与编辑器一致）
            let path = target.standardizedFileURL.path
            let hashed = Insecure.MD5.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            var appFolder = support.appendingPathComponent("CfEditor", isDirectory: true)
            if !FileManager.default.fileExists(atPath: appFolder.path) {
                try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
                var values = URLResourceValues(); values.isExcludedFromBackup = true; try? appFolder.setResourceValues(values)
            }
            var tcDir = appFolder.appendingPathComponent("TestCases", isDirectory: true)
            if !FileManager.default.fileExists(atPath: tcDir.path) {
                try? FileManager.default.createDirectory(at: tcDir, withIntermediateDirectories: true)
                var values = URLResourceValues(); values.isExcludedFromBackup = true; try? tcDir.setResourceValues(values)
            }
            let tcFile = tcDir.appendingPathComponent("\(hashed).json")
            let testCases: [[String: Any]] = pairs.isEmpty
                ? [["input": "", "expected": "", "received": "", "lastRunMs": NSNull(), "timedOut": false, "verdict": "none"]]
                : pairs.map { [
                    "input": $0.input,
                    "expected": $0.output,
                    "received": "",
                    "lastRunMs": NSNull(),
                    "timedOut": false,
                    "verdict": "none"
                ] }
            if let data = try? JSONSerialization.data(withJSONObject: testCases) {
                try? data.write(to: tcFile, options: .atomic)
            }

            // 4) 通过通知切换到编辑器并打开该文件
            NotificationCenter.default.post(name: .openEditorFileRequested, object: target)
            // 保留题面页，不主动关闭，便于返回继续查看题面
        }
    }

    private func openStatusAndTrack() {
        // 仅打开 Sheet，加载与跟踪逻辑放在 Sheet 内部 .task 中
        showStatusSheet = true
    }
}

// MARK: - 交互：按钮按压缩放动画（触摸即刻生效）
private struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressScaleView(configuration: configuration)
    }

    private struct PressScaleView: View {
        let configuration: Configuration
        @GestureState private var isTouching: Bool = false

        var body: some View {
            // 零距离拖拽可在触摸按下的第一时间进入 pressed 状态
            let touchDown = DragGesture(minimumDistance: 0)
                .updating($isTouching) { _, state, _ in
                    if state == false { state = true }
                }

            let pressed = configuration.isPressed || isTouching

            return configuration.label
                .contentShape(Rectangle())
                .scaleEffect(pressed ? 0.96 : 1.0)
                .opacity(pressed ? 0.92 : 1.0)
                .shadow(color: Color.black.opacity(pressed ? 0.2 : 0), radius: 8, x: 0, y: 4)
                .animation(.interactiveSpring(response: 0.08, dampingFraction: 0.9), value: pressed)
                .simultaneousGesture(touchDown)
        }
    }
}

// MARK: - 轻触反馈
private func performLightHaptic() {
#if os(iOS)
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
#endif
}

// MARK: - 颜色工具
private func bubbleBackgroundColor(for attempt: ProblemAttemptState) -> Color {
    switch attempt {
    case .solved: return Color.green.opacity(0.18)
    case .tried: return Color.red.opacity(0.18)
    case .none: return Color.clear
    }
}

private func colorForProblemRating(_ rating: Int?) -> Color {
    guard let r = rating else { return .black }
    return colorForRating(r)
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
