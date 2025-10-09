//
//  ProblemStatement.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import Foundation

// MARK: - Problem Statement Data Model

/// 表示题面的完整数据结构
struct ProblemStatement: Codable, Identifiable {
    let id: String // contestId-problemIndex，例如 "2042-A"
    let contestId: Int
    let problemIndex: String
    let name: String
    let timeLimit: String
    let memoryLimit: String
    let inputFile: String
    let outputFile: String
    
    // 题面各个部分的内容
    let statement: [ContentElement]
    let inputSpecification: [ContentElement]
    let outputSpecification: [ContentElement]
    let samples: [TestSample]
    let note: [ContentElement]?
    
    // 元数据
    let cachedAt: Date
    let sourceURL: String
    let rawHTML: String?  // 🔍 调试用：存储原始 HTML
    
    init(contestId: Int, problemIndex: String, name: String, timeLimit: String, memoryLimit: String, inputFile: String, outputFile: String, statement: [ContentElement], inputSpecification: [ContentElement], outputSpecification: [ContentElement], samples: [TestSample], note: [ContentElement]?, sourceURL: String, rawHTML: String? = nil) {
        self.id = "\(contestId)-\(problemIndex)"
        self.contestId = contestId
        self.problemIndex = problemIndex
        self.name = name
        self.timeLimit = timeLimit
        self.memoryLimit = memoryLimit
        self.inputFile = inputFile
        self.outputFile = outputFile
        self.statement = statement
        self.inputSpecification = inputSpecification
        self.outputSpecification = outputSpecification
        self.samples = samples
        self.note = note
        self.cachedAt = Date()
        self.sourceURL = sourceURL
        self.rawHTML = rawHTML
    }
}

// MARK: - Content Element

/// 表示题面中的内容元素（文本、公式、图片等）
enum ContentElement: Codable, Equatable, Identifiable {
    case text(String)
    case inlineLatex(String)   // 行内公式 $...$
    case blockLatex(String)    // 块级公式 $$...$$
    case image(String) // URL string
    case list([String])
    case code(String)
    case paragraph([ContentElement])
    
    var id: String {
        switch self {
        case .text(let content): return "text-\(content.prefix(20).hashValue)"
        case .inlineLatex(let formula): return "inline-latex-\(formula.hashValue)"
        case .blockLatex(let formula): return "block-latex-\(formula.hashValue)"
        case .image(let url): return "image-\(url.hashValue)"
        case .list(let items): return "list-\(items.joined().hashValue)"
        case .code(let code): return "code-\(code.hashValue)"
        case .paragraph(let elements): return "paragraph-\(elements.count)-\(elements.first?.id ?? "empty")"
        }
    }
}

// MARK: - Test Sample

/// 表示一个测试样例
struct TestSample: Codable, Identifiable {
    let id: String
    let input: String
    let output: String
    let inputLineGroups: [Int]?  // 每行所属的组号（从 Codeforces HTML 提取）
    let outputLineGroups: [Int]? // 输出每行的组号
    
    init(id: Int, input: String, output: String, inputLineGroups: [Int]? = nil, outputLineGroups: [Int]? = nil) {
        self.id = "sample-\(id)"
        self.input = input
        self.output = output
        self.inputLineGroups = inputLineGroups
        self.outputLineGroups = outputLineGroups
    }
}

// MARK: - Problem Preview (轻量级版本)

/// 题目预览信息（用于列表显示）
struct ProblemPreview: Codable, Identifiable {
    let id: String
    let contestId: Int
    let problemIndex: String
    let name: String
    let tags: [String]
    let rating: Int?
    let isCached: Bool
    
    init(contestId: Int, problemIndex: String, name: String, tags: [String] = [], rating: Int? = nil, isCached: Bool = false) {
        self.id = "\(contestId)-\(problemIndex)"
        self.contestId = contestId
        self.problemIndex = problemIndex
        self.name = name
        self.tags = tags
        self.rating = rating
        self.isCached = isCached
    }
}

