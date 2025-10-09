//
//  ProblemViewerWrapper.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import SwiftUI

// MARK: - Problem Viewer Wrapper

/// 题目查看器包装，原生渲染
struct ProblemViewerWrapper: View {
    let problem: CFProblem
    
    @StateObject private var cache = ProblemCache.shared
    @State private var isLoading: Bool = false
    @State private var loadError: String? = nil
    @State private var problemStatement: ProblemStatement? = nil
    
    var body: some View {
        ZStack {
            // 内容区域
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("正在加载题面...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if let error = loadError {
                errorView(error)
            } else if let statement = problemStatement {
                ProblemStatementView(problem: statement, sourceProblem: problem)
            } else {
                Text("未知错误")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(problem.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if problemStatement != nil {
                    Button {
                        Task {
                            await loadProblemStatement(forceRefresh: true)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await loadProblemStatement()
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("加载失败")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                Task {
                    await loadProblemStatement(forceRefresh: true)
                }
            } label: {
                Label("重试", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func loadProblemStatement(forceRefresh: Bool = false) async {
        guard let contestId = problem.contestId else {
            loadError = "该题目缺少比赛 ID，无法加载题面"
            return
        }
        
        isLoading = true
        loadError = nil
        
        do {
            problemStatement = try await cache.getProblem(
                contestId: contestId,
                problemIndex: problem.index,
                tags: problem.tags,
                forceRefresh: forceRefresh
            )
            isLoading = false
            
        } catch {
            isLoading = false
            
            if let parserError = error as? ParserError {
                loadError = parserError.errorDescription ?? "未知错误"
            } else {
                loadError = error.localizedDescription
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProblemViewerWrapper(problem: CFProblem(
            contestId: 2042,
            index: "A",
            name: "Greedy Monocarp",
            type: "PROGRAMMING",
            rating: 800,
            tags: ["greedy", "math"]
        ))
    }
}
