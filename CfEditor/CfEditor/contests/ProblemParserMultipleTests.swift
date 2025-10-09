//
//  ProblemParserMultipleTests.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import Foundation

// MARK: - Multiple Test Cases Detection

extension ProblemParser {
    
    /// 检测题目是否包含多组测试用例
    static func detectMultipleTestCases(from inputSpec: [ContentElement]) -> Bool {
        let text = extractTextFromElements(inputSpec).lowercased()
        
        // 检测常见的多测模式
        let patterns = [
            "first line contains.*t.*test case",
            "first line contains.*t.*number of test",
            "first line.*integer t",
            "test cases",
            "number of test cases",
            "contains t \\(",
            "contains an integer t"
        ]
        
        for pattern in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    /// 从 ContentElement 数组中提取纯文本
    static func extractTextFromElements(_ elements: [ContentElement]) -> String {
        var result = ""
        
        for element in elements {
            switch element {
            case .text(let content):
                result += content + " "
            case .paragraph(let subElements):
                result += extractTextFromElements(subElements) + " "
            case .list(let items):
                result += items.joined(separator: " ") + " "
            default:
                break
            }
        }
        
        return result
    }
    
    /// 调整多测题目的样例分组（第一行 t 单独分组，不参与高亮）
    static func adjustSamplesForMultipleTestCases(_ samples: [TestSample]) -> [TestSample] {
        return samples.map { sample in
            guard let originalInputGroups = sample.inputLineGroups,
                  originalInputGroups.count >= 2 else {
                return sample
            }
            
            #if DEBUG
            print("🔍 adjustSamplesForMultipleTestCases:")
            print("   原始输入分组: \(originalInputGroups)")
            print("   原始输出分组: \(sample.outputLineGroups ?? [])")
            #endif
            
            // 将输入的第一行（测试用例数量 t）设为组 -1，其余行组号减1
            var newInputGroups = [-1]
            
            for i in 1..<originalInputGroups.count {
                newInputGroups.append(originalInputGroups[i] - 1)
            }
            
            // 输出的所有组号也减1
            var newOutputGroups: [Int]? = nil
            if let originalOutputGroups = sample.outputLineGroups {
                newOutputGroups = originalOutputGroups.map { $0 - 1 }
            }
            
            #if DEBUG
            print("   调整后输入分组: \(newInputGroups)")
            print("   调整后输出分组: \(newOutputGroups ?? [])")
            #endif
            
            return TestSample(
                id: Int(sample.id.replacingOccurrences(of: "sample-", with: "")) ?? 0,
                input: sample.input,
                output: sample.output,
                inputLineGroups: newInputGroups,
                outputLineGroups: newOutputGroups
            )
        }
    }
}

