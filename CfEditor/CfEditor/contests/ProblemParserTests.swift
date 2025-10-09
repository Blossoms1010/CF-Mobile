//
//  ProblemParserTests.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import Foundation

// MARK: - Parser Testing Utilities

#if DEBUG
extension ProblemParser {
    /// 测试解析器（使用示例 HTML）
    static func testParser() async {
        print("🧪 Testing Problem Parser...")
        
        // 测试 1: 解析真实题目
        do {
            let problem = try await fetchAndParse(contestId: 2042, problemIndex: "A")
            print("✅ Successfully parsed problem: \(problem.name)")
            print("   - Time Limit: \(problem.timeLimit)")
            print("   - Memory Limit: \(problem.memoryLimit)")
            print("   - Samples: \(problem.samples.count)")
            print("   - Statement elements: \(problem.statement.count)")
        } catch {
            print("❌ Failed to parse: \(error)")
        }
        
        // 测试 2: HTML 清理
        testHTMLCleaning()
        
        // 测试 3: LaTeX 提取
        testLatexExtraction()
    }
    
    private static func testHTMLCleaning() {
        print("\n🧪 Testing HTML Cleaning...")
        
        let testCases = [
            ("<p>Hello &nbsp; World</p>", "Hello World"),
            ("&lt;script&gt;", "<script>"),
            ("1 &lt;= n &lt;= 100", "1 <= n <= 100"),
            ("&amp; &quot; &#39;", "& \" '"),
        ]
        
        for (html, expected) in testCases {
            let cleaned = ProblemParser.cleanHTML(html)
            if cleaned.trimmingCharacters(in: .whitespacesAndNewlines).contains(expected) {
                print("✅ \(html) → \(cleaned)")
            } else {
                print("❌ Expected '\(expected)', got '\(cleaned)'")
            }
        }
    }
    
    private static func testLatexExtraction() {
        print("\n🧪 Testing LaTeX Extraction...")
        
        let testHTML = "<p>The sum is $$\\sum_{i=1}^{n} a_i$$ and inline $x^2$</p>"
        let elements = ProblemParser.parseLatex(from: testHTML)
        
        print("   Extracted \(elements.count) elements:")
        for element in elements {
            switch element {
            case .text(let content):
                print("   - Text: \(content)")
            case .inlineLatex(let formula):
                print("   - Inline LaTeX: \(formula)")
            case .blockLatex(let formula):
                print("   - Block LaTeX: \(formula)")
            default:
                break
            }
        }
    }
}
#endif

// MARK: - Quick Test Function

/// 快速测试函数（可在应用启动时调用）
func testProblemParserQuick() {
    #if DEBUG
    Task {
        await ProblemParser.testParser()
    }
    #endif
}

