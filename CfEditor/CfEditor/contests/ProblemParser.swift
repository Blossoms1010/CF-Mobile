//
//  ProblemParser.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import Foundation

// MARK: - Problem Parser

/// 解析 Codeforces 题目 HTML 的工具类
class ProblemParser {
    
    // MARK: - Public Methods
    
    /// 从 URL 下载并解析题目
    static func fetchAndParse(contestId: Int, problemIndex: String) async throws -> ProblemStatement {
        let urlString = "https://codeforces.com/contest/\(contestId)/problem/\(problemIndex)"
        
        guard let url = URL(string: urlString) else {
            throw ParserError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ParserError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ParserError.networkError
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw ParserError.encodingError
        }
        
        // 检查是否被 Cloudflare 拦截
        // 注意：正常的 Codeforces 页面也可能包含 "challenge-platform"，
        // 所以我们需要更精确的检测：检查是否有真正的验证页面特征
        let isCloudflareBlocked = (
            html.contains("Checking your browser") ||
            html.contains("Just a moment") ||
            html.contains("Enable JavaScript and cookies to continue") ||
            (html.contains("cf-browser-verification") && html.contains("ray ID"))
        )
        
        if isCloudflareBlocked {
            throw ParserError.cloudflareBlocked
        }
        
        let result = try parse(html: html, contestId: contestId, problemIndex: problemIndex, sourceURL: urlString)
        
        return result
    }
    
    /// 解析 HTML 字符串
    static func parse(html: String, contestId: Int, problemIndex: String, sourceURL: String) throws -> ProblemStatement {
        
        // 🔍 调试：保存原始 HTML 到文件
        #if DEBUG
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let debugPath = documentsPath.appendingPathComponent("debug_problem_\(contestId)_\(problemIndex).html")
            try? html.write(to: debugPath, atomically: true, encoding: .utf8)
            print("🔍 Debug: Saved raw HTML to \(debugPath.path)")
            
            // 打印输入规范部分的原始 HTML（前 500 字符）
            if let range = html.range(of: #"<div class="input-specification">"#) {
                let startIndex = range.lowerBound
                let endIndex = html.index(startIndex, offsetBy: min(1000, html.distance(from: startIndex, to: html.endIndex)))
                let snippet = String(html[startIndex..<endIndex])
                print("🔍 Input specification HTML snippet:\n\(snippet)")
            }
        }
        #endif
        
        // ===== 第一步：标准化 LaTeX 标记 =====
        var cleanedHTML = html
        
        // 将 $$$$$$ (六个美元符号，块状公式) 替换为标准的 $$
        // 注意：必须先处理较长的模式，避免被较短的模式替换
        cleanedHTML = cleanedHTML.replacingOccurrences(of: "$$$$$$", with: "$$")
        
        // 将 $$$ (三个美元符号，行内公式) 替换为标准的 $
        cleanedHTML = cleanedHTML.replacingOccurrences(of: "$$$", with: "$")
        
        // 提取题目名称
        let name = extractTitle(from: cleanedHTML)
        
        // 提取时间和内存限制
        let timeLimit = extractTimeLimit(from: cleanedHTML)
        let memoryLimit = extractMemoryLimit(from: cleanedHTML)
        
        // 提取输入输出文件
        let (inputFile, outputFile) = extractIOFiles(from: cleanedHTML)
        
        // 提取题面内容
        let statement = extractStatement(from: cleanedHTML)
        
        // 提取输入输出格式
        let inputSpec = extractInputSpecification(from: cleanedHTML)
        let outputSpec = extractOutputSpecification(from: cleanedHTML)
        
        // 提取样例
        let samples = extractSamples(from: cleanedHTML)
        
        // 提取注释
        let note = extractNote(from: cleanedHTML)
        
        return ProblemStatement(
            contestId: contestId,
            problemIndex: problemIndex,
            name: name,
            timeLimit: timeLimit,
            memoryLimit: memoryLimit,
            inputFile: inputFile,
            outputFile: outputFile,
            statement: statement,
            inputSpecification: inputSpec,
            outputSpecification: outputSpec,
            samples: samples,
            note: note,
            sourceURL: sourceURL,
            rawHTML: html  // 🔍 传递原始 HTML 用于调试
        )
    }
    
    // MARK: - Private Helper Methods
    
    private static func extractTitle(from html: String) -> String {
        if let range = html.range(of: #"<div class="title">([^<]+)</div>"#, options: .regularExpression) {
            let match = String(html[range])
            return match.replacingOccurrences(of: #"<div class="title">"#, with: "")
                .replacingOccurrences(of: "</div>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "Untitled Problem"
    }
    
    private static func extractTimeLimit(from html: String) -> String {
        if let range = html.range(of: #"<div class="time-limit">.*?(\d+\.?\d*)\s*(second|seconds|ms)"#, options: .regularExpression) {
            let match = String(html[range])
            if let numberRange = match.range(of: #"\d+\.?\d*\s*(second|seconds|ms)"#, options: .regularExpression) {
                return String(match[numberRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return "1 second"
    }
    
    private static func extractMemoryLimit(from html: String) -> String {
        if let range = html.range(of: #"<div class="memory-limit">.*?(\d+)\s*megabytes"#, options: .regularExpression) {
            let match = String(html[range])
            if let numberRange = match.range(of: #"\d+\s*megabytes"#, options: .regularExpression) {
                return String(match[numberRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return "256 megabytes"
    }
    
    private static func extractIOFiles(from html: String) -> (String, String) {
        var inputFile = "standard input"
        var outputFile = "standard output"
        
        if let range = html.range(of: #"<div class="input-file">.*?<div class="property-title">.*?</div>(.*?)</div>"#, options: .regularExpression) {
            let match = String(html[range])
            inputFile = cleanHTML(match).trimmingCharacters(in: .whitespacesAndNewlines)
            if inputFile.isEmpty { inputFile = "standard input" }
        }
        
        if let range = html.range(of: #"<div class="output-file">.*?<div class="property-title">.*?</div>(.*?)</div>"#, options: .regularExpression) {
            let match = String(html[range])
            outputFile = cleanHTML(match).trimmingCharacters(in: .whitespacesAndNewlines)
            if outputFile.isEmpty { outputFile = "standard output" }
        }
        
        return (inputFile, outputFile)
    }
    
    private static func extractStatement(from html: String) -> [ContentElement] {
        #if DEBUG
        print("\n[ProblemParser] ========== extractStatement 开始 ==========")
        #endif
        
        // 查找题面描述的开始和结束位置
        guard let startRange = html.range(of: #"<div class="header">[\s\S]*?</div>"#, options: .regularExpression) else {
            return [.text("Unable to extract problem statement")]
        }
        
        // 从 header 之后开始，寻找下一个 <div> 开始标签
        // 这个 <div> 是包含整个 statement 内容的容器
        let afterHeader = startRange.upperBound
        let remainingHTML = String(html[afterHeader...])
        
        // 找到 header 后的第一个 <div> 开始位置
        guard let divStartRange = remainingHTML.range(of: #"<div>"#, options: []) else {
            return [.text("Unable to extract problem statement")]
        }
        
        // statement 内容从这个 <div> 的内部开始
        let contentStart = html.index(afterHeader, offsetBy: remainingHTML.distance(from: remainingHTML.startIndex, to: divStartRange.upperBound))
        
        // 找到 input-specification 的位置作为结束点
        guard let endRange = html.range(of: #"<div class="input-specification">"#, options: .regularExpression) else {
            return [.text("Unable to extract problem statement")]
        }
        
        // 需要回退到 input-specification 之前的 </div>
        let beforeInputSpec = String(html[..<endRange.lowerBound])
        guard let lastDivEndRange = beforeInputSpec.range(of: #"</div>"#, options: [.backwards]) else {
            return [.text("Unable to extract problem statement")]
        }
        
        let endIndex = lastDivEndRange.lowerBound
        
        guard contentStart < endIndex else {
            return [.text("Unable to extract problem statement")]
        }
        
        let content = String(html[contentStart..<endIndex])
        
        #if DEBUG
        print("[ProblemParser] Statement content 长度: \(content.count) 字符")
        if content.contains("<img") {
            print("[ProblemParser] ✅ Statement 包含 <img 标签")
            // 提取并打印所有图片 URL
            let imgPattern = #"<img[^>]+src="([^"]+)"#
            if let regex = try? NSRegularExpression(pattern: imgPattern, options: []) {
                let nsContent = content as NSString
                let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))
                for match in matches {
                    if match.numberOfRanges > 1 {
                        let urlRange = match.range(at: 1)
                        let url = nsContent.substring(with: urlRange)
                        print("[ProblemParser]   图片 URL: \(url)")
                    }
                }
            }
        } else {
            print("[ProblemParser] ❌ Statement 不包含 <img 标签")
        }
        #endif
        
        return parseContent(content)
    }
    
    private static func extractInputSpecification(from html: String) -> [ContentElement] {
        // 查找输入格式的开始和结束位置
        guard let startRange = html.range(of: #"<div class="input-specification">[\s\S]*?<div class="section-title">Input[\s\S]*?</div>"#, options: .regularExpression),
              let endRange = html.range(of: #"<div class="output-specification">"#, options: .regularExpression) else {
            return []
        }
        
        // 提取标题之后到 output-specification 之前的内容
        let startIndex = startRange.upperBound
        let endIndex = endRange.lowerBound
        
        guard startIndex < endIndex else {
            return []
        }
        
        let content = String(html[startIndex..<endIndex])
        return parseContent(content)
    }
    
    private static func extractOutputSpecification(from html: String) -> [ContentElement] {
        // 查找输出格式的开始和结束位置
        guard let startRange = html.range(of: #"<div class="output-specification">[\s\S]*?<div class="section-title">Output[\s\S]*?</div>"#, options: .regularExpression) else {
            return []
        }
        
        // 查找下一个主要部分（可能是 sample-tests 或 note）
        let startIndex = startRange.upperBound
        let remainingHTML = String(html[startIndex...])
        
        // 尝试找到下一个主要 div
        if let endRange = remainingHTML.range(of: #"<div class="(sample-tests|note)">"#, options: .regularExpression) {
            let endIndex = html.index(startIndex, offsetBy: remainingHTML.distance(from: remainingHTML.startIndex, to: endRange.lowerBound))
            let content = String(html[startIndex..<endIndex])
            return parseContent(content)
        } else {
            // 如果找不到下一个部分，取到 problem-statement 结束
            if let problemEndRange = remainingHTML.range(of: #"</div>\s*</div>\s*<script"#, options: .regularExpression) {
                let endIndex = html.index(startIndex, offsetBy: remainingHTML.distance(from: remainingHTML.startIndex, to: problemEndRange.lowerBound))
                let content = String(html[startIndex..<endIndex])
                return parseContent(content)
            }
        }
        
        return []
    }
    
    private static func extractSamples(from html: String) -> [TestSample] {
        var samples: [TestSample] = []
        
        // 首先定位到 sample-tests 区域
        guard let sampleTestsRange = html.range(of: #"<div class="sample-test">"#) else {
            print("⚠️ 未找到 sample-test 区域")
            return []
        }
        
        // 只在 sample-tests 区域内提取样例
        let sampleTestsStart = sampleTestsRange.lowerBound
        let remainingHTML = String(html[sampleTestsStart...])
        
        // 找到 sample-tests 区域的结束位置（下一个主要 div 或结束标签）
        let sampleTestsHTML: String
        if let endRange = remainingHTML.range(of: #"</div>\s*</div>\s*<div class="(note|footer)">"#, options: .regularExpression) {
            sampleTestsHTML = String(remainingHTML[..<endRange.lowerBound])
        } else if let endRange = remainingHTML.range(of: #"</div>\s*</div>\s*</div>\s*<script"#, options: .regularExpression) {
            sampleTestsHTML = String(remainingHTML[..<endRange.lowerBound])
        } else {
            sampleTestsHTML = remainingHTML
        }
        
        #if DEBUG
        print("🔍 Sample tests HTML (first 1000 chars):\n\(sampleTestsHTML.prefix(1000))")
        #endif
        
        // 提取所有样例输入和输出
        // 注意：必须使用非贪婪匹配，并且确保只匹配 <pre> 标签内的内容
        let inputPattern = #"<div class="input">[^>]*>[\s\S]*?<pre[^>]*>([\s\S]*?)</pre>"#
        let outputPattern = #"<div class="output">[^>]*>[\s\S]*?<pre[^>]*>([\s\S]*?)</pre>"#
        
        let inputs = extractAllMatches(from: sampleTestsHTML, pattern: inputPattern)
        let outputs = extractAllMatches(from: sampleTestsHTML, pattern: outputPattern)
        
        #if DEBUG
        print("🔍 找到 \(inputs.count) 个输入, \(outputs.count) 个输出")
        if inputs.count > 0 {
            let firstInput = inputs[0]
            print("🔍 第一个原始输入 (前200字符): \(firstInput.prefix(200))")
            print("🔍 原始输入中的换行符数量: \(firstInput.filter { $0 == "\n" }.count)")
            print("🔍 原始输入中的 <br> 标签数量: \(firstInput.components(separatedBy: "<br").count - 1)")
            // 显示字符的十六进制表示
            let chars = Array(firstInput.prefix(50))
            print("🔍 前50个字符: \(chars.map { String(format: "%02X", $0.asciiValue ?? 0) }.joined(separator: " "))")
        }
        if outputs.count > 0 {
            print("🔍 第一个原始输出 (前200字符): \(outputs[0].prefix(200))")
        }
        #endif
        
        for (index, (input, output)) in zip(inputs, outputs).enumerated() {
            // 提取分组信息（如果存在 test-example-line 标签）
            let (cleanInput, inputGroups) = extractTextWithGroups(from: input)
            let (cleanOutput, outputGroups) = extractTextWithGroups(from: output)
            
            #if DEBUG
            print("🔍 样例 \(index + 1):")
            print("   输入 (清理后): \(cleanInput.prefix(100))...")
            print("   输入换行符数量: \(cleanInput.filter { $0 == "\n" }.count)")
            if let groups = inputGroups {
                print("   输入分组: \(groups)")
            }
            print("   输出 (清理后): \(cleanOutput.prefix(100))...")
            print("   输出换行符数量: \(cleanOutput.filter { $0 == "\n" }.count)")
            if let groups = outputGroups {
                print("   输出分组: \(groups)")
            }
            #endif
            
            samples.append(TestSample(
                id: index + 1,
                input: cleanInput,
                output: cleanOutput,
                inputLineGroups: inputGroups,
                outputLineGroups: outputGroups
            ))
        }
        
        return samples
    }
    
    /// 从 HTML 中提取文本和分组信息
    /// 返回：(清理后的文本, 每行的组号数组)
    private static func extractTextWithGroups(from html: String) -> (String, [Int]?) {
        // 检查是否有 test-example-line 标签
        if html.contains("test-example-line") {
            // 使用正则提取每个 test-example-line
            let pattern = #"<div class="test-example-line[^"]*test-example-line-(\d+)[^"]*">([^<]*)</div>"#
            let regex = try! NSRegularExpression(pattern: pattern)
            let nsString = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
            
            var lines: [String] = []
            var groups: [Int] = []
            
            for match in matches {
                // 提取组号
                if match.numberOfRanges >= 2,
                   let groupRange = Range(match.range(at: 1), in: html),
                   let groupNum = Int(html[groupRange]) {
                    groups.append(groupNum)
                }
                
                // 提取行内容
                if match.numberOfRanges >= 3,
                   let lineRange = Range(match.range(at: 2), in: html) {
                    let lineText = String(html[lineRange])
                    lines.append(cleanHTML(lineText))
                }
            }
            
            #if DEBUG
            print("🔍 extractTextWithGroups: 找到 \(lines.count) 行，分组: \(groups)")
            #endif
            
            if !lines.isEmpty {
                return (lines.joined(separator: "\n"), groups)
            }
        }
        
        // 如果没有 test-example-line，使用旧方法
        return (cleanHTMLPreserveNewlines(html), nil)
    }
    
    private static func extractNote(from html: String) -> [ContentElement]? {
        guard let range = html.range(of: #"<div class="note">[\s\S]*?<div class="section-title">Note[\s\S]*?</div>([\s\S]*?)</div>\s*</div>"#, options: .regularExpression) else {
            return nil
        }
        
        let content = String(html[range])
        let elements = parseContent(content)
        return elements.isEmpty ? nil : elements
    }
    
    // MARK: - Content Parsing
    
    private static func parseContent(_ html: String) -> [ContentElement] {
        var elements: [ContentElement] = []
        
        #if DEBUG
        // 检查原始 HTML 中是否包含图片标签
        if html.contains("<img") {
            print("[ProblemParser] ✅ 原始 HTML 包含 <img 标签")
            // 查找第一个 img 标签的位置
            if let imgRange = html.range(of: "<img[^>]*>", options: .regularExpression) {
                let imgTag = String(html[imgRange])
                print("[ProblemParser] 第一个 img 标签: \(imgTag)")
            }
        } else {
            print("[ProblemParser] ❌ 原始 HTML 不包含 <img 标签")
        }
        #endif
        
        // 提取段落
        let paragraphs = extractParagraphs(from: html)
        
        for paragraph in paragraphs {
            // 检查是否包含公式：tex-formula 标签 或者 成对的美元符号
            let hasTexFormula = paragraph.contains("class=\"tex-formula\"")
            let hasDoubleDollar = paragraph.contains("$$")
            // 使用正则检查是否有成对的单美元符号（避免误判普通文本中的单个 $）
            let hasSingleDollarPair = paragraph.range(of: #"\$[^\$]+\$"#, options: .regularExpression) != nil
            
            if hasTexFormula || hasDoubleDollar || hasSingleDollarPair {
                // 包含 LaTeX 公式（块状 $$ 或行内 $）
                let parsedElements = parseLatex(from: paragraph)
                
                // 将解析出的元素包装成段落（如果包含多个元素或混合内容）
                if parsedElements.count == 1 {
                    // 单个元素：直接添加（可能是单个块级公式或纯文本）
                    elements.append(parsedElements[0])
                } else if parsedElements.count > 1 {
                    // 多个元素：检查是否有需要内联显示的内容
                    let hasInlineLatex = parsedElements.contains { element in
                        if case .inlineLatex = element {
                            return true
                        }
                        return false
                    }
                    
                    if hasInlineLatex {
                        // 包含行内公式：包装成段落以实现内联显示
                        elements.append(.paragraph(parsedElements))
                    } else {
                        // 全是块级元素：分别添加
                        elements.append(contentsOf: parsedElements)
                    }
                }
            } else if paragraph.contains("<img") {
                // 包含图片
                if let imageURL = extractImageURL(from: paragraph) {
                    #if DEBUG
                    print("[ProblemParser] 添加图片元素: \(imageURL)")
                    #endif
                    elements.append(.image(imageURL))
                } else {
                    #if DEBUG
                    print("[ProblemParser] 警告：段落包含 <img 但无法提取 URL: \(paragraph.prefix(100))...")
                    #endif
                }
            } else if paragraph.contains("<ul") || paragraph.contains("<ol") {
                // 列表
                let listItems = extractListItems(from: paragraph)
                if !listItems.isEmpty {
                    elements.append(.list(listItems))
                }
            } else {
                // 普通文本
                let text = cleanHTML(paragraph).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    elements.append(.text(text))
                }
            }
        }
        
        return elements
    }
    
    private static func extractParagraphs(from html: String) -> [String] {
        var paragraphs: [String] = []
        let nsString = html as NSString
        
        // 定义所有需要提取的模式
        struct Match {
            let range: NSRange
            let content: String
        }
        
        var allMatches: [Match] = []
        
        // 1. 提取所有 <p> 标签
        let pPattern = #"<p>([\s\S]*?)</p>"#
        if let pRegex = try? NSRegularExpression(pattern: pPattern, options: []) {
            let pResults = pRegex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            for result in pResults {
                if result.range.location != NSNotFound {
                    let match = nsString.substring(with: result.range)
                    allMatches.append(Match(range: result.range, content: match))
                }
            }
        }
        
        // 2. 提取特定类型的 div（包含实际内容的，如公式、图片、居中内容等）
        let contentDivPattern = #"<div class="(tex-formula|tex-span|center)[^"]*"[^>]*>(?:(?!<div).)*?</div>"#
        if let divRegex = try? NSRegularExpression(pattern: contentDivPattern, options: [.dotMatchesLineSeparators]) {
            let divResults = divRegex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            for result in divResults {
                if result.range.location != NSNotFound {
                    let match = nsString.substring(with: result.range)
                    allMatches.append(Match(range: result.range, content: match))
                }
            }
        }
        
        // 3. 提取 <center> 标签（通常包含图片）
        let centerPattern = #"<center>[\s\S]*?</center>"#
        if let centerRegex = try? NSRegularExpression(pattern: centerPattern, options: []) {
            let centerResults = centerRegex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            for result in centerResults {
                if result.range.location != NSNotFound {
                    let match = nsString.substring(with: result.range)
                    allMatches.append(Match(range: result.range, content: match))
                }
            }
        }
        
        // 4. 提取 <ul> 和 <ol> 列表（如果它们不在 <p> 中）
        let listPattern = #"<(ul|ol)[^>]*>[\s\S]*?</\1>"#
        if let listRegex = try? NSRegularExpression(pattern: listPattern, options: []) {
            let listResults = listRegex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            for result in listResults {
                if result.range.location != NSNotFound {
                    let match = nsString.substring(with: result.range)
                    allMatches.append(Match(range: result.range, content: match))
                }
            }
        }
        
        // 按照在 HTML 中的位置排序
        allMatches.sort { $0.range.location < $1.range.location }
        
        // 去重：如果一个匹配包含在另一个匹配中，只保留外层的
        var filteredMatches: [Match] = []
        for match in allMatches {
            let isContainedInOther = filteredMatches.contains { existing in
                NSLocationInRange(match.range.location, existing.range) &&
                NSLocationInRange(match.range.location + match.range.length - 1, existing.range)
            }
            if !isContainedInOther {
                // 同时检查新匹配是否包含已有的匹配
                filteredMatches.removeAll { existing in
                    NSLocationInRange(existing.range.location, match.range) &&
                    NSLocationInRange(existing.range.location + existing.range.length - 1, match.range)
                }
                filteredMatches.append(match)
            }
        }
        
        // 提取内容
        paragraphs = filteredMatches.map { $0.content }
        
        #if DEBUG
        print("[ProblemParser] 提取段落 - 共找到 \(paragraphs.count) 个元素（按原始顺序）")
        for (index, para) in paragraphs.enumerated() {
            if para.contains("<img") {
                print("[ProblemParser] ✅ 元素 #\(index) 包含图片: \(para.prefix(100))...")
            }
        }
        #endif
        
        return paragraphs
    }
    
    static func parseLatex(from html: String) -> [ContentElement] {
        var elements: [ContentElement] = []
        
        #if DEBUG
        if html.contains("$") {
            print("🔍 parseLatex input (first 200 chars): \(html.prefix(200))")
        }
        #endif
        
        // 策略：直接提取 <span class="tex-formula">$...$</span> 中的公式内容
        // 其他文本保持为普通文本
        
        let pattern = #"<span class="tex-formula">([^<]*(?:<[^>]+>[^<]*)*)</span>"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = html as NSString
        let results = regex?.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        
        #if DEBUG
        if let count = results?.count, count > 0 {
            print("🔍 Found \(count) tex-formula tags")
        }
        #endif
        
        // 如果没有找到 tex-formula 标签，但包含 $$ 或 $，尝试直接提取
        // 注意：$$$ 已在源头被替换成 $（行内）或 $$$$$$ 被替换成 $$（块状）
        if results?.isEmpty != false && (html.contains("$$") || html.contains("$")) {
            #if DEBUG
            print("🔍 No tex-formula tags found, using fallback regex for $ symbols")
            #endif
            
            // 使用非贪婪匹配：同时匹配 $$ 和 $ 之间的内容（优先匹配 $$）
            // 模式说明：先尝试匹配 $$...$$，如果不匹配再尝试 $...$
            let fallbackPattern = #"\$\$([^\$]+)\$\$|\$([^\$]+)\$"#
            let fallbackRegex = try? NSRegularExpression(pattern: fallbackPattern, options: [])
            let fallbackResults = fallbackRegex?.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            
            #if DEBUG
            if let count = fallbackResults?.count {
                print("🔍 Fallback found \(count) formulas")
            }
            #endif
            
            var lastIdx = 0
            fallbackResults?.forEach { match in
                // 添加公式前的文本
                if match.range.location > lastIdx {
                    let textRange = NSRange(location: lastIdx, length: match.range.location - lastIdx)
                    let text = cleanHTML(nsString.substring(with: textRange))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        elements.append(.text(text))
                    }
                }
                
                // 提取公式（捕获组1是 $$..$$，捕获组2是 $..$）
                var formula = ""
                var isBlockFormula = false
                
                if match.numberOfRanges > 1 {
                    let range1 = match.range(at: 1)
                    if range1.location != NSNotFound {
                        // 捕获组1：块级公式 $$...$$
                        formula = nsString.substring(with: range1).trimmingCharacters(in: .whitespacesAndNewlines)
                        isBlockFormula = true
                    } else if match.numberOfRanges > 2 {
                        let range2 = match.range(at: 2)
                        if range2.location != NSNotFound {
                            // 捕获组2：行内公式 $...$
                            formula = nsString.substring(with: range2).trimmingCharacters(in: .whitespacesAndNewlines)
                            isBlockFormula = false
                        }
                    }
                }
                
                if !formula.isEmpty {
                    #if DEBUG
                    print("🔍 Extracted \(isBlockFormula ? "block" : "inline") formula via fallback: \(formula)")
                    #endif
                    if isBlockFormula {
                        elements.append(.blockLatex(formula))
                    } else {
                        elements.append(.inlineLatex(formula))
                    }
                }
                
                lastIdx = match.range.location + match.range.length
            }
            
            // 添加剩余文本
            if lastIdx < nsString.length {
                let textRange = NSRange(location: lastIdx, length: nsString.length - lastIdx)
                let text = cleanHTML(nsString.substring(with: textRange))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    elements.append(.text(text))
                }
            }
            
            return elements
        }
        
        var lastIndex = 0
        
        // 临时缓存：用于合并连续的文本和行内公式
        var paragraphBuffer: [ContentElement] = []
        
        results?.forEach { result in
            // 添加公式前的普通文本
            if result.range.location > lastIndex {
                let textRange = NSRange(location: lastIndex, length: result.range.location - lastIndex)
                let text = cleanHTML(nsString.substring(with: textRange))
                // ⚠️ 不要 trim，保留空格以保持文本流
                if !text.isEmpty {
                    paragraphBuffer.append(.text(text))
                }
            }
            
            // 提取 LaTeX 公式内容（捕获组1）
            if result.numberOfRanges > 1 {
                let latexRange = result.range(at: 1)
                var latexContent = nsString.substring(with: latexRange)
                
                // 清理内部的 HTML 标签
                latexContent = latexContent
                    .replacingOccurrences(of: #"<span class="tex-font-style-[^"]+">"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "</span>", with: "")
                
                // 移除 $ 符号并判断是块级还是行内公式
                var isBlockFormula = false
                
                // 先尝试匹配 $$...$$（两个美元符号，块级公式）
                if latexContent.hasPrefix("$$") && latexContent.hasSuffix("$$") && latexContent.count > 4 {
                    latexContent = String(latexContent.dropFirst(2).dropLast(2))
                    isBlockFormula = true
                }
                // 再尝试匹配 $...$ （单个美元符号，行内公式）
                else if latexContent.hasPrefix("$") && latexContent.hasSuffix("$") && latexContent.count > 2 {
                    latexContent = String(latexContent.dropFirst(1).dropLast(1))
                    isBlockFormula = false
                }
                
                latexContent = latexContent.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !latexContent.isEmpty {
                    #if DEBUG
                    print("🔍 Extracted \(isBlockFormula ? "block" : "inline") formula from tex-formula tag: \(latexContent)")
                    #endif
                    
                    if isBlockFormula {
                        // 块级公式：先flush缓存，再添加块级公式
                        if !paragraphBuffer.isEmpty {
                            if paragraphBuffer.count == 1 {
                                elements.append(paragraphBuffer[0])
                            } else {
                                elements.append(.paragraph(paragraphBuffer))
                            }
                            paragraphBuffer = []
                        }
                        elements.append(.blockLatex(latexContent))
                    } else {
                        // 行内公式：加入缓存
                        paragraphBuffer.append(.inlineLatex(latexContent))
                    }
                }
            }
            
            lastIndex = result.range.location + result.range.length
        }
        
        // 添加剩余的普通文本到缓存
        if lastIndex < nsString.length {
            let textRange = NSRange(location: lastIndex, length: nsString.length - lastIndex)
            let text = cleanHTML(nsString.substring(with: textRange))
            // ⚠️ 不要 trim，保留空格以保持文本流
            if !text.isEmpty {
                paragraphBuffer.append(.text(text))
            }
        }
        
        // Flush 缓存中的剩余内容
        if !paragraphBuffer.isEmpty {
            #if DEBUG
            print("🔍 Flushing paragraph buffer with \(paragraphBuffer.count) element(s)")
            for (i, el) in paragraphBuffer.enumerated() {
                switch el {
                case .text(let t):
                    print("   [\(i)] Text: \(t.prefix(50))")
                case .inlineLatex(let f):
                    print("   [\(i)] InlineLatex: \(f)")
                default:
                    print("   [\(i)] Other")
                }
            }
            
            if paragraphBuffer.count == 1 {
                print("   → Adding as single element (not paragraph)")
            } else {
                print("   → Adding as .paragraph with \(paragraphBuffer.count) elements")
            }
            #endif
            
            // ⚠️ 修复：即使只有一个元素，如果是 inlineLatex 也应该包装成段落
            // 这样可以使用 MixedContentView 渲染，避免换行
            if paragraphBuffer.count == 1, case .text = paragraphBuffer[0] {
                // 只有纯文本时，直接添加
                elements.append(paragraphBuffer[0])
            } else {
                // 其他情况（包括单个 inlineLatex）都包装成段落
                elements.append(.paragraph(paragraphBuffer))
            }
        }
        
        // 如果没有找到任何元素，返回清理后的纯文本
        if elements.isEmpty {
            let cleanText = cleanHTML(html).trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanText.isEmpty {
                elements.append(.text(cleanText))
            }
        }
        
        return elements
    }
    
    private static func extractImageURL(from html: String) -> String? {
        if let range = html.range(of: #"<img[^>]+src="([^"]+)""#, options: .regularExpression) {
            let match = String(html[range])
            if let srcRange = match.range(of: #"src="([^"]+)""#, options: .regularExpression) {
                var src = String(match[srcRange])
                    .replacingOccurrences(of: "src=\"", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                
                // 处理相对路径
                if src.hasPrefix("//") {
                    src = "https:" + src
                } else if src.hasPrefix("/") {
                    src = "https://codeforces.com" + src
                }
                
                return src
            }
        }
        return nil
    }
    
    private static func extractListItems(from html: String) -> [String] {
        let pattern = #"<li>([\s\S]*?)</li>"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = html as NSString
        let results = regex?.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var items: [String] = []
        results?.forEach { result in
            if result.range.location != NSNotFound {
                let match = nsString.substring(with: result.range)
                let cleaned = cleanHTML(match).trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    items.append(cleaned)
                }
            }
        }
        
        return items
    }
    
    private static func extractAllMatches(from html: String, pattern: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = html as NSString
        let results = regex?.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var matches: [String] = []
        results?.forEach { result in
            if result.numberOfRanges > 1 {
                let captureRange = result.range(at: 1)
                if captureRange.location != NSNotFound {
                    matches.append(nsString.substring(with: captureRange))
                }
            }
        }
        
        return matches
    }
    
    // MARK: - HTML Cleaning
    
    static func cleanHTML(_ html: String) -> String {
        var result = html
        
        // 移除 HTML 标签
        result = result.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        
        // 处理 HTML 实体
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&mdash;", with: "—")
        result = result.replacingOccurrences(of: "&ndash;", with: "–")
        result = result.replacingOccurrences(of: "&hellip;", with: "…")
        
        // 清理多余空白
        result = result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        return result
    }
    
    /// 清理 HTML 但保留换行符（用于样例输入输出）
    static func cleanHTMLPreserveNewlines(_ html: String) -> String {
        var result = html
        
        // 首先移除 HTML 标签之间的换行符和空白，避免产生额外的空行
        // 例如 "</div>\n<div>" 变成 "</div><div>"
        result = result.replacingOccurrences(
            of: #">\s+<"#,
            with: "><",
            options: .regularExpression
        )
        
        // 将 <br> 标签转换为换行符
        result = result.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
        
        // 将块级元素的结束标签转换为换行符（在移除标签之前）
        // 这样 <div>内容1</div><div>内容2</div> 会变成 <div>内容1\n<div>内容2\n
        let blockTags = ["div", "p", "pre"]
        for tag in blockTags {
            result = result.replacingOccurrences(
                of: #"</\#(tag)>"#,
                with: "\n",
                options: .regularExpression
            )
        }
        
        // 移除剩余的 HTML 标签
        result = result.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        
        // 处理 HTML 实体
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&mdash;", with: "—")
        result = result.replacingOccurrences(of: "&ndash;", with: "–")
        result = result.replacingOccurrences(of: "&hellip;", with: "…")
        
        // 将连续的空格（但不包括换行）替换为单个空格
        // 注意：这里使用 [ \t]+ 而不是 \s+，以保留换行符
        result = result.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
        
        // 移除每行首尾的空格，但保留换行
        let lines = result.components(separatedBy: "\n")
        let trimmedLines = lines.map { $0.trimmingCharacters(in: .whitespaces) }
        result = trimmedLines.joined(separator: "\n")
        
        // 只移除首尾多余的空白行，但保留最后一个换行符（如果原本存在）
        // 先检查原字符串是否以换行结尾
        let endsWithNewline = result.hasSuffix("\n")
        
        // 移除首尾的空白字符
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果原本以换行结尾，恢复最后的换行符
        if endsWithNewline && !result.isEmpty {
            result += "\n"
        }
        
        return result
    }
}

// MARK: - Parser Error

enum ParserError: Error, LocalizedError {
    case invalidURL
    case networkError
    case encodingError
    case cloudflareBlocked
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network request failed"
        case .encodingError:
            return "Unable to decode HTML"
        case .cloudflareBlocked:
            return "Blocked by Cloudflare. Please try again later."
        case .parseError(let message):
            return "Parse error: \(message)"
        }
    }
}

