//
//  ProblemStatementView.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import SwiftUI
import WebKit
import CryptoKit

// MARK: - Problem Statement View (移动端友好)

struct ProblemStatementView: View {
    let problem: ProblemStatement
    let sourceProblem: CFProblem?  // 源题目信息（包含 rating 和 tags）
    
    @State private var fontSize: CGFloat = 16
    @State private var copiedInputSample: Int? = nil
    @State private var copiedOutputSample: Int? = nil
    @State private var showRawHTML = false
    @State private var showGenerateSuccess = false
    @State private var generatedFileURL: URL? = nil
    @StateObject private var favoritesManager = FavoritesManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    // 计算属性：当前题目是否已收藏
    private var isFavorited: Bool {
        favoritesManager.isFavorite(id: problem.id)
    }
    
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
            
            // 限制信息和生成按钮
            HStack(spacing: 16) {
                LimitBadge(icon: "clock", text: problem.timeLimit, color: .blue)
                LimitBadge(icon: "memorychip", text: problem.memoryLimit, color: .green)
                
                Spacer()
                
                // 右侧按钮组（竖直排列）
                VStack(spacing: 8) {
                    // 收藏按钮（五角星）
                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorited ? "star.fill" : "star")
                            .font(.system(size: 22))
                            .foregroundColor(isFavorited ? .yellow : .gray)
                    }
                    
                    // 一键生成 C++ 文件按钮
                    Button(action: generateCppFile) {
                        Image(systemName: showGenerateSuccess ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.green)
                    }
                }
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
    
    private func toggleFavorite() {
        let favorite = FavoriteProblem(
            contestId: problem.contestId,
            problemIndex: problem.problemIndex,
            name: problem.name,
            rating: sourceProblem?.rating,  // 从源题目获取 rating
            tags: sourceProblem?.tags ?? []  // 从源题目获取 tags
        )
        
        withAnimation {
            if isFavorited {
                favoritesManager.removeFavorite(id: problem.id)
            } else {
                favoritesManager.addFavorite(favorite)
            }
        }
        
        #if DEBUG
        print("⭐️ 题目 \(problem.contestId)\(problem.problemIndex) 收藏状态: \(isFavorited ? "已收藏" : "未收藏"), rating: \(sourceProblem?.rating?.description ?? "nil"), tags: \(sourceProblem?.tags?.count ?? 0)")
        #endif
    }
    
    // MARK: - Generate C++ File
    
    private func generateCppFile() {
        // 生成文件名：contestId + problemIndex.cpp，例如 1010D.cpp
        let fileName = "\(problem.contestId)\(problem.problemIndex).cpp"
        
        // 获取文档目录
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        // C++ 模板代码
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
        
        // 如果文件不存在，创建文件
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? template.data(using: .utf8)?.write(to: fileURL)
        }
        
        // 准备测试用例数据
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
        
        // 保存测试用例到编辑器的持久化位置
        saveTestCases(testCases, for: fileURL)
        
        // 显示成功状态
        showGenerateSuccess = true
        generatedFileURL = fileURL
        
        // 2秒后重置状态
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

