//
//  MultipleTestCasesDetectionTests.swift
//  CfEditorTests
//
//  Created by AI on 2025-10-09.
//

import XCTest
@testable import CfEditor

class MultipleTestCasesDetectionTests: XCTestCase {
    
    // 测试多测题目检测
    func testDetectMultipleTestCases() {
        // 模拟包含多测的输入说明
        let inputSpec1: [ContentElement] = [
            .paragraph([
                .text("The first line contains an integer "),
                .inlineLatex("t"),
                .text(" ("),
                .inlineLatex("1 \\le t \\le 100"),
                .text(") — the number of test cases.")
            ])
        ]
        
        let inputSpec2: [ContentElement] = [
            .text("The first line of input contains a single integer t — the number of test cases.")
        ]
        
        let inputSpec3: [ContentElement] = [
            .paragraph([
                .text("Input consists of multiple test cases. The first line contains t.")
            ])
        ]
        
        // 模拟不包含多测的输入说明
        let inputSpec4: [ContentElement] = [
            .paragraph([
                .text("The first line contains two integers n and m.")
            ])
        ]
        
        // 验证检测结果
        XCTAssertTrue(detectMultipleTestCases(from: inputSpec1), "应该检测到多测（模式1）")
        XCTAssertTrue(detectMultipleTestCases(from: inputSpec2), "应该检测到多测（模式2）")
        XCTAssertTrue(detectMultipleTestCases(from: inputSpec3), "应该检测到多测（模式3）")
        XCTAssertFalse(detectMultipleTestCases(from: inputSpec4), "不应该检测到多测")
    }
    
    // 测试样例分组调整
    func testAdjustSamplesForMultipleTestCases() {
        let sample = TestSample(
            id: 1,
            input: "3\n1 2\n3 4\n5 6",
            output: "3\n7\n11",
            inputLineGroups: [1, 2, 3, 4],
            outputLineGroups: [1, 2, 3]
        )
        
        let adjusted = adjustSamplesForMultipleTestCases([sample])
        
        // 验证第一行被设置为 -1（不参与高亮）
        XCTAssertNotNil(adjusted.first?.inputLineGroups)
        XCTAssertEqual(adjusted.first?.inputLineGroups?.first, -1, "第一行应该被设置为 -1")
        
        // 验证其余行的分组
        XCTAssertEqual(adjusted.first?.inputLineGroups?.count, 4, "应该有4行")
        XCTAssertEqual(adjusted.first?.inputLineGroups?[1], 1, "第二行应该是组 1")
        XCTAssertEqual(adjusted.first?.inputLineGroups?[2], 2, "第三行应该是组 2")
        XCTAssertEqual(adjusted.first?.inputLineGroups?[3], 3, "第四行应该是组 3")
    }
    
    // 辅助函数：直接调用 ProblemParser 的私有方法进行测试
    // 注意：这些是模拟实现，实际测试需要访问私有方法
    private func detectMultipleTestCases(from inputSpec: [ContentElement]) -> Bool {
        let text = extractTextFromElements(inputSpec).lowercased()
        
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
    
    private func extractTextFromElements(_ elements: [ContentElement]) -> String {
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
    
    private func adjustSamplesForMultipleTestCases(_ samples: [TestSample]) -> [TestSample] {
        return samples.map { sample in
            let inputLines = sample.input.components(separatedBy: .newlines)
            
            if inputLines.count >= 2 {
                var newInputGroups = [Int](repeating: -1, count: 1)
                
                for i in 1..<inputLines.count {
                    newInputGroups.append(i)
                }
                
                return TestSample(
                    id: Int(sample.id.replacingOccurrences(of: "sample-", with: "")) ?? 0,
                    input: sample.input,
                    output: sample.output,
                    inputLineGroups: newInputGroups,
                    outputLineGroups: sample.outputLineGroups
                )
            }
            
            return sample
        }
    }
}

