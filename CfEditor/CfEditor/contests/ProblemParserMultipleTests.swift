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
            // 如果 HTML 提供了分组信息，优先使用
            if let originalInputGroups = sample.inputLineGroups, originalInputGroups.count >= 2 {
                #if DEBUG
                print("🔍 adjustSamplesForMultipleTestCases (使用HTML分组):")
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
            
            // HTML 没有分组信息时，手动创建智能分组
            let inputLines = sample.input.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let outputLines = sample.output.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            
            // 尝试解析第一行为测试用例数量
            guard let firstLine = inputLines.first,
                  let testCount = Int(firstLine.trimmingCharacters(in: .whitespaces)),
                  testCount > 1 && testCount <= 100,
                  inputLines.count > 1 else {
                return sample
            }
            
            #if DEBUG
            print("🔍 adjustSamplesForMultipleTestCases (智能分组):")
            print("   检测到 \(testCount) 个测试用例")
            print("   输入行数: \(inputLines.count), 输出行数: \(outputLines.count)")
            #endif
            
            // 为输入创建分组：第一行设为 -1，其余行基于空行或均匀分组
            var newInputGroups = [-1]  // 第一行（测试数量）
            
            // 尝试基于空行分隔输入（跳过第一行的测试数量）
            let inputLinesWithEmpty = sample.input.components(separatedBy: "\n")
            var inputCurrentGroup = 0
            var inputConsecutiveEmptyLines = 0
            var tempInputGroups: [Int] = []
            var firstLineSkipped = false
            
            for line in inputLinesWithEmpty {
                // 跳过第一行（测试数量）
                if !firstLineSkipped {
                    firstLineSkipped = true
                    continue
                }
                
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    inputConsecutiveEmptyLines += 1
                } else {
                    if inputConsecutiveEmptyLines > 0 && !tempInputGroups.isEmpty {
                        inputCurrentGroup += 1
                    }
                    inputConsecutiveEmptyLines = 0
                    tempInputGroups.append(inputCurrentGroup)
                }
            }
            
            // 判断输入空行分组是否有效
            let inputUniqueGroups = Set(tempInputGroups).count
            let isInputValidGrouping = inputUniqueGroups > 1 && inputUniqueGroups <= testCount + 1
            
            if isInputValidGrouping && !tempInputGroups.isEmpty {
                newInputGroups.append(contentsOf: tempInputGroups)
                #if DEBUG
                print("   输入使用空行分组: \(inputUniqueGroups) 组")
                #endif
            } else {
                // 回退到均匀分组
                let remainingInputLines = inputLines.count - 1
                let linesPerTest = max(1, remainingInputLines / testCount)
                for i in 0..<remainingInputLines {
                    let groupIndex = min(i / linesPerTest, testCount - 1)
                    newInputGroups.append(groupIndex)
                }
                #if DEBUG
                print("   输入使用均匀分组: 每组约 \(linesPerTest) 行")
                #endif
            }
            
            // 为输出创建分组：基于空行分隔或均匀分组
            var newOutputGroups: [Int] = []
            
            // 策略1：检测空行分隔（连续空行视为分隔符）
            let outputLinesWithEmpty = sample.output.components(separatedBy: "\n")
            var currentGroup = 0
            var consecutiveEmptyLines = 0
            var groupCounts: [Int] = []  // 记录每组的行数
            
            for line in outputLinesWithEmpty {
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    consecutiveEmptyLines += 1
                } else {
                    // 如果前面有空行，视为分组分隔符
                    if consecutiveEmptyLines > 0 && !newOutputGroups.isEmpty {
                        currentGroup += 1
                    }
                    consecutiveEmptyLines = 0
                    newOutputGroups.append(currentGroup)
                }
            }
            
            // 判断空行分组是否合理
            // 要求：组数必须等于 testCount，允许 ±1 的误差
            let uniqueGroups = Set(newOutputGroups).count
            let isValidGrouping = (uniqueGroups >= testCount - 1) && (uniqueGroups <= testCount + 1)
            
            #if DEBUG
            print("   空行分组检测: \(uniqueGroups) 组, 预期: \(testCount) 组, 是否有效: \(isValidGrouping)")
            #endif
            
            // 如果空行分组无效，尝试其他策略
            if !isValidGrouping || newOutputGroups.isEmpty {
                // 策略2：如果输出行数恰好等于测试用例数，假设每个子测试1行输出
                if outputLines.count == testCount {
                    newOutputGroups = Array(0..<testCount)
                    #if DEBUG
                    print("   ✅ 输出行数(\(outputLines.count))等于测试数(\(testCount))，使用1行1组策略")
                    #endif
                } else {
                    // 策略3：尝试均匀分组
                    let linesPerOutputTest = max(1, outputLines.count / testCount)
                    for i in 0..<outputLines.count {
                        let groupIndex = min(i / linesPerOutputTest, testCount - 1)
                        newOutputGroups.append(groupIndex)
                    }
                    #if DEBUG
                    print("   ⚠️ 使用均匀分组作为备选: 每组约 \(linesPerOutputTest) 行")
                    #endif
                }
            } else {
                #if DEBUG
                print("   ✅ 使用空行分组")
                #endif
            }
            
            #if DEBUG
            print("   生成的输入分组: \(newInputGroups)")
            print("   生成的输出分组: \(newOutputGroups)")
            #endif
            
            return TestSample(
                id: Int(sample.id.replacingOccurrences(of: "sample-", with: "")) ?? 0,
                input: sample.input,
                output: sample.output,
                inputLineGroups: newInputGroups,
                outputLineGroups: newOutputGroups.isEmpty ? nil : newOutputGroups
            )
        }
    }
}

