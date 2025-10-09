//
//  ProblemDebugView.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//  调试视图，用于测试题目解析功能
//

import SwiftUI

struct ProblemDebugView: View {
    @State private var contestId: String = "2042"
    @State private var problemIndex: String = "A"
    @State private var isLoading: Bool = false
    @State private var result: String = ""
    @State private var problemStatement: ProblemStatement? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 输入区域
                    VStack(alignment: .leading, spacing: 12) {
                        Text("题目信息")
                            .font(.headline)
                        
                        HStack {
                            Text("Contest ID:")
                                .frame(width: 100, alignment: .leading)
                            TextField("2042", text: $contestId)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                        }
                        
                        HStack {
                            Text("Problem:")
                                .frame(width: 100, alignment: .leading)
                            TextField("A", text: $problemIndex)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.allCharacters)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    // 按钮
                    HStack(spacing: 12) {
                        Button {
                            Task {
                                await testParse()
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .frame(width: 20, height: 20)
                            } else {
                                Label("测试解析", systemImage: "play.fill")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoading)
                        
                        Button {
                            result = ""
                            problemStatement = nil
                        } label: {
                            Label("清空", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Divider()
                    
                    // 结果区域
                    if !result.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("解析结果")
                                .font(.headline)
                            
                            Text(result)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                    
                    // 预览区域
                    if let statement = problemStatement {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("题目预览")
                                .font(.headline)
                            
                            ProblemStatementView(problem: statement)
                                .frame(maxHeight: 400)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("题目解析调试")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func testParse() async {
        guard let cid = Int(contestId), !problemIndex.isEmpty else {
            result = "❌ 请输入有效的 Contest ID 和 Problem Index"
            return
        }
        
        isLoading = true
        result = "🔄 开始解析...\n"
        problemStatement = nil
        
        do {
            let statement = try await ProblemParser.fetchAndParse(
                contestId: cid,
                problemIndex: problemIndex
            )
            
            result += "✅ 解析成功！\n\n"
            result += "题目名称: \(statement.name)\n"
            result += "时间限制: \(statement.timeLimit)\n"
            result += "内存限制: \(statement.memoryLimit)\n"
            result += "输入: \(statement.inputFile)\n"
            result += "输出: \(statement.outputFile)\n"
            result += "题面段落: \(statement.statement.count) 个\n"
            result += "样例数量: \(statement.samples.count) 个\n"
            
            if !statement.samples.isEmpty {
                result += "\n样例预览:\n"
                for (idx, sample) in statement.samples.prefix(2).enumerated() {
                    result += "\n样例 \(idx + 1):\n"
                    result += "输入: \(sample.input.prefix(50))...\n"
                    result += "输出: \(sample.output.prefix(50))...\n"
                }
            }
            
            problemStatement = statement
            
        } catch let error as ParserError {
            result += "❌ 解析失败\n\n"
            result += "错误类型: \(error)\n"
            result += "错误描述: \(error.errorDescription ?? "未知错误")\n"
            result += "恢复建议: \(error.recoverySuggestion ?? "无")\n"
            
        } catch {
            result += "❌ 未知错误\n\n"
            result += "错误: \(error.localizedDescription)\n"
        }
        
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    ProblemDebugView()
}

