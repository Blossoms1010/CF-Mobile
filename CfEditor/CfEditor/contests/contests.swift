import SwiftUI
import CryptoKit

// MARK: - 练习页面模式
enum PracticeMode: String, CaseIterable {
    case contests = "比赛"
    case problemset = "题库"
}

struct ContestsView: View {
    @AppStorage("cfHandle") private var handle: String = ""
    @StateObject var store: ContestsStore
    @StateObject private var problemsetStore = ProblemsetStore()

    // 分段控制器状态
    @State private var selectedMode: PracticeMode = .contests
    
    // 仅在本视图内维护展开状态（如需跨页持久，可换成 SceneStorage 自行序列化）
    @State private var expanded: Set<Int> = []
    // 用于导航到题面页面，避免每个条目提前构建目的视图导致"全开"
    @State private var selectedProblem: CFProblem?
    
    // 题库相关状态
    @State private var showingFilterSheet: Bool = false
    
    // 比赛相关状态
    @State private var showingContestFilterSheet: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 分段控制器
            Picker("模式", selection: $selectedMode) {
                ForEach(PracticeMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // 根据选择的模式显示不同内容
            Group {
                switch selectedMode {
                case .contests:
                    contestsListView
                case .problemset:
                    problemsetListView
                }
            }
        }
        .navigationTitle("练习")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectedMode == .problemset {
                    Button {
                        showingFilterSheet = true
                    } label: {
                        Image(systemName: problemsetStore.filter.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                } else if selectedMode == .contests {
                    Button {
                        showingContestFilterSheet = true
                    } label: {
                        Image(systemName: store.filter.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        // 初次进入时确保数据加载
        .task {
            await store.ensureLoaded(currentHandle: handle)
            await problemsetStore.ensureLoaded(currentHandle: handle)
        }
        // 切换账号/退出登录才触发重载
        .onChange(of: handle.lowercased()) { _ in
            Task {
                await store.handleChanged(to: handle)
                await problemsetStore.handleChanged(to: handle)
                
                // 主动刷新当前可见页的题目与进度
                if selectedMode == .contests {
                    let ids = store.vms.map { $0.id }
                    for cid in ids { await store.ensureProblemsLoaded(contestId: cid, force: true) }
                }
            }
        }
        // 手动下拉刷新
        .refreshable {
            switch selectedMode {
            case .contests:
                await store.forceRefresh(currentHandle: handle)
                let ids = store.vms.map { $0.id }
                for cid in ids { await store.ensureProblemsLoaded(contestId: cid, force: true) }
            case .problemset:
                await problemsetStore.forceRefresh(currentHandle: handle)
            }
        }
        // 仅在选择了某个题目时才构建并跳转目的视图
        .navigationDestination(item: $selectedProblem) { p in
            ProblemWebPage(problem: p)
        }
        // 题库过滤器弹窗
        .sheet(isPresented: $showingFilterSheet) {
            ProblemsetFilterView(store: problemsetStore)
        }
        // 比赛过滤器弹窗
        .sheet(isPresented: $showingContestFilterSheet) {
            ContestFilterView(store: store)
        }
    }

    private var contestsListView: some View {
        List {
            // 未登录提示
            if handle.trimmed.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("未填写 Handle，展示公共比赛列表")
                        Text("去\"我的\"页输入 Handle 后，可显示你的做题进度。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // 搜索框
            Section {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索比赛...", text: $store.filter.searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            store.applyFilters()
                        }
                        .onChange(of: store.filter.searchText) { _ in
                            // 实时搜索
                            if store.filter.searchText.trimmed.isEmpty {
                                store.applyFilters()
                            }
                        }
                }
                .padding(.vertical, 4)
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

            // 底部加载更多（类似"上拉加载"体验）
            if store.hasMore {
                Section {
                    HStack { Spacer(); ProgressView(); Text("正在加载更多…"); Spacer() }
                        .onAppear { 
                            if store.filter.hasActiveFilters {
                                store.loadMoreFilteredIfNeeded()
                            } else {
                                store.loadMoreIfNeeded()
                            }
                        }
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

    // MARK: - 题库视图
    private var problemsetListView: some View {
        List {
            // 未登录提示
            if handle.trimmed.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("未填写 Handle，展示公共题库")
                        Text("去\"我的\"页输入 Handle 后，可显示你的做题进度。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // 搜索框
            Section {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索题目...", text: $problemsetStore.filter.searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            problemsetStore.applyFilters()
                        }
                }
                .padding(.vertical, 4)
            }
            
            // 页面级 loading / error
            if problemsetStore.loading && problemsetStore.problems.isEmpty {
                Section { HStack { ProgressView(); Text("加载中…") } }
            } else if let err = problemsetStore.error {
                Section { Text(err).foregroundColor(.red) }
            }
            
            // 题目列表
            ForEach(problemsetStore.displayedProblems) { problem in
                Section {
                    Button {
                        performLightHaptic()
                        selectedProblem = problem
                    } label: {
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                HStack(spacing: 6) {
                                    Text("\(problem.contestId ?? 0)\(problem.index)").bold()
                                    Text(problem.name).lineLimit(2)
                                }
                                .foregroundColor(colorForProblemRating(problem.rating))
                                Spacer(minLength: 8)
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(problem.rating.map { "★\($0)" } ?? "★NULL")
                                        .foregroundColor(colorForProblemRating(problem.rating))
                                    if let solvedCount = problemsetStore.problemStatistics[problem.id] {
                                        Text("✓\(formatSolvedCount(solvedCount))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(bubbleBackgroundColor(for: problemsetStore.getProblemStatus(for: problem)))
                            )
                            
                            // 显示标签
                            if shouldShowTags(for: problem, store: problemsetStore) {
                                ProblemTagsView(
                                    tags: problem.tags ?? []
                                )
                            }
                        }
                    }
                    .buttonStyle(PressScaleStyle())
                    .listRowSeparator(.hidden)
                }
            }
            
            // 底部加载更多
            if problemsetStore.canLoadMore {
                Section {
                    HStack { Spacer(); ProgressView(); Text("正在加载更多…"); Spacer() }
                        .onAppear { problemsetStore.loadMoreIfNeeded() }
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: problemsetStore.displayedProblems)
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
    @AppStorage("aiTransModelName") private var aiTransModelName: String = ""
    @AppStorage("aiTransModel") private var aiTransModel: String = ""
    @AppStorage("aiTransProxyApi") private var aiTransProxyApi: String = ""
    @AppStorage("aiTransApiKey") private var aiTransApiKey: String = ""
    @State private var cookieHandle: String? = nil
    @State private var isTranslating: Bool = false
    @State private var isSubmissionsPresented: Bool = false

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
                if !t.isEmpty {
                    Text(t)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .sheet(isPresented: $isSubmissionsPresented) {
            NavigationStack {
                let effectiveHandle = {
                    if let ch = cookieHandle, !ch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return ch
                    }
                    return UserDefaults.standard.string(forKey: "cfHandle")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                }()
                ProblemSubmissionsView(problem: CFProblemIdentifier(contestId: problem.contestId ?? 0, index: problem.index, name: problem.name), handle: effectiveHandle)
                    .navigationTitle("提交记录")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") { isSubmissionsPresented = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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


            // 查看提交记录按钮 - 需要登录状态
            let cookieHandleExists = !(cookieHandle ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let userDefaultsHandle = UserDefaults.standard.string(forKey: "cfHandle")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let userDefaultsHandleExists = !userDefaultsHandle.isEmpty
            let hasValidHandle = cookieHandleExists || userDefaultsHandleExists
            
            Button(action: { isSubmissionsPresented = true }) {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundColor(hasValidHandle ? .blue : .gray)
            }
            .disabled(!hasValidHandle)
            
            // 翻译按钮：一键将题面翻译为中文
            Button(action: translateProblemToChinese) {
                if isTranslating {
                    HStack(spacing: 4) { ProgressView().controlSize(.small); Text("翻译中…") }
                } else {
                    Label("翻译", systemImage: "character.book.closed")
                }
            }
            .disabled(isTranslating || !isAITranslatorConfigured)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .border(Color(UIColor.separator), width: 0.5)
    }

    private var isAITranslatorConfigured: Bool {
        !aiTransModel.trimmed.isEmpty && !aiTransProxyApi.trimmed.isEmpty
    }

    private func translateProblemToChinese() {
        guard !isTranslating else { return }
        isTranslating = true
        web.collectTranslatableSegments { segments in
            Task {
                guard isAITranslatorConfigured else { await MainActor.run { self.isTranslating = false }; return }
                let translated = await AITranslator.translateENtoZH(segments, model: aiTransModel.trimmed, proxyAPI: aiTransProxyApi.trimmed, apiKey: aiTransApiKey.trimmed.isEmpty ? nil : aiTransApiKey.trimmed)
                await MainActor.run {
                    self.web.applyTranslations(translated) {
                        self.isTranslating = false
                    }
                }
            }
        }
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
            let template = """
#include <bits/stdc++.h>
#define cy {cout << "YES" << endl; return;}
#define cn {cout << "NO" << endl; return;}
#define inf 0x3f3f3f3f
#define llinf 0x3f3f3f3f3f3f3f3f
// #define int long long
#define db(a) cout << #a << " = " << (a) << '\\n'

using namespace std;

typedef pair<int, int> PII;
typedef tuple<int, int, int, int> St;
typedef long long ll;

int T = 1;
const int N = 2e5 + 10, MOD = 998244353;
int dx[] = {1, -1, 0, 0}, dy[] = {0, 0, 1, -1};

void solve() {
    
}

signed main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    cin >> T;
    while (T -- ) {
        solve();
    }
    return 0;
}
"""
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

// MARK: - 工具函数
private func formatSolvedCount(_ count: Int) -> String {
    if count >= 1000000 {
        return String(format: "%.1fM", Double(count) / 1000000)
    } else if count >= 1000 {
        return String(format: "%.1fK", Double(count) / 1000)
    } else {
        return String(count)
    }
}

private func formatParticipantCount(_ count: Int) -> String {
    if count >= 1000000 {
        return String(format: "%.1fM", Double(count) / 1000000)
    } else if count >= 1000 {
        return String(format: "%.1fK", Double(count) / 1000)
    } else {
        return String(count)
    }
}

// MARK: - 标签显示逻辑
@MainActor
private func shouldShowTags(for problem: CFProblem, store: ProblemsetStore) -> Bool {
    let status = store.getProblemStatus(for: problem)
    
    // 如果是已解决的题目，总是显示标签
    if status == .solved {
        return true
    }
    
    // 如果是未解决的题目，根据设置决定是否显示
    return store.filter.showUnsolvedTags
}

// MARK: - 标签视图组件
private struct ProblemTagsView: View {
    let tags: [String]
    
    var body: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.15))
                            )
                            .foregroundColor(Color.secondary)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }
}
