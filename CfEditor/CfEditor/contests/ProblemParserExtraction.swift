//
//  ProblemParserExtraction.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import Foundation

// MARK: - Content Extraction Methods

extension ProblemParser {
    
    // MARK: - Basic Information Extraction
    
    static func extractTitle(from html: String) -> String {
        if let range = html.range(of: #"<div class="title">([^<]+)</div>"#, options: .regularExpression) {
            let match = String(html[range])
            return match.replacingOccurrences(of: #"<div class="title">"#, with: "")
                .replacingOccurrences(of: "</div>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "Untitled Problem"
    }
    
    static func extractTimeLimit(from html: String) -> String {
        if let range = html.range(of: #"<div class="time-limit">.*?(\d+\.?\d*)\s*(second|seconds|ms)"#, options: .regularExpression) {
            let match = String(html[range])
            if let numberRange = match.range(of: #"\d+\.?\d*\s*(second|seconds|ms)"#, options: .regularExpression) {
                return String(match[numberRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return "1 second"
    }
    
    static func extractMemoryLimit(from html: String) -> String {
        if let range = html.range(of: #"<div class="memory-limit">.*?(\d+)\s*megabytes"#, options: .regularExpression) {
            let match = String(html[range])
            if let numberRange = match.range(of: #"\d+\s*megabytes"#, options: .regularExpression) {
                return String(match[numberRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return "256 megabytes"
    }
    
    static func extractIOFiles(from html: String) -> (String, String) {
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
    
    // MARK: - Section Extraction
    
    static func extractStatement(from html: String) -> [ContentElement] {
        #if DEBUG
        print("\n[ProblemParser] ========== extractStatement 开始 ==========")
        #endif
        
        guard let startRange = html.range(of: #"<div class="header">[\s\S]*?</div>"#, options: .regularExpression) else {
            return [.text("Unable to extract problem statement")]
        }
        
        let afterHeader = startRange.upperBound
        let remainingHTML = String(html[afterHeader...])
        
        guard let divStartRange = remainingHTML.range(of: #"<div>"#, options: []) else {
            return [.text("Unable to extract problem statement")]
        }
        
        let contentStart = html.index(afterHeader, offsetBy: remainingHTML.distance(from: remainingHTML.startIndex, to: divStartRange.upperBound))
        
        guard let endRange = html.range(of: #"<div class="input-specification">"#, options: .regularExpression) else {
            return [.text("Unable to extract problem statement")]
        }
        
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
        }
        #endif
        
        return parseContent(content)
    }
    
    static func extractInputSpecification(from html: String) -> [ContentElement] {
        guard let startRange = html.range(of: #"<div class="input-specification">[\s\S]*?<div class="section-title">Input[\s\S]*?</div>"#, options: .regularExpression),
              let endRange = html.range(of: #"<div class="output-specification">"#, options: .regularExpression) else {
            return []
        }
        
        let startIndex = startRange.upperBound
        let endIndex = endRange.lowerBound
        
        guard startIndex < endIndex else {
            return []
        }
        
        let content = String(html[startIndex..<endIndex])
        return parseContent(content)
    }
    
    static func extractOutputSpecification(from html: String) -> [ContentElement] {
        guard let startRange = html.range(of: #"<div class="output-specification">[\s\S]*?<div class="section-title">Output[\s\S]*?</div>"#, options: .regularExpression) else {
            return []
        }
        
        let startIndex = startRange.upperBound
        let remainingHTML = String(html[startIndex...])
        
        if let endRange = remainingHTML.range(of: #"<div class="(sample-tests|note)">"#, options: .regularExpression) {
            let endIndex = html.index(startIndex, offsetBy: remainingHTML.distance(from: remainingHTML.startIndex, to: endRange.lowerBound))
            let content = String(html[startIndex..<endIndex])
            return parseContent(content)
        } else if let problemEndRange = remainingHTML.range(of: #"</div>\s*</div>\s*<script"#, options: .regularExpression) {
            let endIndex = html.index(startIndex, offsetBy: remainingHTML.distance(from: remainingHTML.startIndex, to: problemEndRange.lowerBound))
            let content = String(html[startIndex..<endIndex])
            return parseContent(content)
        }
        
        return []
    }
    
    static func extractNote(from html: String) -> [ContentElement]? {
        guard let range = html.range(of: #"<div class="note">[\s\S]*?<div class="section-title">Note[\s\S]*?</div>([\s\S]*?)</div>\s*</div>"#, options: .regularExpression) else {
            return nil
        }
        
        let content = String(html[range])
        let elements = parseContent(content)
        return elements.isEmpty ? nil : elements
    }
    
    // MARK: - Sample Extraction
    
    static func extractSamples(from html: String) -> [TestSample] {
        var samples: [TestSample] = []
        
        guard let sampleTestsRange = html.range(of: #"<div class="sample-test">"#) else {
            print("⚠️ 未找到 sample-test 区域")
            return []
        }
        
        let sampleTestsStart = sampleTestsRange.lowerBound
        let remainingHTML = String(html[sampleTestsStart...])
        
        let sampleTestsHTML: String
        if let endRange = remainingHTML.range(of: #"</div>\s*</div>\s*<div class="(note|footer)">"#, options: .regularExpression) {
            sampleTestsHTML = String(remainingHTML[..<endRange.lowerBound])
        } else if let endRange = remainingHTML.range(of: #"</div>\s*</div>\s*</div>\s*<script"#, options: .regularExpression) {
            sampleTestsHTML = String(remainingHTML[..<endRange.lowerBound])
        } else {
            sampleTestsHTML = remainingHTML
        }
        
        let inputPattern = #"<div class="input">[\s\S]*?<pre>([\s\S]*?)</pre>"#
        let outputPattern = #"<div class="output">[\s\S]*?<pre>([\s\S]*?)</pre>"#
        
        let inputs = extractAllMatches(from: sampleTestsHTML, pattern: inputPattern)
        let outputs = extractAllMatches(from: sampleTestsHTML, pattern: outputPattern)
        
        for (index, (input, output)) in zip(inputs, outputs).enumerated() {
            let (cleanInput, inputGroups) = extractTextWithGroups(from: input)
            let (cleanOutput, outputGroups) = extractTextWithGroups(from: output)
            
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
    static func extractTextWithGroups(from html: String) -> (String, [Int]?) {
        if html.contains("test-example-line") {
            let pattern = #"<div class="test-example-line[^"]*test-example-line-(\d+)[^"]*">([^<]*)</div>"#
            let regex = try! NSRegularExpression(pattern: pattern)
            let nsString = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
            
            var lines: [String] = []
            var groups: [Int] = []
            
            for match in matches {
                if match.numberOfRanges >= 2,
                   let groupRange = Range(match.range(at: 1), in: html),
                   let groupNum = Int(html[groupRange]) {
                    groups.append(groupNum)
                }
                
                if match.numberOfRanges >= 3,
                   let lineRange = Range(match.range(at: 2), in: html) {
                    let lineText = String(html[lineRange])
                    lines.append(cleanHTML(lineText))
                }
            }
            
            if !lines.isEmpty {
                return (lines.joined(separator: "\n"), groups)
            }
        }
        
        return (cleanHTMLPreserveNewlines(html), nil)
    }
}

