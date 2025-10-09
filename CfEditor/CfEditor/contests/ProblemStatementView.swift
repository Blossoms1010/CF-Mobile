//
//  ProblemStatementView.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import SwiftUI
import WebKit
import CryptoKit

// MARK: - Problem Statement View (Mobile-Friendly)

struct ProblemStatementView: View {
    let problem: ProblemStatement
    let sourceProblem: CFProblem?  // Source problem info (includes rating and tags)
    
    @State private var fontSize: CGFloat = 16
    @State private var fontDesign: Font.Design = .serif  // Default to serif for better readability
    @State private var selectedFontName: String = "Serif"  // Default font name
    @State private var showFontSheet = false
    @State private var copiedInputSample: Int? = nil
    @State private var copiedOutputSample: Int? = nil
    @State private var showRawHTML = false
    @State private var showGenerateSuccess = false
    @State private var generatedFileURL: URL? = nil
    @State private var selectedLanguage: String = "English" // Default English
    @StateObject private var favoritesManager = FavoritesManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    // Translation states
    @State private var currentTranslation: ProblemTranslation? = nil
    @State private var isTranslating = false
    @State private var translationError: String? = nil
    @StateObject private var translationCache = TranslationCache.shared
    @AppStorage("aiTransModels") private var modelsData: Data = Data()
    
    // Computed property: whether current problem is favorited
    private var isFavorited: Bool {
        favoritesManager.isFavorite(id: problem.id)
    }
    
    // Get display title (translated or original)
    private var displayTitle: String {
        if selectedLanguage == "Chinese", let translation = currentTranslation {
            return translation.translatedName
        }
        return problem.name
    }
    
    // Get display statement (translated or original)
    private var displayStatement: [ContentElement] {
        if selectedLanguage == "Chinese", let translation = currentTranslation {
            return translation.translatedStatement
        }
        return problem.statement
    }
    
    // Get display input spec (translated or original)
    private var displayInputSpec: [ContentElement] {
        if selectedLanguage == "Chinese", let translation = currentTranslation {
            return translation.translatedInputSpec
        }
        return problem.inputSpecification
    }
    
    // Get display output spec (translated or original)
    private var displayOutputSpec: [ContentElement] {
        if selectedLanguage == "Chinese", let translation = currentTranslation {
            return translation.translatedOutputSpec
        }
        return problem.outputSpecification
    }
    
    // Get display note (translated or original)
    private var displayNote: [ContentElement]? {
        if selectedLanguage == "Chinese", let translation = currentTranslation {
            return translation.translatedNote
        }
        return problem.note
    }
    
    // Helper function to create font based on selected font name
    private func makeFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontOptions: [String: (design: Font.Design, fontName: String?)] = [
            "System": (.default, nil),
            "Serif": (.serif, nil),
            "Monospaced": (.monospaced, nil),
            "Rounded": (.rounded, nil),
            "PingFang": (.default, "PingFang SC"),
            "Heiti": (.default, "Heiti SC"),
            "Kaiti": (.serif, "Kaiti SC"),
            "Songti": (.serif, "Songti SC"),
            "Georgia": (.serif, "Georgia"),
            "Palatino": (.serif, "Palatino"),
            "Courier": (.monospaced, "Courier"),
            "Menlo": (.monospaced, "Menlo")
        ]
        
        if let option = fontOptions[selectedFontName], let fontName = option.fontName {
            return .custom(fontName, size: size)
        } else if let option = fontOptions[selectedFontName] {
            return .system(size: size, weight: weight, design: option.design)
        }
        return .system(size: size, weight: weight, design: fontDesign)
    }
    
    var body: some View {
        ScrollView {
            if showRawHTML {
                // 🔍 Debug mode: display raw HTML
                VStack(alignment: .leading, spacing: 10) {
                    Text("⚠️ Raw HTML Debug Mode")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding()
                    
                    Text(problem.rawHTML ?? "No raw HTML data")
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                }
            } else {
            VStack(alignment: .leading, spacing: 20) {
                // Translation error banner
                if let error = translationError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("关闭") {
                            translationError = nil
                        }
                        .font(.caption)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Header - title and limits
                headerSection
                
                Divider()
                
                // Problem description
                if !displayStatement.isEmpty {
                    sectionView(title: "Description", icon: "doc.text", content: displayStatement)
                }
                
                // Input format
                if !displayInputSpec.isEmpty {
                    sectionView(title: "Input", icon: "arrow.down.doc", content: displayInputSpec)
                }
                
                // Output format
                if !displayOutputSpec.isEmpty {
                    sectionView(title: "Output", icon: "arrow.up.doc", content: displayOutputSpec)
                }
                
                // Samples
                if !problem.samples.isEmpty {
                    samplesSection
                }
                
                // Note
                if let note = displayNote {
                    sectionView(title: "Note", icon: "lightbulb", content: note)
                }
            }
            .padding()
            .padding(.bottom, 60) // Leave space for bottom TabBar
            }
        }
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                fontSizeMenu
            }
        }
        .overlay(alignment: .bottom) {
            if isTranslating {
                HStack {
                    ProgressView()
                    Text("翻译中...")
                        .font(.subheadline)
                }
                .padding()
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(12)
                .padding(.bottom, 80)
            }
        }
        .onAppear {
            loadCachedTranslation()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(displayTitle)
                .font(makeFont(size: fontSize + 8, weight: .bold))
                .foregroundColor(.primary)
            
            // Limits and buttons
            HStack(spacing: 16) {
                LimitBadge(icon: "clock", text: formatTimeLimit(problem.timeLimit), color: .blue)
                LimitBadge(icon: "memorychip", text: formatMemoryLimit(problem.memoryLimit), color: .green)
                
                Spacer()
                
                // Right button group (horizontal)
                HStack(spacing: 12) {
                    // Favorite button (star)
                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorited ? "star.fill" : "star")
                            .font(.system(size: 20))
                            .foregroundColor(isFavorited ? .yellow : .gray)
                    }
                    
                    // One-click generate C++ file button
                    Button(action: generateCppFile) {
                        Image(systemName: showGenerateSuccess ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                    }
                    
                    // Language selection button
                    Menu {
                        Button {
                            selectedLanguage = "English"
                        } label: {
                            HStack {
                                Text("English")
                                if selectedLanguage == "English" {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        Button {
                            switchToLanguage("Chinese")
                        } label: {
                            HStack {
                                Text("Chinese")
                                if selectedLanguage == "Chinese" {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .disabled(isTranslating || !hasAIModels())
                        
                        // 翻译管理选项（仅在有缓存或正在翻译时显示）
                        if currentTranslation != nil || isTranslating {
                            Divider()
                            
                            Button {
                                translateProblem()
                            } label: {
                                Label("重新翻译", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .disabled(isTranslating || !hasAIModels())
                            
                            Button(role: .destructive) {
                                Task {
                                    await translationCache.deleteTranslation(problemId: problem.id, language: "Chinese")
                                    currentTranslation = nil
                                    selectedLanguage = "English"
                                }
                            } label: {
                                Label("清除缓存", systemImage: "trash")
                            }
                            .disabled(isTranslating)
                        }
                    } label: {
                        Image(systemName: isTranslating ? "arrow.triangle.2.circlepath" : "globe")
                            .font(.system(size: 20))
                            .foregroundStyle(
                                LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .rotationEffect(.degrees(isTranslating ? 360 : 0))
                            .animation(isTranslating ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isTranslating)
                    }
                }
            }
            
            // IO files
            HStack(spacing: 16) {
                IOBadge(icon: "arrow.down.circle", label: "Input", text: problem.inputFile)
                IOBadge(icon: "arrow.up.circle", label: "Output", text: problem.outputFile)
            }
        }
    }
    
    // MARK: - Section View
    
    private func sectionView(title: String, icon: String, content: [ContentElement]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Label(title, systemImage: icon)
                .font(makeFont(size: fontSize + 4, weight: .semibold))
                .foregroundColor(.accentColor)
            
            // Content
            VStack(alignment: .leading, spacing: 10) {
                ForEach(content) { element in
                    contentElementView(element)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Content Element View
    
    private func contentElementView(_ element: ContentElement) -> AnyView {
        switch element {
        case .text(let content):
            return AnyView(
                Text(content)
                    .font(makeFont(size: fontSize))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            )
            
        case .inlineLatex(let formula):
            return AnyView(
                InlineLatexView(formula: formula, fontSize: fontSize)
            )
            
        case .blockLatex(let formula):
            return AnyView(
                BlockLatexView(formula: formula, fontSize: fontSize)
            )
            
        case .image(let urlString):
            if let url = URL(string: urlString) {
                return AnyView(
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(8)
                        case .failure:
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                        @unknown default:
                            EmptyView()
                        }
                    }
                )
            } else {
                return AnyView(EmptyView())
            }
            
        case .list(let items):
            return AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(makeFont(size: fontSize))
                            Text(item)
                                .font(makeFont(size: fontSize))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.leading, 8)
            )
            
        case .code(let code):
            return AnyView(
                Text(code)
                    .font(.system(size: fontSize - 2, design: .monospaced))
                    .padding(12)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .textSelection(.enabled)
            )
            
        case .paragraph(let elements):
            // Paragraph: render mixed content (text + inline formulas) with a single WebView
            return AnyView(
                MixedContentView(elements: elements, fontSize: fontSize)
            )
        }
    }
    
    // MARK: - Samples Section
    
    private var samplesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Samples", systemImage: "doc.on.doc")
                .font(makeFont(size: fontSize + 4, weight: .semibold))
                .foregroundColor(.accentColor)
            
            ForEach(Array(problem.samples.enumerated()), id: \.element.id) { index, sample in
                SampleCard(
                    sampleNumber: index + 1,
                    input: sample.input,
                    output: sample.output,
                    inputLineGroups: sample.inputLineGroups,
                    outputLineGroups: sample.outputLineGroups,
                    fontSize: fontSize,
                    fontDesign: fontDesign,
                    selectedFontName: selectedFontName,
                    isInputCopied: copiedInputSample == index,
                    isOutputCopied: copiedOutputSample == index,
                    onCopyInput: {
                        copyToClipboard(sample.input)
                        copiedInputSample = index
                        
                        // Reset after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            if copiedInputSample == index {
                                copiedInputSample = nil
                            }
                        }
                    },
                    onCopyOutput: {
                        copyToClipboard(sample.output)
                        copiedOutputSample = index
                        
                        // Reset after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            if copiedOutputSample == index {
                                copiedOutputSample = nil
                            }
                        }
                    },
                    isInteractive: problem.isInteractive
                )
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Font Size Menu
    
    private var fontSizeMenu: some View {
        Button {
            showFontSheet = true
        } label: {
            Image(systemName: "textformat.size")
        }
        .sheet(isPresented: $showFontSheet) {
            FontSettingsSheet(fontSize: $fontSize, fontDesign: $fontDesign, selectedFontName: $selectedFontName)
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTimeLimit(_ timeLimit: String) -> String {
        // Convert "1 second" -> "1s", "2 seconds" -> "2s"
        let components = timeLimit.components(separatedBy: " ")
        if let value = components.first {
            return "\(value)s"
        }
        return timeLimit
    }
    
    private func formatMemoryLimit(_ memoryLimit: String) -> String {
        // Convert "256 megabytes" -> "256 MB", "512 megabytes" -> "512 MB"
        let components = memoryLimit.components(separatedBy: " ")
        if let value = components.first {
            return "\(value) MB"
        }
        return memoryLimit
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
    
    private func toggleFavorite() {
        let favorite = FavoriteProblem(
            contestId: problem.contestId,
            problemIndex: problem.problemIndex,
            name: problem.name,
            rating: sourceProblem?.rating,  // Get rating from source problem
            tags: sourceProblem?.tags ?? []  // Get tags from source problem
        )
        
        withAnimation {
            if isFavorited {
                favoritesManager.removeFavorite(id: problem.id)
            } else {
                favoritesManager.addFavorite(favorite)
            }
        }
        
        #if DEBUG
        print("⭐️ Problem \(problem.contestId)\(problem.problemIndex) favorite status: \(isFavorited ? "favorited" : "not favorited"), rating: \(sourceProblem?.rating?.description ?? "nil"), tags: \(sourceProblem?.tags?.count ?? 0)")
        #endif
    }
    
    // MARK: - Generate C++ File
    
    private func generateCppFile() {
        // Generate filename: contestId + problemIndex.cpp, e.g. 1010D.cpp
        let fileName = "\(problem.contestId)\(problem.problemIndex).cpp"
        
        // Get documents directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        // C++ template code
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
        
        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? template.data(using: .utf8)?.write(to: fileURL)
        }
        
        // Prepare test case data
        let testCases = problem.samples.map { sample in
            [
                "input": sample.input,
                "expected": sample.output,
                "received": "",
                "lastRunMs": NSNull(),
                "timedOut": false,
                "verdict": "none"
            ] as [String: Any]
        }
        
        // Save test cases to editor's persistent location
        saveTestCases(testCases, for: fileURL)
        
        // Show success status
        showGenerateSuccess = true
        generatedFileURL = fileURL
        
        // Reset status after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showGenerateSuccess = false
        }
    }
    
    private func saveTestCases(_ testCases: [[String: Any]], for fileURL: URL) {
        // 使用与编辑器相同的哈希算法
        let path = fileURL.standardizedFileURL.path
        let hashed = Insecure.MD5.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
        
        // 获取应用支持目录
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        var appFolder = support.appendingPathComponent("CfEditor", isDirectory: true)
        
        // 创建 CfEditor 文件夹
        if !FileManager.default.fileExists(atPath: appFolder.path) {
            try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? appFolder.setResourceValues(values)
        }
        
        // 创建 TestCases 子文件夹
        var tcDir = appFolder.appendingPathComponent("TestCases", isDirectory: true)
        if !FileManager.default.fileExists(atPath: tcDir.path) {
            try? FileManager.default.createDirectory(at: tcDir, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? tcDir.setResourceValues(values)
        }
        
        // 保存测试用例 JSON
        let tcFile = tcDir.appendingPathComponent("\(hashed).json")
        if let data = try? JSONSerialization.data(withJSONObject: testCases) {
            try? data.write(to: tcFile, options: .atomic)
        }
    }
    
    // MARK: - Translation
    
    private func hasAIModels() -> Bool {
        guard let models = try? JSONDecoder().decode([AITranslationModel].self, from: modelsData) else {
            return false
        }
        return !models.isEmpty
    }
    
    private func translateProblem() {
        guard let models = try? JSONDecoder().decode([AITranslationModel].self, from: modelsData),
              let firstModel = models.first else {
            translationError = "请先在设置中配置 AI 翻译模型"
            return
        }
        
        isTranslating = true
        translationError = nil
        
        Task {
            do {
                // Extract text from content elements
                func extractTexts(from elements: [ContentElement]) -> [String] {
                    var texts: [String] = []
                    for element in elements {
                        switch element {
                        case .text(let content):
                            texts.append(content)
                        case .paragraph(let subElements):
                            for subElement in subElements {
                                if case .text(let content) = subElement {
                                    texts.append(content)
                                }
                            }
                        case .list(let items):
                            texts.append(contentsOf: items)
                        default:
                            break
                        }
                    }
                    return texts
                }
                
                // Collect all texts to translate
                var textsToTranslate: [String] = []
                textsToTranslate.append(problem.name)
                textsToTranslate.append(contentsOf: extractTexts(from: problem.statement))
                textsToTranslate.append(contentsOf: extractTexts(from: problem.inputSpecification))
                textsToTranslate.append(contentsOf: extractTexts(from: problem.outputSpecification))
                if let note = problem.note {
                    textsToTranslate.append(contentsOf: extractTexts(from: note))
                }
                
                // Translate all texts
                let translatedTexts = try await AITranslator.translateENtoZH(
                    textsToTranslate,
                    model: firstModel.model,
                    proxyAPI: firstModel.apiEndpoint,
                    apiKey: firstModel.apiKey
                )
                
                // Reconstruct content elements with translated text
                var textIndex = 0
                
                func replaceTexts(in elements: [ContentElement]) -> [ContentElement] {
                    var result: [ContentElement] = []
                    for element in elements {
                        switch element {
                        case .text:
                            if textIndex < translatedTexts.count {
                                result.append(.text(translatedTexts[textIndex]))
                                textIndex += 1
                            } else {
                                result.append(element)
                            }
                        case .paragraph(let subElements):
                            var translatedSub: [ContentElement] = []
                            for subElement in subElements {
                                if case .text = subElement {
                                    if textIndex < translatedTexts.count {
                                        translatedSub.append(.text(translatedTexts[textIndex]))
                                        textIndex += 1
                                    } else {
                                        translatedSub.append(subElement)
                                    }
                                } else {
                                    translatedSub.append(subElement)
                                }
                            }
                            result.append(.paragraph(translatedSub))
                        case .list:
                            var translatedItems: [String] = []
                            if let listElement = element as? ContentElement,
                               case .list(let items) = listElement {
                                for _ in items {
                                    if textIndex < translatedTexts.count {
                                        translatedItems.append(translatedTexts[textIndex])
                                        textIndex += 1
                                    }
                                }
                                result.append(.list(translatedItems))
                            }
                        default:
                            result.append(element)
                        }
                    }
                    return result
                }
                
                let translatedName = textIndex < translatedTexts.count ? translatedTexts[textIndex] : problem.name
                textIndex += 1
                
                let translatedStatement = replaceTexts(in: problem.statement)
                let translatedInput = replaceTexts(in: problem.inputSpecification)
                let translatedOutput = replaceTexts(in: problem.outputSpecification)
                let translatedNote = problem.note != nil ? replaceTexts(in: problem.note!) : nil
                
                // Create translation object
                let translation = ProblemTranslation(
                    problemId: problem.id,
                    targetLanguage: "Chinese",
                    translatedName: translatedName,
                    translatedStatement: translatedStatement,
                    translatedInputSpec: translatedInput,
                    translatedOutputSpec: translatedOutput,
                    translatedNote: translatedNote,
                    translatedAt: Date(),
                    modelUsed: firstModel.model
                )
                
                // Save to cache
                await translationCache.saveTranslation(translation)
                
                await MainActor.run {
                    currentTranslation = translation
                    selectedLanguage = "Chinese"
                    isTranslating = false
                }
            } catch {
                await MainActor.run {
                    translationError = "翻译失败: \(error.localizedDescription)"
                    isTranslating = false
                }
            }
        }
    }
    
    // MARK: - Load Cached Translation
    
    private func switchToLanguage(_ language: String) {
        // 如果切换到英文，直接切换
        if language == "English" {
            selectedLanguage = "English"
            return
        }
        
        // 如果切换到中文，检查是否有缓存
        if language == "Chinese" {
            // 尝试从缓存加载
            if let translation = translationCache.getTranslation(problemId: problem.id, language: "Chinese") {
                // 有缓存，直接使用
                currentTranslation = translation
                selectedLanguage = "Chinese"
            } else {
                // 没有缓存，自动开始翻译
                translateProblem()
            }
        }
    }
    
    private func loadCachedTranslation() {
        // Try to load Chinese translation from cache
        if let translation = translationCache.getTranslation(problemId: problem.id, language: "Chinese") {
            currentTranslation = translation
        }
    }
}

// MARK: - Limit Badge

struct LimitBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 14))
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }
}

// MARK: - IO Badge

struct IOBadge: View {
    let icon: String
    let label: String
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.secondary)
            
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Sample Card

struct SampleCard: View {
    let sampleNumber: Int
    let input: String
    let output: String
    let inputLineGroups: [Int]?  // Codeforces 原生分组信息
    let outputLineGroups: [Int]?
    let fontSize: CGFloat
    let fontDesign: Font.Design
    let selectedFontName: String
    let isInputCopied: Bool
    let isOutputCopied: Bool
    let onCopyInput: () -> Void
    let onCopyOutput: () -> Void
    let isInteractive: Bool  // 是否为交互题
    
    @Environment(\.colorScheme) var colorScheme
    
    // Helper function to create font
    private func makeFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontOptions: [String: (design: Font.Design, fontName: String?)] = [
            "System": (.default, nil),
            "Serif": (.serif, nil),
            "Monospaced": (.monospaced, nil),
            "Rounded": (.rounded, nil),
            "PingFang": (.default, "PingFang SC"),
            "Heiti": (.default, "Heiti SC"),
            "Kaiti": (.serif, "Kaiti SC"),
            "Songti": (.serif, "Songti SC"),
            "Georgia": (.serif, "Georgia"),
            "Palatino": (.serif, "Palatino"),
            "Courier": (.monospaced, "Courier"),
            "Menlo": (.monospaced, "Menlo")
        ]
        
        if let option = fontOptions[selectedFontName], let fontName = option.fontName {
            return .custom(fontName, size: size)
        } else if let option = fontOptions[selectedFontName] {
            return .system(size: size, weight: weight, design: option.design)
        }
        return .system(size: size, weight: weight, design: fontDesign)
    }
    
    // 🎯 点击高亮功能：记录当前选中的组索引（输入输出联动）
    @State private var selectedGroup: Int? = nil
    
    // 根据样例编号决定是否使用条纹背景（奇数样例有条纹，偶数样例无条纹）
    private var useStripes: Bool {
        sampleNumber % 2 == 1
    }
    
    // 将文本分割成行，并关联分组信息
    private func parseLines(_ text: String, groups: [Int]?, isOutput: Bool = false) -> [(line: String, groupIndex: Int)] {
        var lines = text.components(separatedBy: "\n")
        // 移除末尾的空行
        while lines.last?.isEmpty == true {
            lines.removeLast()
        }
        
        var result: [(String, Int)] = []
        
        // 🎯 交互题特殊处理：所有行都归为同一组（组号0），不进行分组和高亮
        if isInteractive {
            for line in lines {
                if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    result.append((line, 0))
                }
            }
            #if DEBUG
            print("🎮 交互题：所有行归为组0，不高亮")
            #endif
            return result
        }
        
        // 如果有分组信息（从 Codeforces HTML 提取），直接使用
        if let groups = groups, groups.count == lines.count {
            for (line, group) in zip(lines, groups) {
                result.append((line, group))
            }
            #if DEBUG
            print("🔍 使用 Codeforces 原生分组信息: \(Set(groups).sorted())")
            #endif
        } else {
            // 回退方案1：按空行分隔
            var hasEmptyLines = false
            var currentGroup = 0
            for line in lines {
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    currentGroup += 1
                    hasEmptyLines = true
                } else {
                    result.append((line, currentGroup))
                }
            }
            
            // 回退方案2：如果没有空行，尝试检测多测试用例格式
            if !hasEmptyLines && result.count > 0 {
                // 检测输入的第一行是否是测试用例数量
                let inputLines = input.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if let firstLine = inputLines.first, 
                   let testCount = Int(firstLine.trimmingCharacters(in: .whitespaces)), 
                   testCount > 1 && testCount <= 100 {
                    
                    if isOutput {
                        // === 输出侧：尝试智能分组 ===
                        // 检测是否每个测试用例以 YES/NO 开头
                        let yesNoIndices = result.enumerated().filter { (index, item) in
                            let trimmed = item.0.trimmingCharacters(in: .whitespaces).uppercased()
                            return trimmed == "YES" || trimmed == "NO"
                        }.map { $0.offset }
                        
                        if yesNoIndices.count == testCount {
                            // 找到了匹配的 YES/NO 模式，按此分组
                            result = []
                            for (groupIdx, startIdx) in yesNoIndices.enumerated() {
                                let endIdx = groupIdx + 1 < yesNoIndices.count ? yesNoIndices[groupIdx + 1] : lines.count
                                for lineIdx in startIdx..<endIdx {
                                    if lineIdx < lines.count && !lines[lineIdx].trimmingCharacters(in: .whitespaces).isEmpty {
                                        result.append((lines[lineIdx], groupIdx))
                                    }
                                }
                            }
                            #if DEBUG
                            print("✅ 输出使用智能分组（YES/NO模式）：检测到 \(testCount) 个测试用例")
                            #endif
                            return result
                        }
                    } else {
                        // === 输入侧：第一行单独分组 ===
                        // 第一行（测试用例数）使用特殊组号 -1，与输出不对应
                        result = []
                        result.append((lines[0], -1))  // 测试用例数单独一组
                        
                        // 后续行按顺序分组（从第1组开始）
                        for i in 1..<lines.count {
                            if !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                                result.append((lines[i], 0))  // 暂时都归为组0
                            }
                        }
                        
                        #if DEBUG
                        print("✅ 输入侧检测到多测格式：第一行(\(firstLine))单独分组为 -1")
                        #endif
                        return result
                    }
                }
            }
            
            #if DEBUG
            if hasEmptyLines {
                print("⚠️ 使用空行分隔回退方案")
            } else {
                print("⚠️ 无分组信息且无空行，所有行归为一组")
            }
            #endif
        }
        
        return result
    }
    
    // 将文本分割成行，过滤掉末尾的空行
    private var inputLines: [(line: String, groupIndex: Int)] {
        let result = parseLines(input, groups: inputLineGroups)
        #if DEBUG
        print("🔍 SampleCard \(sampleNumber) - Input:")
        print("   原始字符串长度: \(input.count)")
        print("   换行符数量: \(input.filter { $0 == "\n" }.count)")
        print("   分割后行数: \(result.count)")
        print("   组数: \(Set(result.map { $0.groupIndex }).count)")
        print("   前3行: \(result.prefix(3).map { "[\($0.groupIndex)] \($0.line)" })")
        #endif
        return result
    }
    
    private var outputLines: [(line: String, groupIndex: Int)] {
        let result = parseLines(output, groups: outputLineGroups, isOutput: true)
        #if DEBUG
        print("🔍 SampleCard \(sampleNumber) - Output:")
        print("   原始字符串长度: \(output.count)")
        print("   换行符数量: \(output.filter { $0 == "\n" }.count)")
        print("   分割后行数: \(result.count)")
        print("   组数: \(Set(result.map { $0.groupIndex }).count)")
        #endif
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("样例 \(sampleNumber)")
                    .font(makeFont(size: fontSize, weight: .semibold))
                
                Spacer()
            }
            .padding(12)
            .background(Color.accentColor.opacity(0.1))
            
            Divider()
            
            // Input
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("输入")
                        .font(makeFont(size: fontSize - 2, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: onCopyInput) {
                        HStack(spacing: 4) {
                            Image(systemName: isInputCopied ? "checkmark" : "doc.on.doc")
                            Text(isInputCopied ? "已复制" : "复制")
                        }
                        .font(makeFont(size: fontSize - 4))
                        .foregroundColor(isInputCopied ? .green : .accentColor)
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: true) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(inputLines.enumerated()), id: \.offset) { index, item in
                                HStack(spacing: 0) {
                                    Text(item.line.isEmpty ? " " : item.line)
                                        .font(.system(size: fontSize - 1, design: .monospaced))
                                        .fixedSize(horizontal: true, vertical: true)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .frame(minWidth: UIScreen.main.bounds.width - 48, alignment: .leading)
                                .background(backgroundColorForLine(groupIndex: item.groupIndex, selectedGroup: selectedGroup, isInput: true))
                                .contentShape(Rectangle())  // 让整行都可点击
                                .onTapGesture {
                                    // 🎯 特殊处理：groupIndex == -1 的行（多测第一行 t）点击时不响应
                                    if item.groupIndex == -1 {
                                        return
                                    }
                                    
                                    // 🎯 点击切换高亮：输入输出联动
                                    if selectedGroup == item.groupIndex {
                                        selectedGroup = nil
                                    } else {
                                        selectedGroup = item.groupIndex
                                    }
                                }
                            }
                        }
                        .textSelection(.enabled)
                    }
                    .frame(maxHeight: 300)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Output
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("输出")
                        .font(makeFont(size: fontSize - 2, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: onCopyOutput) {
                        HStack(spacing: 4) {
                            Image(systemName: isOutputCopied ? "checkmark" : "doc.on.doc")
                            Text(isOutputCopied ? "已复制" : "复制")
                        }
                        .font(makeFont(size: fontSize - 4))
                        .foregroundColor(isOutputCopied ? .green : .accentColor)
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: true) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(outputLines.enumerated()), id: \.offset) { index, item in
                                HStack(spacing: 0) {
                                    Text(item.line.isEmpty ? " " : item.line)
                                        .font(.system(size: fontSize - 1, design: .monospaced))
                                        .fixedSize(horizontal: true, vertical: true)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .frame(minWidth: UIScreen.main.bounds.width - 48, alignment: .leading)
                                .background(backgroundColorForLine(groupIndex: item.groupIndex, selectedGroup: selectedGroup, isInput: false))
                                .contentShape(Rectangle())  // 让整行都可点击
                                .onTapGesture {
                                    // 🎯 特殊处理：groupIndex == -1 的行（多测第一行 t）点击时不响应
                                    if item.groupIndex == -1 {
                                        return
                                    }
                                    
                                    // 🎯 点击切换高亮：输入输出联动
                                    if selectedGroup == item.groupIndex {
                                        selectedGroup = nil
                                    } else {
                                        selectedGroup = item.groupIndex
                                    }
                                }
                            }
                        }
                        .textSelection(.enabled)
                    }
                    .frame(maxHeight: 300)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(colorScheme == .dark ? Color(.systemGray6) : Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Helper: 计算行背景色（高亮 > 条纹 > 透明）
    
    /// 计算每一行的背景色
    /// - Parameters:
    ///   - groupIndex: 该行所属的组索引（-1 表示多测题目的第一行 t，不参与高亮）
    ///   - selectedGroup: 当前选中的组索引（nil 表示未选中）
    ///   - isInput: 是否是输入区域（用于区分输入/输出的选中状态）
    /// - Returns: 背景颜色
    private func backgroundColorForLine(groupIndex: Int, selectedGroup: Int?, isInput: Bool) -> Color {
        // 🎯 特殊处理：groupIndex == -1 表示多测题目的第一行（测试用例数量 t），不参与高亮
        if groupIndex == -1 {
            return Color.clear
        }
        
        // 🎯 优先级1：如果该组被选中，显示淡淡的黄色高亮
        if let selected = selectedGroup, selected == groupIndex {
            // CF 官网风格的黄色高亮（更淡的黄色，深色模式下稍微调暗）
            return colorScheme == .dark 
                ? Color.yellow.opacity(0.15)   // 深色模式：淡黄色
                : Color.yellow.opacity(0.20)   // 浅色模式：淡黄色
        }
        
        // 🎯 优先级2：如果启用条纹背景且是偶数组，显示灰色条纹（第0组=灰，第1组=白，第2组=灰...）
        if useStripes && groupIndex % 2 == 0 {
            return Color.gray.opacity(0.08)
        }
        
        // 🎯 优先级3：默认透明
        return Color.clear
    }
}

// MARK: - Mixed Content View

/// 混合内容视图：在一个WebView中渲染文本和行内公式
struct MixedContentView: View {
    let elements: [ContentElement]
    let fontSize: CGFloat
    @State private var htmlHeight: CGFloat = 50
    
    var body: some View {
        MixedContentWebView(elements: elements, fontSize: fontSize, height: $htmlHeight)
            .frame(height: htmlHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Latex Views

/// 行内公式视图（不换行，跟随文本流）
struct InlineLatexView: View {
    let formula: String
    let fontSize: CGFloat
    @State private var htmlHeight: CGFloat = 30
    
    var body: some View {
        LatexWebView(formula: formula, fontSize: fontSize, isInline: true, height: $htmlHeight)
            .frame(height: htmlHeight)
            // 行内公式不占满整行
    }
}

/// 块级公式视图（独立一行，居中显示）
struct BlockLatexView: View {
    let formula: String
    let fontSize: CGFloat
    @State private var htmlHeight: CGFloat = 100
    
    var body: some View {
        LatexWebView(formula: formula, fontSize: fontSize, isInline: false, height: $htmlHeight)
            .frame(height: htmlHeight)
            .frame(maxWidth: .infinity)
    }
}

struct MixedContentWebView: UIViewRepresentable {
    let elements: [ContentElement]
    let fontSize: CGFloat
    @Binding var height: CGFloat
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "heightHandler")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = generateHTML(elements: elements, fontSize: fontSize)
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func generateHTML(elements: [ContentElement], fontSize: CGFloat) -> String {
        let isDark = UITraitCollection.current.userInterfaceStyle == .dark
        let textColor = isDark ? "#FFFFFF" : "#000000"
        
        // 构建混合内容
        var content = ""
        for (index, element) in elements.enumerated() {
            // 在公式前添加空格（如果前面是文本）
            if case .inlineLatex = element, index > 0 {
                if case .text = elements[index - 1] {
                    content += " "
                }
            }
            
            switch element {
            case .text(let text):
                content += text
            case .inlineLatex(let formula):
                content += "\\(\(formula)\\)"
            default:
                break
            }
            
            // 在公式后添加空格（如果后面是文本）
            if case .inlineLatex = element, index < elements.count - 1 {
                if case .text = elements[index + 1] {
                    content += " "
                }
            }
        }
        
        #if DEBUG
        print("📝 MixedContentWebView HTML content: \(content.prefix(200))")
        #endif
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
            <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
            <style>
                body {
                    margin: 0;
                    padding: 4px;
                    font-size: \(fontSize)px;
                    color: \(textColor);
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.6;
                }
            </style>
        </head>
        <body>
            <div>\(content)</div>
            <script>
                MathJax.typesetPromise().then(() => {
                    const height = document.body.scrollHeight;
                    window.webkit.messageHandlers.heightHandler.postMessage(height);
                });
            </script>
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MixedContentWebView
        
        init(_ parent: MixedContentWebView) {
            self.parent = parent
            super.init()
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 获取内容高度
            webView.evaluateJavaScript("document.body.scrollHeight") { result, error in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self.parent.height = height + 16
                    }
                }
            }
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightHandler", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    self.parent.height = height + 16
                }
            }
        }
    }
}

struct LatexWebView: UIViewRepresentable {
    let formula: String
    let fontSize: CGFloat
    let isInline: Bool
    @Binding var height: CGFloat
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "heightHandler")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = generateHTML(formula: formula, fontSize: fontSize, isInline: isInline)
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func generateHTML(formula: String, fontSize: CGFloat, isInline: Bool) -> String {
        let isDark = UITraitCollection.current.userInterfaceStyle == .dark
        let textColor = isDark ? "#FFFFFF" : "#000000"
        
        // 行内公式使用 \(...\)，块级公式使用 \[...\]
        let mathDelimiter = isInline ? "\\(\(formula)\\)" : "\\[\(formula)\\]"
        let displayStyle = isInline ? "display: inline;" : "display: block; text-align: center;"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
            <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
            <style>
                body {
                    margin: 0;
                    padding: 4px;
                    font-size: \(fontSize)px;
                    color: \(textColor);
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                }
                .formula {
                    \(displayStyle)
                    max-width: 100%;
                    overflow-x: auto;
                }
            </style>
        </head>
        <body>
            <div class="formula">\(mathDelimiter)</div>
            <script>
                MathJax.typesetPromise().then(() => {
                    const height = document.body.scrollHeight;
                    window.webkit.messageHandlers.heightHandler.postMessage(height);
                });
            </script>
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: LatexWebView
        
        init(_ parent: LatexWebView) {
            self.parent = parent
            super.init()
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 获取内容高度
            webView.evaluateJavaScript("document.body.scrollHeight") { result, error in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self.parent.height = height + 16
                    }
                }
            }
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightHandler", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    self.parent.height = height + 16
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProblemStatementView(
            problem: ProblemStatement(
                contestId: 2042,
                problemIndex: "A",
                name: "Greedy Monocarp",
                timeLimit: "1 second",
                memoryLimit: "256 megabytes",
                inputFile: "standard input",
                outputFile: "standard output",
                statement: [
                    .text("Monocarp has n items. The i-th item has a value of a_i."),
                    .text("Monocarp wants to divide all items into two groups such that:"),
                    .list(["Each item belongs to exactly one group", "The sum of values in both groups is the same"]),
                    .blockLatex("\\sum_{i=1}^{n} a_i = 2k")
                ],
                inputSpecification: [
                    .text("The first line contains a single integer t (1 ≤ t ≤ 10^4) — the number of test cases."),
                    .text("The first line of each test case contains an integer n (1 ≤ n ≤ 100).")
                ],
                outputSpecification: [
                    .text("For each test case, output YES if it's possible, NO otherwise.")
                ],
                samples: [
                    TestSample(id: 1, input: "3\n3\n1 2 3", output: "6"),
                    TestSample(id: 2, input: "5\n5 4 3 2 1", output: "15")
                ],
                note: [
                    .text("In the first test case, the answer is 6."),
                    .text("In the second test case, the answer is 15.")
                ],
                sourceURL: "https://codeforces.com/contest/2042/problem/A"
            ),
            sourceProblem: nil
        )
    }
}

// MARK: - Font Settings Sheet

struct FontSettingsSheet: View {
    @Binding var fontSize: CGFloat
    @Binding var fontDesign: Font.Design
    @Binding var selectedFontName: String
    @Environment(\.dismiss) private var dismiss
    
    // Helper function to create font
    private func makeFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontOptions: [String: (design: Font.Design, fontName: String?)] = [
            "System": (.default, nil),
            "Serif": (.serif, nil),
            "Monospaced": (.monospaced, nil),
            "Rounded": (.rounded, nil),
            "PingFang": (.default, "PingFang SC"),
            "Heiti": (.default, "Heiti SC"),
            "Kaiti": (.serif, "Kaiti SC"),
            "Songti": (.serif, "Songti SC"),
            "Georgia": (.serif, "Georgia"),
            "Palatino": (.serif, "Palatino"),
            "Courier": (.monospaced, "Courier"),
            "Menlo": (.monospaced, "Menlo")
        ]
        
        if let option = fontOptions[selectedFontName], let fontName = option.fontName {
            return .custom(fontName, size: size)
        } else if let option = fontOptions[selectedFontName] {
            return .system(size: size, weight: weight, design: option.design)
        }
        return .system(size: size, weight: weight, design: fontDesign)
    }
    
    struct FontOption: Identifiable {
        let id = UUID()
        let name: String
        let displayName: String
        let design: Font.Design
        let icon: String
        let color: Color
        let description: String
        let fontName: String?
        
        init(name: String, displayName: String, design: Font.Design, icon: String, color: Color, description: String, fontName: String? = nil) {
            self.name = name
            self.displayName = displayName
            self.design = design
            self.icon = icon
            self.color = color
            self.description = description
            self.fontName = fontName
        }
    }
    
    let fontOptions: [FontOption] = [
        // 系统字体
        FontOption(name: "System", displayName: "系统默认", design: .default, icon: "character", color: .blue, description: "Apple 系统标准字体"),
        FontOption(name: "Serif", displayName: "衬线体", design: .serif, icon: "character.book.closed", color: .brown, description: "优雅的阅读字体"),
        FontOption(name: "Monospaced", displayName: "等宽字体", design: .monospaced, icon: "chevron.left.forwardslash.chevron.right", color: .green, description: "适合代码显示"),
        FontOption(name: "Rounded", displayName: "圆角字体", design: .rounded, icon: "circle.circle", color: .purple, description: "友好圆润风格"),
        
        // 中文字体
        FontOption(name: "PingFang", displayName: "苹方", design: .default, icon: "character.zh", color: .cyan, description: "现代简洁的中文字体", fontName: "PingFang SC"),
        FontOption(name: "Heiti", displayName: "黑体", design: .default, icon: "character.textbox.zh", color: .indigo, description: "经典中文黑体", fontName: "Heiti SC"),
        FontOption(name: "Kaiti", displayName: "楷体", design: .serif, icon: "character.book.closed.fill.zh", color: .orange, description: "优雅的手写风格", fontName: "Kaiti SC"),
        FontOption(name: "Songti", displayName: "宋体", design: .serif, icon: "text.book.closed", color: .pink, description: "传统中文宋体", fontName: "Songti SC"),
        
        // 英文字体
        FontOption(name: "Georgia", displayName: "Georgia", design: .serif, icon: "text.book.closed.fill", color: .red, description: "优雅的英文衬线体", fontName: "Georgia"),
        FontOption(name: "Palatino", displayName: "Palatino", design: .serif, icon: "textformat", color: .teal, description: "经典书籍字体", fontName: "Palatino"),
        FontOption(name: "Courier", displayName: "Courier", design: .monospaced, icon: "terminal", color: .mint, description: "经典等宽字体", fontName: "Courier"),
        FontOption(name: "Menlo", displayName: "Menlo", design: .monospaced, icon: "curlybraces", color: .gray, description: "程序员最爱", fontName: "Menlo")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 预览区域
                    previewSection
                    
                    // 字体大小调节
                    fontSizeSection
                    
                    // 字体选择
                    fontSelectionSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("字体设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("完成")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(spacing: 16) {
            Text("预览")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                // 中文预览
                VStack(alignment: .leading, spacing: 8) {
                    Text("中文预览")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("算法竞赛是一种智力活动")
                        .font(makeFont(size: fontSize))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider()
                
                // 英文预览
                VStack(alignment: .leading, spacing: 8) {
                    Text("English Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("The quick brown fox jumps over the lazy dog")
                        .font(makeFont(size: fontSize))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider()
                
                // 数字和代码预览
                VStack(alignment: .leading, spacing: 8) {
                    Text("Numbers & Code")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("int main() { return 0; } // 1234567890")
                        .font(makeFont(size: fontSize))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
            )
        }
    }
    
    // MARK: - Font Size Section
    
    private var fontSizeSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("字体大小")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(fontSize))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                    )
            }
            
            // 滑块
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Image(systemName: "textformat.size.smaller")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $fontSize, in: 10...32, step: 1)
                        .accentColor(.accentColor)
                    
                    Image(systemName: "textformat.size.larger")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                
                // 快速选择按钮
                HStack(spacing: 10) {
                    ForEach([12, 14, 16, 18, 20, 24], id: \.self) { size in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                fontSize = CGFloat(size)
                            }
                        } label: {
                            Text("\(size)")
                                .font(.system(size: 13, weight: fontSize == CGFloat(size) ? .bold : .regular))
                                .foregroundColor(fontSize == CGFloat(size) ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(fontSize == CGFloat(size) ? Color.accentColor : Color(.systemGray5))
                                )
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
            )
        }
    }
    
    // MARK: - Font Selection Section
    
    private var fontSelectionSection: some View {
        VStack(spacing: 16) {
            Text("字体样式")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                ForEach(fontOptions) { option in
                    FontOptionCard(
                        option: option,
                        isSelected: selectedFontName == option.name,
                        fontSize: fontSize,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                fontDesign = option.design
                                selectedFontName = option.name
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Font Option Card

struct FontOptionCard: View {
    let option: FontSettingsSheet.FontOption
    let isSelected: Bool
    let fontSize: CGFloat
    let action: () -> Void
    
    // Helper function to create the actual font for preview
    private var previewFont: Font {
        if let fontName = option.fontName {
            return .custom(fontName, size: 14)
        } else {
            return .system(size: 14, design: option.design)
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 图标
                ZStack {
                    Circle()
                        .fill(option.color.opacity(isSelected ? 0.2 : 0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: option.icon)
                        .font(.system(size: 22))
                        .foregroundColor(option.color)
                }
                
                // 字体信息
                VStack(alignment: .leading, spacing: 6) {
                    Text(option.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(option.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    // 示例文本 - 使用实际字体
                    Text("示例 Sample Aa 123")
                        .font(previewFont)
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(.top, 2)
                }
                
                Spacer()
                
                // 选中标记
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(option.color)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isSelected ? option.color.opacity(0.5) : Color.clear,
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: isSelected ? option.color.opacity(0.2) : Color.black.opacity(0.03),
                        radius: isSelected ? 8 : 4,
                        y: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

