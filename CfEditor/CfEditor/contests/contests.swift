import SwiftUI
import CryptoKit

// MARK: - 练习页面模式
enum PracticeMode: String, CaseIterable {
    case contests = "Contests"
    case problemset = "Problems"
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
        .navigationTitle("Practice")
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
                    TextField("Search Contests...", text: $store.filter.searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            store.applyFilters()
                        }
                        .onChange(of: store.filter.searchText) { _ in
                            // 实时搜索 - 每次输入都触发过滤
                            store.applyFilters()
                        }
                }
                .padding(.vertical, 4)
            }

            // 页面级 loading / error
            if store.loading && store.vms.isEmpty {
                Section { HStack { ProgressView(); Text("Loading") } }
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
                                Task { 
                                    await store.ensureProblemsLoaded(contestId: vm.id)
                                    // 参与人数在首屏批量加载，这里不需要单独加载
                                }
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
                                        HStack(spacing: 8) {
                                                                        // 状态图标区域 - 固定在最左侧
                            let problemState = problemStateForDisplay(vmId: vm.id, p: p)
                            HStack {
                                circledStatusIcon(for: problemState)
                            }
                            .frame(width: 20, alignment: .leading)
                                            
                                            // 题目信息区域 - 保持原始位置
                                            HStack(spacing: 6) {
                                                Text(p.index).bold()
                                                    .foregroundColor(colorForProblemRating(p.rating))
                                                Text(p.name).lineLimit(2)
                                                    .foregroundColor(colorForProblemRating(p.rating))
                                                Spacer()
                                                Text(p.rating.map { "\($0)" } ?? "Unknown")
                                                    .foregroundColor(colorForProblemRating(p.rating))
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(Color.clear)
                                            )
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(PressScaleStyle())
                                }
                            }
                            .padding(.vertical, 6)
                        } else if store.loadingContestIds.contains(vm.id) {
                            HStack { ProgressView(); Text("Loading...") }
                        } else {
                            Text("展开加载题目").foregroundColor(.secondary)
                        }
                    } label: {
                        rowHeader(vm)
                    }
                }
                .task { 
                    await store.ensureProblemsLoaded(contestId: vm.id)
                    // 参与人数在首屏批量加载，这里不需要单独加载
                }
            }

            // 底部加载更多（类似"上拉加载"体验）
            if store.hasMore {
                Section {
                    HStack { Spacer(); ProgressView(); Text("Loading..."); Spacer() }
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
                        Text("Solved \(solved) / \(total)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Solved \(solved)")
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
                    TextField("Search Problems...", text: $problemsetStore.filter.searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            problemsetStore.applyFilters()
                        }
                }
                .padding(.vertical, 4)
            }
            
            // 页面级 loading / error
            if problemsetStore.loading && problemsetStore.problems.isEmpty {
                Section { HStack { ProgressView(); Text("Loading") } }
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
                            HStack(spacing: 8) {
                                // 状态图标区域 - 固定在最左侧
                                let problemStatus = problemsetStore.getProblemStatus(for: problem)
                                HStack {
                                    circledStatusIcon(for: problemStatus)
                                }
                                .frame(width: 20, alignment: .leading)
                                
                                // 题目信息区域 - 保持原始位置
                                HStack(spacing: 6) {
                                    Text("\(problem.contestId ?? 0)\(problem.index)").bold()
                                    Text(problem.name).lineLimit(2)
                                }
                                .foregroundColor(colorForProblemRating(problem.rating))
                                Spacer(minLength: 8)
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(problem.rating.map { "\($0)" } ?? "Unknown")
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
                                    .fill(Color.clear)
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
                    HStack { Spacer(); ProgressView(); Text("Loading"); Spacer() }
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

// MARK: - 翻译数据模型
struct TranslationSegment: Codable, Identifiable {
    let id: UUID
    let original: String
    let translated: String
    
    init(original: String, translated: String) {
        self.id = UUID()
        self.original = original
        self.translated = translated
    }
}

// 题目部分类型
enum ProblemSection: String, CaseIterable, Codable {
    case legend = "Legend"          // 题目描述
    case input = "Input"           // 输入说明
    case output = "Output"         // 输出说明
    case note = "Note"             // 注意事项
    case interaction = "Interaction" // 交互说明
    case hack = "Hack"             // Hack说明
    case tutorial = "Tutorial"     // 题解
    
    var displayName: String {
        switch self {
        case .legend: return "题目描述"
        case .input: return "输入"
        case .output: return "输出"
        case .note: return "注意事项"
        case .interaction: return "交互"
        case .hack: return "Hack"
        case .tutorial: return "题解"
        }
    }
    
    var icon: String {
        switch self {
        case .legend: return "doc.text"
        case .input: return "square.and.arrow.down"
        case .output: return "square.and.arrow.up"
        case .note: return "exclamationmark.triangle"
        case .interaction: return "person.2.circle"
        case .hack: return "hammer"
        case .tutorial: return "lightbulb"
        }
    }
}

// 按部分组织的翻译内容
struct SectionTranslation: Codable, Identifiable {
    let id: UUID
    let section: ProblemSection
    let segments: [TranslationSegment]
    
    init(section: ProblemSection, segments: [TranslationSegment]) {
        self.id = UUID()
        self.section = section
        self.segments = segments
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
    @State private var isReadingSettingsPresented: Bool = false
    @State private var isTranslationPresented: Bool = false
    @State private var sectionTranslations: [SectionTranslation] = []
    @AppStorage("problemReaderFontSize") private var readerFontSize: Int = 17
    @AppStorage("problemReaderLineHeight") private var readerLineHeight: Double = 1.75

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
                    // 加载保存的翻译结果
                    loadTranslationResult()
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
                    .navigationTitle("Submissions")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("close") { isSubmissionsPresented = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isReadingSettingsPresented) {
            readingSettingsSheet
        }
        .sheet(isPresented: $isTranslationPresented) {
            translationSheet
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

            // 阅读设置
            Button(action: { isReadingSettingsPresented = true }) {
                Image(systemName: "textformat.size")
            }
            .accessibilityLabel("阅读设置")

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
            
            // 翻译按钮：一键将题面翻译为中文 / 查看已有翻译
            Button(action: {
                startStreamingTranslation()
            }) {
                if isTranslating {
                    HStack(spacing: 4) { 
                        ProgressView().controlSize(.small)
                        Text("翻译中…") 
                    }
                } else if sectionTranslations.isEmpty {
                    Label("翻译", systemImage: "character.book.closed")
                } else {
                    Label("查看翻译", systemImage: "character.book.closed.fill")
                        .foregroundColor(.blue)
                }
            }
            .disabled(isTranslating || (!sectionTranslations.isEmpty ? false : !isAITranslatorConfigured))
            
            // 如果有翻译内容，添加长按菜单
            if !sectionTranslations.isEmpty {
                Menu {
                    Button(action: { isTranslationPresented = true }) {
                        Label("查看翻译", systemImage: "eye")
                    }
                    Button {
                        startStreamingTranslation()
                    } label: {
                        Label("重新翻译", systemImage: "arrow.clockwise")
                    }
                    .disabled(isTranslating || !isAITranslatorConfigured)
                    Button(role: .destructive) {
                        clearTranslations()
                    } label: {
                        Label("清除翻译", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                } primaryAction: {
                    isTranslationPresented = true
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .border(Color(UIColor.separator), width: 0.5)
    }

    private var isAITranslatorConfigured: Bool {
        !aiTransModel.trimmed.isEmpty && !aiTransProxyApi.trimmed.isEmpty
    }
    
    @ViewBuilder
    private var translationSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if isTranslating {
                        // 翻译进度显示
                        VStack(spacing: 20) {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .controlSize(.large)
                                Text("正在翻译题面...")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("请稍候，AI正在为您生成中文翻译")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(24)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                        .padding(.top, 40)
                    } else if sectionTranslations.isEmpty {
                        ContentUnavailableView(
                            "暂无翻译内容",
                            systemImage: "doc.text",
                            description: Text("点击翻译按钮获取题面的中文翻译")
                        )
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        // 按部分显示翻译内容
                        ForEach(sectionTranslations) { sectionTranslation in
                            VStack(alignment: .leading, spacing: 8) {
                                // 部分标题
                                HStack {
                                    Image(systemName: sectionTranslation.section.icon)
                                        .foregroundColor(.blue)
                                    Text(sectionTranslation.section.displayName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                
                                // 翻译内容
                                ForEach(sectionTranslation.segments) { segment in
                                    LatexRenderedTextView(segment.translated, fontSize: 16)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 1)
                                        .id(segment.id) // 确保每个段落有稳定的ID
                                        .onAppear {
                                            // 添加小延迟，避免同时初始化太多WebView
                                            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.1...0.3)) {
                                                // 触发渲染
                                            }
                                        }
                                }
                            }
                            .background(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 6)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("题面翻译")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") {
                        isTranslationPresented = false
                    }
                }
                
                if !sectionTranslations.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button(action: copyAllTranslations) {
                                Label("copy translated text", systemImage: "doc.on.doc")
                            }
                            Button(action: clearTranslations) {
                                Label("reset", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    @ViewBuilder
    private var readingSettingsSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Adjust theses for better experience")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 20) {
                    // 字体大小设置
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Front Size")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(readerFontSize)px")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack(spacing: 12) {
                            Text("A")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Slider(value: Binding(
                                get: { Double(readerFontSize) },
                                set: { newValue in
                                    readerFontSize = Int(newValue)
                                    applyReadingSettings()
                                }
                            ), in: 14...22, step: 1)
                            
                            Text("A")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // 行间距设置
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Line Spacing")
                                .fontWeight(.medium)
                            Spacer()
                            Text(String(format: "%.2f", readerLineHeight))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack(spacing: 12) {
                            Text("Dense")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Slider(value: $readerLineHeight, in: 1.4...2.2, step: 0.05)
                                .onChange(of: readerLineHeight) { _, _ in
                                    applyReadingSettings()
                                }
                            
                            Text("Loose")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // 预设方案
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Settings")
                            .fontWeight(.medium)
                        
                        HStack(spacing: 12) {
                            presetButton(title: "Comfortable", fontSize: 17, lineHeight: 1.75)
                            presetButton(title: "Eye Care", fontSize: 18, lineHeight: 1.8)
                            presetButton(title: "Compact", fontSize: 15, lineHeight: 1.6)
                        }
                    }
                }
                .padding(20)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .navigationTitle("Reading Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("done") {
                        isReadingSettingsPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private func presetButton(title: String, fontSize: Int, lineHeight: Double) -> some View {
        Button(action: {
            readerFontSize = fontSize
            readerLineHeight = lineHeight
            applyReadingSettings()
        }) {
            Text(title)
                .font(.footnote)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.accentColor.opacity(0.1))
                )
                .foregroundStyle(.primary)
        }
    }
    
    private func applyReadingSettings() {
        // 将设置应用到WebView中的阅读模式
        let script = """
        (function() {
            if (document.getElementById('cf-reader-container')) {
                document.documentElement.style.setProperty('--cf-font-size', '\(readerFontSize)px');
                document.documentElement.style.setProperty('--cf-line-height', '\(readerLineHeight)');
            }
        })();
        """
        web.webView?.evaluateJavaScript(script) { _, _ in }
    }

    private func startStreamingTranslation() {
        // 立即打开翻译sheet
        isTranslationPresented = true
        
        // 如果已有翻译内容，直接显示，否则开始翻译
        if sectionTranslations.isEmpty {
            translateProblemToChinese()
        }
    }
    
    private func translateProblemToChinese() {
        guard !isTranslating else { return }
        isTranslating = true
        web.collectSectionBasedSegments { sectionData in
            Task {
                guard isAITranslatorConfigured else { 
                    await MainActor.run { self.isTranslating = false }
                    return 
                }
                
                var resultSections: [SectionTranslation] = []
                
                // 按照预定义顺序处理各部分，确保显示顺序正确
                let sectionOrder: [ProblemSection] = [.legend, .input, .output, .note, .interaction, .hack, .tutorial]
                
                for section in sectionOrder {
                    guard let segments = sectionData[section.rawValue], !segments.isEmpty else { continue }
                    let translated = await AITranslator.translateENtoZH(segments, model: aiTransModel.trimmed, proxyAPI: aiTransProxyApi.trimmed, apiKey: aiTransApiKey.trimmed.isEmpty ? nil : aiTransApiKey.trimmed)
                    
                    let translatedSegments = zip(segments, translated).map { original, translated in
                        TranslationSegment(original: original, translated: translated)
                    }
                    
                    resultSections.append(SectionTranslation(section: section, segments: translatedSegments))
                }
                
                await MainActor.run {
                    self.sectionTranslations = resultSections
                    self.saveTranslationResult()
                    self.isTranslating = false
                }
            }
        }
    }

    // MARK: - 翻译结果持久化
    private func translationCacheKey() -> String {
        let cid = problem.contestId ?? 0
        let idx = problem.index
        return "translation_\(cid)_\(idx)"
    }
    
    private func saveTranslationResult() {
        let key = translationCacheKey()
        do {
            let data = try JSONEncoder().encode(sectionTranslations)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Failed to save translation result: \(error)")
        }
    }
    
    private func loadTranslationResult() {
        let key = translationCacheKey()
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        do {
            sectionTranslations = try JSONDecoder().decode([SectionTranslation].self, from: data)
        } catch {
            print("Failed to load translation result: \(error)")
        }
    }
    
    private func clearTranslations() {
        sectionTranslations = []
        let key = translationCacheKey()
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    private func copyAllTranslations() {
        let allTranslations = sectionTranslations.flatMap { sectionTranslation in
            [sectionTranslation.section.displayName + ":"] + sectionTranslation.segments.map { $0.translated }
        }.joined(separator: "\n\n")
        #if canImport(UIKit)
        UIPasteboard.general.string = allTranslations
        #elseif canImport(AppKit)
        NSPasteboard.general.setString(allTranslations, forType: .string)
        #endif
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

// MARK: - 状态图标工具
private func statusIcon(for attempt: ProblemAttemptState) -> String {
    switch attempt {
    case .solved: return "✓"
    case .tried: return "✗"
    case .none: return ""
    }
}

private func statusIconColor(for attempt: ProblemAttemptState) -> Color {
    switch attempt {
    case .solved: return .green
    case .tried: return .red
    case .none: return .secondary
    }
}

// MARK: - 圆圈状态图标组件
@ViewBuilder
private func circledStatusIcon(for attempt: ProblemAttemptState) -> some View {
    let icon = statusIcon(for: attempt)
    let iconColor = statusIconColor(for: attempt)
    
    ZStack {
        // 圆圈边框
        Circle()
            .stroke(iconColor, lineWidth: 1.5)
            .frame(width: 18, height: 18)
        
        // 图标内容
        if !icon.isEmpty {
            Text(icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(iconColor)
        }
    }
    .frame(width: 20, height: 20)
}

// MARK: - 颜色工具
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
