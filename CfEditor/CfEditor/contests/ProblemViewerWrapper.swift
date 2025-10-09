//
//  ProblemViewerWrapper.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import SwiftUI

// MARK: - Problem Viewer Wrapper

/// Problem viewer wrapper with native rendering
struct ProblemViewerWrapper: View {
    let problem: CFProblem
    
    @StateObject private var cache = ProblemCache.shared
    @State private var isLoading: Bool = false
    @State private var loadError: String? = nil
    @State private var problemStatement: ProblemStatement? = nil
    
    var body: some View {
        ZStack {
            // Content area
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading problem statement...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if let error = loadError {
                errorView(error)
            } else if let statement = problemStatement {
                ProblemStatementView(problem: statement, sourceProblem: problem)
            } else {
                Text("Unknown error")
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
            
            Text("Load Failed")
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
                Label("Retry", systemImage: "arrow.clockwise")
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
            loadError = "This problem is missing contest ID, cannot load statement"
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
                loadError = parserError.errorDescription ?? "Unknown error"
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
