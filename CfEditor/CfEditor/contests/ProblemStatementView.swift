//
//  ProblemStatementView.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import SwiftUI
import WebKit

// MARK: - Problem Statement View (移动端友好)

struct ProblemStatementView: View {
    let problem: ProblemStatement
    @State private var fontSize: CGFloat = 16
    @State private var copiedInputSample: Int? = nil
    @State private var copiedOutputSample: Int? = nil
    @State private var showRawHTML = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            if showRawHTML {
                // 🔍 调试模式：直接显示原始 HTML
                VStack(alignment: .leading, spacing: 10) {
                    Text("⚠️ 原始 HTML 调试模式")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding()
                    
                    Text(problem.rawHTML ?? "无原始 HTML 数据")
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                }
            } else {
            VStack(alignment: .leading, spacing: 20) {
                // Header - 标题和限制
                headerSection
                
                Divider()
                
                // 题面描述
                if !problem.statement.isEmpty {
                    sectionView(title: "题面描述", icon: "doc.text", content: problem.statement)
                }
                
                // 输入格式
                if !problem.inputSpecification.isEmpty {
                    sectionView(title: "输入格式", icon: "arrow.down.doc", content: problem.inputSpecification)
                }
                
                // 输出格式
                if !problem.outputSpecification.isEmpty {
                    sectionView(title: "输出格式", icon: "arrow.up.doc", content: problem.outputSpecification)
                }
                
                // 样例
                if !problem.samples.isEmpty {
                    samplesSection
                }
                
                // 注释
                if let note = problem.note {
                    sectionView(title: "注释", icon: "lightbulb", content: note)
                }
            }
            .padding()
            .padding(.bottom, 60) // 为底部 TabBar 留出空间
            }
        }
        .navigationTitle(problem.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                fontSizeMenu
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            Text(problem.name)
                .font(.system(size: fontSize + 8, weight: .bold))
                .foregroundColor(.primary)
            
            // 限制信息
            HStack(spacing: 16) {
                LimitBadge(icon: "clock", text: problem.timeLimit, color: .blue)
                LimitBadge(icon: "memorychip", text: problem.memoryLimit, color: .green)
            }
            
            // IO 文件
            HStack(spacing: 16) {
                IOBadge(icon: "arrow.down.circle", label: "输入", text: problem.inputFile)
                IOBadge(icon: "arrow.up.circle", label: "输出", text: problem.outputFile)
            }
        }
    }
    
    // MARK: - Section View
    
    private func sectionView(title: String, icon: String, content: [ContentElement]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            Label(title, systemImage: icon)
                .font(.system(size: fontSize + 4, weight: .semibold))
                .foregroundColor(.accentColor)
            
            // 内容
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
                    .font(.system(size: fontSize))
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
                                .font(.system(size: fontSize))
                            Text(item)
                                .font(.system(size: fontSize))
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
            // 段落：使用单个WebView渲染混合内容（文本+行内公式）
            return AnyView(
                MixedContentView(elements: elements, fontSize: fontSize)
            )
        }
    }
    
    // MARK: - Samples Section
    
    private var samplesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("样例", systemImage: "doc.on.doc")
                .font(.system(size: fontSize + 4, weight: .semibold))
                .foregroundColor(.accentColor)
            
            ForEach(Array(problem.samples.enumerated()), id: \.element.id) { index, sample in
                SampleCard(
                    sampleNumber: index + 1,
                    input: sample.input,
                    output: sample.output,
                    inputLineGroups: sample.inputLineGroups,
                    outputLineGroups: sample.outputLineGroups,
                    fontSize: fontSize,
                    isInputCopied: copiedInputSample == index,
                    isOutputCopied: copiedOutputSample == index,
                    onCopyInput: {
                        copyToClipboard(sample.input)
                        copiedInputSample = index
                        
                        // 2秒后重置
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            if copiedInputSample == index {
                                copiedInputSample = nil
                            }
                        }
                    },
                    onCopyOutput: {
                        copyToClipboard(sample.output)
                        copiedOutputSample = index
                        
                        // 2秒后重置
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            if copiedOutputSample == index {
                                copiedOutputSample = nil
                            }
                        }
                    }
                )
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Font Size Menu
    
    private var fontSizeMenu: some View {
        Menu {
            Button {
                fontSize = 14
            } label: {
                Label("小", systemImage: fontSize == 14 ? "checkmark" : "")
            }
            
            Button {
                fontSize = 16
            } label: {
                Label("中", systemImage: fontSize == 16 ? "checkmark" : "")
            }
            
            Button {
                fontSize = 18
            } label: {
                Label("大", systemImage: fontSize == 18 ? "checkmark" : "")
            }
            
            Button {
                fontSize = 20
            } label: {
                Label("特大", systemImage: fontSize == 20 ? "checkmark" : "")
            }
        } label: {
            Image(systemName: "textformat.size")
        }
    }
    
    // MARK: - Helper Methods
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
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
    let isInputCopied: Bool
    let isOutputCopied: Bool
    let onCopyInput: () -> Void
    let onCopyOutput: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    // 根据样例编号决定是否使用条纹背景（奇数样例有条纹，偶数样例无条纹）
    private var useStripes: Bool {
        sampleNumber % 2 == 1
    }
    
    // 将文本分割成行，并关联分组信息
    private func parseLines(_ text: String, groups: [Int]?) -> [(line: String, groupIndex: Int)] {
        var lines = text.components(separatedBy: "\n")
        // 移除末尾的空行
        while lines.last?.isEmpty == true {
            lines.removeLast()
        }
        
        var result: [(String, Int)] = []
        
        // 如果有分组信息（从 Codeforces HTML 提取），直接使用
        if let groups = groups, groups.count == lines.count {
            for (line, group) in zip(lines, groups) {
                result.append((line, group))
            }
            #if DEBUG
            print("🔍 使用 Codeforces 原生分组信息: \(Set(groups).sorted())")
            #endif
        } else {
            // 回退方案：按空行分隔
            var currentGroup = 0
            for line in lines {
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    currentGroup += 1
                } else {
                    result.append((line, currentGroup))
                }
            }
            #if DEBUG
            print("⚠️ 使用空行分隔回退方案")
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
        let result = parseLines(output, groups: outputLineGroups)
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
                    .font(.system(size: fontSize, weight: .semibold))
                
                Spacer()
            }
            .padding(12)
            .background(Color.accentColor.opacity(0.1))
            
            Divider()
            
            // Input
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("输入")
                        .font(.system(size: fontSize - 2, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: onCopyInput) {
                        HStack(spacing: 4) {
                            Image(systemName: isInputCopied ? "checkmark" : "doc.on.doc")
                            Text(isInputCopied ? "已复制" : "复制")
                        }
                        .font(.system(size: fontSize - 4))
                        .foregroundColor(isInputCopied ? .green : .accentColor)
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: true) {
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background((useStripes && item.groupIndex % 2 == 1) ? Color.gray.opacity(0.08) : Color.clear)
                        }
                    }
                    .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Output
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("输出")
                        .font(.system(size: fontSize - 2, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: onCopyOutput) {
                        HStack(spacing: 4) {
                            Image(systemName: isOutputCopied ? "checkmark" : "doc.on.doc")
                            Text(isOutputCopied ? "已复制" : "复制")
                        }
                        .font(.system(size: fontSize - 4))
                        .foregroundColor(isOutputCopied ? .green : .accentColor)
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: true) {
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background((useStripes && item.groupIndex % 2 == 1) ? Color.gray.opacity(0.08) : Color.clear)
                        }
                    }
                    .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(colorScheme == .dark ? Color(.systemGray6) : Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
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
        ProblemStatementView(problem: ProblemStatement(
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
        ))
    }
}

