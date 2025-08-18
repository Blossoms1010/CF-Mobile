import SwiftUI
import CryptoKit
import WebKit

struct CodeEditorView: View {
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("cfHandle") private var cfHandle: String = ""

    @State private var code: String = ""

    @State private var language: String = "plaintext"
    // 主题跟随系统，无需用户选择
    @State private var readOnly: Bool = false
    @State private var fontSize: Int = 14
    // 行号默认开启，去掉开关
    @State private var minimap: Bool = false

    // 文件管理
    @State private var isFilesPresented: Bool = false
    @State private var currentFileURL: URL? = nil
    @State private var isSaveAsPresented: Bool = false
    @State private var saveAsFileName: String = ""
    @State private var isActionsPresented: Bool = false
    @State private var undoRequestToken: Int = 0
    @State private var redoRequestToken: Int = 0
    @State private var canUndo: Bool = false
    @State private var canRedo: Bool = false

    // 脏标记 & 保存提示
    @State private var isDirty: Bool = false
    @State private var lastSavedCode: String = ""
    @State private var toastText: String = ""
    @State private var showToast: Bool = false

    private let lastFilePathKey: String = "CodeEditorView.lastFilePath"
    private let showFilesOnLaunchKey: String = "CodeEditorView.showFilesOnLaunch"
    private let autosaveFileName: String = "__autosave__.json"
    private let autosaveEnabledKey: String = "CodeEditorView.autosaveEnabled"

    private let languages = [
        (key: "cpp", name: "C++"),
        (key: "python", name: "Python"),
        (key: "java", name: "Java"),
        (key: "plaintext", name: "Text")
    ]
    
    // 运行面板
    @State private var isRunPresented: Bool = false
    // 提交流：确认 -> 自动提交 -> 展示判题状态
    @State private var showSubmitConfirm: Bool = false
    @State private var isSubmitSheetPresented: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var submitErrorText: String = ""
    @State private var showSubmitError: Bool = false
    @StateObject private var statusVM = SubmissionStatusViewModel()
    @State private var isStatusPresented: Bool = false
    @State private var testCases: [TestCase] = [TestCase(input: "", expected: "", received: "")]
    @State private var isEditorReady: Bool = false
    @State private var cookieHandle: String? = nil
    @State private var lastSubmitAt: Date? = nil
    
    private var languageDisplayKey: String {
        switch language {
        case "plaintext": return "txt"
        default: return language
        }
    }

    var resolvedTheme: String { (colorScheme == .dark) ? "vs-dark" : "vs" }

    private var navigationTitleText: String {
        let base = currentFileURL?.lastPathComponent ?? "未命名"
        return isDirty ? "*\(base)" : base
    }

    private var hasCFLogin: Bool {
        let t = (cookieHandle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty
    }
    private var canSubmit: Bool {
        hasCFLogin && !shouldShowEmptyState
    }

    // 自动保存开关与防抖
    @State private var autosaveEnabled: Bool = false
    @State private var autosaveDebounceItem: DispatchWorkItem? = nil

    var body: some View {
        let base: AnyView = AnyView(
            makeEditorContent()
                .background(Color(uiColor: .systemBackground))
                .navigationTitle(navigationTitleText)
                .navigationBarTitleDisplayMode(.inline)
                // 主题自动根据系统切换（依赖 colorScheme，计算属性 resolvedTheme 会变更）
                .toolbar { navigationToolbar }
                // 键盘工具栏：全局收起键盘
                .toolbar { keyboardToolbar }
        )

        return base
            // 文件管理弹窗
            .sheet(isPresented: $isFilesPresented) { filesSheetContent() }
            // 另存为
            .sheet(isPresented: $isSaveAsPresented) { saveAsSheetContent() }
            .onAppear { onAppearSetup(); refreshCFHandle() }
            // 跨 Tab 通知：直接打开指定文件
            .onReceive(NotificationCenter.default.publisher(for: .openEditorFileRequested)) { note in
                if let url = note.object as? URL, FileManager.default.fileExists(atPath: url.path) {
                    openFile(at: url)
                }
            }
            .onChange(of: isFilesPresented) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: showFilesOnLaunchKey)
            }
            // 代码变化：更新脏标记并自动保存草稿
            .onChange(of: code) { _, _ in
                updateDirtyStateAndAutosave()
            }
            .onChange(of: language) { _, _ in
                writeAutosave()
            }
            .onChange(of: autosaveEnabled) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: autosaveEnabledKey)
                if newValue { scheduleAutosaveFile() } else { autosaveDebounceItem?.cancel() }
            }
            // 测试样例变化：按文件持久化
            .onChange(of: testCases) { _, _ in
                persistCurrentTestCases()
            }
            // Cookie 变化时刷新视图，以便 hasCFLogin 即时更新
            .onReceive(NotificationCenter.default.publisher(for: .NSHTTPCookieManagerCookiesChanged)) { _ in
                refreshCFHandle()
            }
            // 运行面板（上下滑动的抽屉）
            .sheet(isPresented: $isRunPresented) {
                RunSheetView(testCases: $testCases, language: language, code: $code)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            // 提交流：选择语言（从 CF 实时获取 programTypeId）+ 未登录遮罩
            .sheet(isPresented: $isSubmitSheetPresented) {
                if let p = parseProblemFromCurrentFile() {
                    SubmitSheetView(contestId: p.contestId, problemIndex: p.index, selectedLanguageKey: $language) { programTypeId, _ in
                        isSubmitSheetPresented = false
                        // 直接发起提交
                        performAutoSubmit(programTypeId: programTypeId)
                    }
                    .presentationDetents([.fraction(0.35), .medium, .large])
                    .presentationDragIndicator(.visible)
                } else {
                    VStack(spacing: 12) {
                        Text("无法识别题号，无法展示提交语言选项")
                        Button("关闭") { isSubmitSheetPresented = false }
                    }
                    .padding()
                }
            }
            // 提交成功后：显示原生判题状态面板
            .sheet(isPresented: $isStatusPresented) {
                if let p = parseProblemFromCurrentFile() {
                    SubmissionStatusView(
                        vm: statusVM,
                        problem: CFProblemIdentifier(contestId: p.contestId, index: p.index, name: nil),
                        handle: (cookieHandle ?? cfHandle)
                    ) { isStatusPresented = false }
                    .presentationDetents([.fraction(0.25), .fraction(0.5), .large])
                    .presentationDragIndicator(.visible)
                } else {
                    VStack(spacing: 12) {
                        Text("无法识别题号，无法展示判题状态")
                        Button("关闭") { isStatusPresented = false }
                    }
                    .padding()
                }
            }
            // 右上角动作面板（上下滑动的抽屉）
            .sheet(isPresented: $isActionsPresented) { actionsSheetContent() }
            // 顶部轻提示
            .overlay(alignment: .top) {
                if showToast {
                    Text(toastText)
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(.ultraThinMaterial)
                        )
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            // 提交确认弹窗
            .alert("确认提交到 Codeforces?", isPresented: $showSubmitConfirm) {
                Button("取消", role: .cancel) {}
                Button("提交") { performAutoSubmit() }
            } message: {
                Text("将根据当前文件名推断题号，直接发起提交，不打开网页提交页。")
            }
            // 提交失败提示
            .alert("提交失败", isPresented: $showSubmitError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(submitErrorText)
            }
    }

    // 顶部控制条已并入标题栏
}

// MARK: - 拆分的 Toolbar 与 Sheet 内容
extension CodeEditorView {
    private func refreshCFHandle() {
        Task {
            let h = await CFCookieBridge.shared.readCurrentCFHandleFromWK()
            await MainActor.run { self.cookieHandle = h }
        }
    }
    // 旧的 Web 提交弹窗逻辑已移除，改为原生自动提交 + 状态视图
    // 导航栏工具条
    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) {
            Button {
                isFilesPresented = true
            } label: {
                Image(systemName: "folder")
            }
            .accessibilityLabel("文件管理")

            Text("Lang：\(languageDisplayKey)")
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                #if canImport(UIKit)
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                #endif
                isSubmitSheetPresented = true
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.tint)
            }
            .disabled(shouldShowEmptyState || isSubmitting)
            .accessibilityLabel("提交")

            Button {
                #if canImport(UIKit)
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                #endif
                isRunPresented = true
            } label: {
                Image(systemName: "play.fill")
            }
            .disabled(shouldShowEmptyState)
            .accessibilityLabel("运行")

            Button {
                isActionsPresented = true
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .disabled(shouldShowEmptyState)
            .accessibilityLabel("更多操作")
        }
    }

    // 键盘工具条
    @ToolbarContentBuilder
    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button {
                #if canImport(UIKit)
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                #endif
            } label: {
                Label("完成", systemImage: "keyboard.chevron.compact.down")
            }
            .accessibilityLabel("收起键盘")
        }
    }

    // 文件浏览 Sheet 内容
    @ViewBuilder
    private func filesSheetContent() -> some View {
        FilesBrowserView(onSelect: { url in
            openFile(at: url)
        }, onDelete: { deletedURL in
            removePersistedTestCases(for: deletedURL)
            let remaining = sortedUserFiles()
            let remainingPaths = Set(remaining.map { $0.standardizedFileURL.path })
            let currentPath = currentFileURL?.standardizedFileURL.path

            let isCurrentMissing = (currentPath == nil) || !(remainingPaths.contains(currentPath!))

            if isCurrentMissing {
                if let next = remaining.first {
                    openFile(at: next)
                } else {
                    currentFileURL = nil
                    code = ""
                    UserDefaults.standard.removeObject(forKey: lastFilePathKey)
                    testCases = loadPersistedTestCases(for: nil)
                }
                isFilesPresented = false
            }
        })
    }

    // 另存为 Sheet 内容
    @ViewBuilder
    private func saveAsSheetContent() -> some View {
        SaveFileSheetView(initialFileName: saveAsFileName) { name in
            saveAsFile(named: name)
        }
    }

    // 设置面板 Sheet 内容
    @ViewBuilder
    private func actionsSheetContent() -> some View {
        SettingsSheetView(
            fontSize: $fontSize,
            minimap: $minimap,
            readOnly: $readOnly,
            autosaveEnabled: $autosaveEnabled,
            code: $code,
            onUndo: { undoRequestToken &+= 1 },
            onRedo: { redoRequestToken &+= 1 },
            canUndo: canUndo,
            canRedo: canRedo,
            onSave: { saveCurrentFile() },
            onSaveAs: {
                saveAsFileName = suggestedFileName()
                isSaveAsPresented = true
            }
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // onAppear 初始化
    private func onAppearSetup() {
        if let lastPath = UserDefaults.standard.string(forKey: lastFilePathKey) {
            let url = URL(fileURLWithPath: lastPath)
            if FileManager.default.fileExists(atPath: url.path) {
                openFile(at: url)
            }
        }
        let showFiles = UserDefaults.standard.bool(forKey: showFilesOnLaunchKey)
        isFilesPresented = showFiles
        migrateLegacyAutosaveIfNeeded()
        tryRestoreAutosaveIfNeeded()
        autosaveEnabled = UserDefaults.standard.bool(forKey: autosaveEnabledKey)
        if currentFileURL == nil {
            testCases = loadPersistedTestCases(for: nil)
        }
        _ = hasCFLogin
    }
}

// MARK: - 辅助：类型擦除以减轻编译器负担
private extension View {
    func asAnyView() -> AnyView { AnyView(self) }
}

// MARK: - 文件操作
extension CodeEditorView {
    @ViewBuilder
    private func makeEditorContent() -> some View {
        ZStack {
            if shouldShowEmptyState {
                VStack(spacing: 16) {
                    ContentUnavailableView("没有打开的文件", systemImage: "doc")
                    HStack(spacing: 12) {
                        Button {
                            saveAsFileName = suggestedFileName()
                            isSaveAsPresented = true
                        } label: { Label("新建文件", systemImage: "plus") }
                        Button {
                            isFilesPresented = true
                        } label: { Label("打开文件", systemImage: "folder") }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
            } else {
                ZStack {
                    MonacoEditorView(
                        text: $code,
                        language: language,
                        theme: resolvedTheme,
                        readOnly: readOnly,
                        fontSize: fontSize,
                        lineNumbers: "on",
                        minimap: minimap,
                        onContentChange: nil,
                        undoRequestToken: undoRequestToken,
                        redoRequestToken: redoRequestToken,
                        onUndoStateChange: { u, r in
                            canUndo = u
                            canRedo = r
                        },
                        onReady: {
                            isEditorReady = true
                        }
                    )
                    .ignoresSafeArea(.keyboard)

                    if !isEditorReady {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("正在加载编辑器…")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground))
                        )
                    }

                    if isSubmitting {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("正在提交…")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground))
                        )
                    }
                }
            }
        }
    }
    private func updateCFLoginState() {}
    private var shouldShowEmptyState: Bool {
        currentFileURL == nil && code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    private func applicationSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        var appFolder = base.appendingPathComponent("CfEditor", isDirectory: true)
        if !FileManager.default.fileExists(atPath: appFolder.path) {
            try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true, attributes: nil)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? appFolder.setResourceValues(values)
        }
        return appFolder
    }

    private func testCasesDirectory() -> URL {
        var dir = applicationSupportDirectory().appendingPathComponent("TestCases", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? dir.setResourceValues(values)
        }
        return dir
    }

    private func testCasesFileURL(for fileURL: URL?) -> URL {
        // 未命名/无文件的上下文使用固定键
        if fileURL == nil {
            return testCasesDirectory().appendingPathComponent("__unsaved__.json")
        }
        let path = fileURL!.standardizedFileURL.path
        let hashed = Insecure.MD5.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
        return testCasesDirectory().appendingPathComponent("\(hashed).json")
    }

    private func persistCurrentTestCases() {
        let url = testCasesFileURL(for: currentFileURL)
        do {
            let data = try JSONEncoder().encode(testCases)
            try data.write(to: url, options: .atomic)
        } catch {
            // 忽略持久化失败
        }
    }

    private func loadPersistedTestCases(for fileURL: URL?) -> [TestCase] {
        let url = testCasesFileURL(for: fileURL)
        guard let data = try? Data(contentsOf: url) else { return [TestCase(input: "", expected: "", received: "")] }
        if let arr = try? JSONDecoder().decode([TestCase].self, from: data) {
            // 确保至少有一个样例
            return arr.isEmpty ? [TestCase(input: "", expected: "", received: "")] : arr
        } else {
            return [TestCase(input: "", expected: "", received: "")]
        }
    }

    private func removePersistedTestCases(for fileURL: URL) {
        let url = testCasesFileURL(for: fileURL)
        try? FileManager.default.removeItem(at: url)
    }

    private func sortedUserFiles(excluding url: URL? = nil) -> [URL] {
        let dir = documentsDirectory()
        let contents = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let filtered = (contents ?? []).filter { candidate in
            guard let url = url else { return true }
            return candidate.standardizedFileURL != url.standardizedFileURL
        }
        return filtered.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return l > r
        }
    }

    private func openFile(at url: URL) {
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else { return }
        code = text
        currentFileURL = url
        language = languageKey(for: url.pathExtension)
        isFilesPresented = false
        UserDefaults.standard.set(url.path, forKey: lastFilePathKey)
        lastSavedCode = text
        isDirty = false
        clearAutosave()
        // 加载该文件对应的测试样例
        testCases = loadPersistedTestCases(for: url)
    }

    private func saveCurrentFile() {
        if let url = currentFileURL {
            save(to: url)
        } else {
            saveAsFileName = suggestedFileName()
            isSaveAsPresented = true
        }
    }

    private func saveAsFile(named name: String) {
        var fileName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if fileName.isEmpty { fileName = suggestedFileName() }
        if URL(fileURLWithPath: fileName).pathExtension.isEmpty {
            fileName += "." + defaultExtension(for: language)
        }
        let url = documentsDirectory().appendingPathComponent(fileName)
        // 新建后根据扩展名锁定语言展示
        language = languageKey(for: url.pathExtension)
        save(to: url)
        currentFileURL = url
        isSaveAsPresented = false
        // 将当前测试样例与新文件绑定并持久化
        persistCurrentTestCases()
    }

    private func save(to url: URL) {
        do {
            try code.data(using: .utf8)?.write(to: url)
            UserDefaults.standard.set(url.path, forKey: lastFilePathKey)
            lastSavedCode = code
            isDirty = false
            clearAutosave()
            if !autosaveEnabled {
                presentToast("已保存")
            }
        } catch {
            // 简化处理：忽略错误
        }
    }

    private func suggestedFileName() -> String {
        "untitled.txt"
    }

    private func defaultExtension(for language: String) -> String {
        switch language {
        case "cpp": return "cpp"
        case "python": return "py"
        case "java": return "java"
        case "plaintext": return "txt"
        default: return "txt"
        }
    }

    private func languageKey(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "c", "cc", "cpp", "cxx", "hpp", "h": return "cpp"
        case "py": return "python"
        case "java": return "java"
        case "js", "mjs", "cjs": return "plaintext"
        case "ts": return "plaintext"
        default: return "plaintext"
        }
    }

    private struct ParsedProblem {
        let contestId: Int
        let index: String
    }

    // 从当前文件名中解析 Codeforces 题号（形如 1234A.cpp / 1234_A.py / 1234A2.cpp）
    private func parseProblemFromCurrentFile() -> ParsedProblem? {
        guard let name = currentFileURL?.lastPathComponent else { return nil }
        let base = name.components(separatedBy: ".").dropLast().joined(separator: ".")
        // 正则：contestId=digits，后跟 index=[A-Za-z][0-9A-Za-z]* 可含下划线
        // 例：1873A、1873_A、1873A2
        let pattern = "^([0-9]{3,6})[_-]?([A-Za-z][0-9A-Za-z]*)$"
        if let r = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(location: 0, length: base.utf16.count)
            if let m = r.firstMatch(in: base, options: [], range: range), m.numberOfRanges >= 3 {
                if let g1 = Range(m.range(at: 1), in: base), let g2 = Range(m.range(at: 2), in: base) {
                    let cidStr = String(base[g1])
                    let idx = String(base[g2]).uppercased()
                    if let cid = Int(cidStr) { return ParsedProblem(contestId: cid, index: idx) }
                }
            }
        }
        return nil
    }

    private func buildSubmitURLForCurrentProblem() -> String {
        if let p = parseProblemFromCurrentFile() {
            return "https://codeforces.com/contest/\(p.contestId)/submit?submittedProblemIndex=\(p.index)"
        } else {
            return "https://codeforces.com/problemset/submit"
        }
    }

    // 构造提交页的路径（不含协议与主机），用于作为登录后的回跳参数
    private func buildSubmitPathForCurrentProblem() -> String {
        if let p = parseProblemFromCurrentFile() {
            return "/contest/\(p.contestId)/submit?submittedProblemIndex=\(p.index)"
        } else {
            return "/problemset/submit"
        }
    }

    // 构造登录页面地址，带上 back 参数使登录成功后自动跳到提交页
    private func buildEnterURL(backPath: String) -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "codeforces.com"
        components.path = "/enter"
        components.queryItems = [URLQueryItem(name: "back", value: backPath)]
        return components.url?.absoluteString ?? "https://codeforces.com/enter?back=%2F"
    }

    // MARK: - 自动提交（原生 HTTP）
    private func lastSubmissionKey(for contestId: Int, index: String) -> String {
        "lastSubmit.\(contestId).\(index)"
    }

    private func persistLastSubmission(contestId: Int, index: String, code: String) {
        let key = lastSubmissionKey(for: contestId, index: index)
        UserDefaults.standard.set(code, forKey: key)
    }

    private func loadLastSubmission(contestId: Int, index: String) -> String? {
        let key = lastSubmissionKey(for: contestId, index: index)
        return UserDefaults.standard.string(forKey: key)
    }

    private func maybeWarnDuplicateBeforeSubmit(contestId: Int, index: String) async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if let last = loadLastSubmission(contestId: contestId, index: index)?.trimmingCharacters(in: .whitespacesAndNewlines), !last.isEmpty, last == trimmed {
            await MainActor.run { presentToast("与上一份代码完全相同，可能会被 Codeforces 拒绝提交") }
        }
    }
    private func performAutoSubmit() {
        guard let p = parseProblemFromCurrentFile() else {
            presentToast("无法从文件名识别题号，如 1873A.cpp")
            return
        }
        if language == "plaintext" {
            presentToast("请选择正确的语言后再提交")
            return
        }
        // 轻量本地节流：两次提交间隔至少 1.2s，减少被 CF 判定频率过高
        if let last = lastSubmitAt, Date().timeIntervalSince(last) < 1.2 {
            presentToast("提交过于频繁，请稍后再试")
            return
        }
        lastSubmitAt = Date()
        isSubmitting = true
        Task {
            defer { Task { @MainActor in isSubmitting = false } }
            do {
                // 预判重复代码：若最近一次 AC/最新一次提交与当前代码完全一致，给出友好提示
                // 注意：此处仅本地快速判断，不替代服务器端的最终校验
                await maybeWarnDuplicateBeforeSubmit(contestId: p.contestId, index: p.index)
                try await CFSubmitClient.submit(contestId: p.contestId, index: p.index, sourceCode: code, languageKey: language)
                await MainActor.run {
                    presentToast("已提交，正在查询…")
                    isStatusPresented = true
                    persistLastSubmission(contestId: p.contestId, index: p.index, code: code)
                }
                // 无论状态面板是否已打开，都主动刷新并跟踪“最近一次提交”
                let usedHandle = (cookieHandle ?? cfHandle).trimmingCharacters(in: .whitespacesAndNewlines)
                if !usedHandle.isEmpty {
                    let pid = CFProblemIdentifier(contestId: p.contestId, index: p.index, name: nil)
                    Task {
                        await statusVM.loadAll(for: pid, handle: usedHandle)
                        statusVM.startTrackingLatest(for: pid, handle: usedHandle)
                    }
                }
            } catch {
                await MainActor.run {
                    submitErrorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    showSubmitError = true
                }
            }
        }
    }

    // 使用精准的 programTypeId 直接提交（由 SubmitSheetView 从 CF 实时读取）
    private func performAutoSubmit(programTypeId: String) {
        guard let p = parseProblemFromCurrentFile() else {
            presentToast("无法从文件名识别题号，如 1873A.cpp")
            return
        }
        // 轻量本地节流
        if let last = lastSubmitAt, Date().timeIntervalSince(last) < 1.2 {
            presentToast("提交过于频繁，请稍后再试")
            return
        }
        lastSubmitAt = Date()
        isSubmitting = true
        Task {
            defer { Task { @MainActor in isSubmitting = false } }
            do {
                await maybeWarnDuplicateBeforeSubmit(contestId: p.contestId, index: p.index)
                try await CFSubmitClient.submit(contestId: p.contestId, index: p.index, sourceCode: code, programTypeId: programTypeId)
                await MainActor.run {
                    presentToast("已提交，正在查询…")
                    isStatusPresented = true
                    persistLastSubmission(contestId: p.contestId, index: p.index, code: code)
                }
                // 无论状态面板是否已打开，都主动刷新并跟踪“最近一次提交”
                let usedHandle = (cookieHandle ?? cfHandle).trimmingCharacters(in: .whitespacesAndNewlines)
                if !usedHandle.isEmpty {
                    let pid = CFProblemIdentifier(contestId: p.contestId, index: p.index, name: nil)
                    Task {
                        await statusVM.loadAll(for: pid, handle: usedHandle)
                        statusVM.startTrackingLatest(for: pid, handle: usedHandle)
                    }
                }
            } catch {
                await MainActor.run {
                    submitErrorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    showSubmitError = true
                }
            }
        }
    }
}

#if DEBUG
struct CodeEditorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { CodeEditorView() }
    }
}
#endif

// MARK: - 轻提示 & 草稿持久化
extension CodeEditorView {
    private func presentToast(_ text: String) {
        toastText = text
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut) { showToast = false }
        }
    }

    private struct AutoSavePayload: Codable {
        var path: String?
        var code: String
        var language: String
    }

    private func autosaveURL() -> URL {
        applicationSupportDirectory().appendingPathComponent(autosaveFileName)
    }

    private func writeAutosave() {
        let payload = AutoSavePayload(path: currentFileURL?.standardizedFileURL.path,
                                      code: code,
                                      language: language)
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: autosaveURL(), options: .atomic)
        } catch { /* 忽略草稿写入错误 */ }
    }

    private func clearAutosave() {
        try? FileManager.default.removeItem(at: autosaveURL())
    }

    private func tryRestoreAutosaveIfNeeded() {
        let url = autosaveURL()
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(AutoSavePayload.self, from: data) else { return }

        // 若当前没有打开文件且编辑区为空，则恢复草稿
        if currentFileURL == nil && code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            code = payload.code
            language = payload.language
            lastSavedCode = ""
            isDirty = !payload.code.isEmpty
            return
        }

        // 若当前打开文件与草稿指向同一路径，且草稿与磁盘不一致，则恢复草稿
        if let cur = currentFileURL?.standardizedFileURL.path,
           let savedPath = payload.path,
           cur == savedPath,
           payload.code != lastSavedCode {
            code = payload.code
            isDirty = true
        }
    }

    private func updateDirtyStateAndAutosave() {
        isDirty = (code != lastSavedCode)
        writeAutosave()
        scheduleAutosaveFile()
    }

    private func scheduleAutosaveFile() {
        guard autosaveEnabled else { return }
        autosaveDebounceItem?.cancel()
        let item = DispatchWorkItem { [code, currentFileURL] in
            // 仅当已有目标文件时执行自动保存，未命名文件不触发磁盘写入
            guard let url = currentFileURL else { return }
            do {
                try code.data(using: .utf8)?.write(to: url)
                lastSavedCode = code
                isDirty = false
                clearAutosave()
            } catch { /* 忽略自动保存失败 */ }
        }
        autosaveDebounceItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: item)
    }

    private func migrateLegacyAutosaveIfNeeded() {
        let legacyURL = documentsDirectory().appendingPathComponent(autosaveFileName)
        let newURL = autosaveURL()
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return }
        // 若新位置已有文件则优先保留新文件，删除旧文件
        if FileManager.default.fileExists(atPath: newURL.path) {
            try? FileManager.default.removeItem(at: legacyURL)
            return
        }
        do {
            try FileManager.default.moveItem(at: legacyURL, to: newURL)
        } catch {
            // 如果移动失败，尝试复制后删除旧文件
            _ = try? FileManager.default.copyItem(at: legacyURL, to: newURL)
            try? FileManager.default.removeItem(at: legacyURL)
        }
    }
}


