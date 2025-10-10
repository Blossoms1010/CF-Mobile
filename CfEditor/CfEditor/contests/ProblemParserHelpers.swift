//
//  ProblemParserHelpers.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import Foundation

// MARK: - HTML Cleaning & Helper Methods

extension ProblemParser {
    
    /// 清理 HTML 标签和实体
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
        result = result.replacingOccurrences(
            of: #">\s+<"#,
            with: "><",
            options: .regularExpression
        )
        
        // 将 <br> 标签转换为换行符
        result = result.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
        
        // 将块级元素的结束标签转换为换行符
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
        result = result.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
        
        // 移除每行首尾的空格，但保留换行
        let lines = result.components(separatedBy: "\n")
        let trimmedLines = lines.map { $0.trimmingCharacters(in: .whitespaces) }
        result = trimmedLines.joined(separator: "\n")
        
        // 只移除首尾多余的空白行，但保留最后一个换行符（如果原本存在）
        let endsWithNewline = result.hasSuffix("\n")
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if endsWithNewline && !result.isEmpty {
            result += "\n"
        }
        
        return result
    }
    
    /// 从 HTML 中提取所有匹配的文本
    static func extractAllMatches(from html: String, pattern: String) -> [String] {
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
    
    /// 从 HTML 中提取图片 URL
    static func extractImageURL(from html: String) -> String? {
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
    
    /// 从 HTML 中提取列表项
    static func extractListItems(from html: String) -> [String] {
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
}

