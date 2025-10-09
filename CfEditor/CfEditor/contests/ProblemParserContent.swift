//
//  ProblemParserContent.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import Foundation

// MARK: - Content Parsing

extension ProblemParser {
    
    /// 解析内容元素（段落、公式、图片、列表等）
    static func parseContent(_ html: String) -> [ContentElement] {
        var elements: [ContentElement] = []
        
        #if DEBUG
        if html.contains("<img") {
            print("[ProblemParser] ✅ 原始 HTML 包含 <img 标签")
        }
        #endif
        
        let paragraphs = extractParagraphs(from: html)
        
        for paragraph in paragraphs {
            // 检查是否包含公式
            let hasTexFormula = paragraph.contains("class=\"tex-formula\"")
            let hasDoubleDollar = paragraph.contains("$$")
            let hasSingleDollarPair = paragraph.range(of: #"\$[^\$]+\$"#, options: .regularExpression) != nil
            
            if hasTexFormula || hasDoubleDollar || hasSingleDollarPair {
                // 包含 LaTeX 公式
                let parsedElements = parseLatex(from: paragraph)
                
                if parsedElements.count == 1 {
                    elements.append(parsedElements[0])
                } else if parsedElements.count > 1 {
                    let hasInlineLatex = parsedElements.contains { element in
                        if case .inlineLatex = element {
                            return true
                        }
                        return false
                    }
                    
                    if hasInlineLatex {
                        elements.append(.paragraph(parsedElements))
                    } else {
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
    
    /// 从 HTML 中提取段落
    static func extractParagraphs(from html: String) -> [String] {
        var paragraphs: [String] = []
        let nsString = html as NSString
        
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
        
        // 2. 提取特定类型的 div
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
        
        // 3. 提取 <center> 标签
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
        
        // 4. 提取 <ul> 和 <ol> 列表
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
                filteredMatches.removeAll { existing in
                    NSLocationInRange(existing.range.location, match.range) &&
                    NSLocationInRange(existing.range.location + existing.range.length - 1, match.range)
                }
                filteredMatches.append(match)
            }
        }
        
        paragraphs = filteredMatches.map { $0.content }
        
        #if DEBUG
        print("[ProblemParser] 提取段落 - 共找到 \(paragraphs.count) 个元素（按原始顺序）")
        for (index, para) in paragraphs.enumerated() {
            if para.contains("<img") {
                print("[ProblemParser] ✅ 元素 #\(index) 包含图片")
            }
        }
        #endif
        
        return paragraphs
    }
}

