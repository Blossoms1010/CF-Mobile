//
//  ProblemParserLatex.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import Foundation

// MARK: - LaTeX Parsing

extension ProblemParser {
    
    /// 解析包含 LaTeX 公式的 HTML
    static func parseLatex(from html: String) -> [ContentElement] {
        var elements: [ContentElement] = []
        
        #if DEBUG
        if html.contains("$") {
            print("🔍 parseLatex input (first 200 chars): \(html.prefix(200))")
        }
        #endif
        
        // 策略：直接提取 <span class="tex-formula">$...$</span> 中的公式内容
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
        if results?.isEmpty != false && (html.contains("$$") || html.contains("$")) {
            #if DEBUG
            print("🔍 No tex-formula tags found, using fallback regex for $ symbols")
            #endif
            
            return parseLatexFallback(from: html, nsString: nsString)
        }
        
        var lastIndex = 0
        var paragraphBuffer: [ContentElement] = []
        
        results?.forEach { result in
            // 添加公式前的普通文本
            if result.range.location > lastIndex {
                let textRange = NSRange(location: lastIndex, length: result.range.location - lastIndex)
                let text = cleanHTML(nsString.substring(with: textRange))
                if !text.isEmpty {
                    paragraphBuffer.append(.text(text))
                }
            }
            
            // 提取 LaTeX 公式内容
            if result.numberOfRanges > 1 {
                let latexRange = result.range(at: 1)
                var latexContent = nsString.substring(with: latexRange)
                
                // 清理内部的 HTML 标签
                latexContent = latexContent
                    .replacingOccurrences(of: #"<span class="tex-font-style-[^"]+">"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "</span>", with: "")
                
                // 移除 $ 符号并判断是块级还是行内公式
                var isBlockFormula = false
                
                if latexContent.hasPrefix("$$") && latexContent.hasSuffix("$$") && latexContent.count > 4 {
                    latexContent = String(latexContent.dropFirst(2).dropLast(2))
                    isBlockFormula = true
                } else if latexContent.hasPrefix("$") && latexContent.hasSuffix("$") && latexContent.count > 2 {
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
            if !text.isEmpty {
                paragraphBuffer.append(.text(text))
            }
        }
        
        // Flush 缓存中的剩余内容
        if !paragraphBuffer.isEmpty {
            if paragraphBuffer.count == 1, case .text = paragraphBuffer[0] {
                elements.append(paragraphBuffer[0])
            } else {
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
    
    /// LaTeX 解析的备用方法（直接匹配 $ 符号）
    private static func parseLatexFallback(from html: String, nsString: NSString) -> [ContentElement] {
        var elements: [ContentElement] = []
        
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
            
            // 提取公式
            var formula = ""
            var isBlockFormula = false
            
            if match.numberOfRanges > 1 {
                let range1 = match.range(at: 1)
                if range1.location != NSNotFound {
                    formula = nsString.substring(with: range1).trimmingCharacters(in: .whitespacesAndNewlines)
                    isBlockFormula = true
                } else if match.numberOfRanges > 2 {
                    let range2 = match.range(at: 2)
                    if range2.location != NSNotFound {
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
}

