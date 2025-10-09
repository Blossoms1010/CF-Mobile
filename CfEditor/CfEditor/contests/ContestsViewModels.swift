//
//  ContestsViewModels.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import Foundation

// MARK: - 练习页面模式

enum PracticeMode: String, CaseIterable {
    case contests = "Contests"
    case problemset = "Problems"
}

// MARK: - 翻译数据模型

struct TranslationSegment: Codable, Identifiable {
    let id: UUID
    let original: String
    let translated: String
    
    init(original: String, translated: String) {
        self.id = UUID()
        self.original = original
        self.translated = translated
    }
}

// 题目部分类型
enum ProblemSection: String, CaseIterable, Codable {
    case legend = "Legend"
    case input = "Input"
    case output = "Output"
    case note = "Note"
    case interaction = "Interaction"
    case hack = "Hack"
    case tutorial = "Tutorial"
    
    var displayName: String {
        switch self {
        case .legend: return "题目描述"
        case .input: return "输入"
        case .output: return "输出"
        case .note: return "注意事项"
        case .interaction: return "交互"
        case .hack: return "Hack"
        case .tutorial: return "题解"
        }
    }
    
    var icon: String {
        switch self {
        case .legend: return "doc.text"
        case .input: return "square.and.arrow.down"
        case .output: return "square.and.arrow.up"
        case .note: return "exclamationmark.triangle"
        case .interaction: return "person.2.circle"
        case .hack: return "hammer"
        case .tutorial: return "lightbulb"
        }
    }
}

// 按部分组织的翻译内容
struct SectionTranslation: Codable, Identifiable {
    let id: UUID
    let section: ProblemSection
    let segments: [TranslationSegment]
    
    init(section: ProblemSection, segments: [TranslationSegment]) {
        self.id = UUID()
        self.section = section
        self.segments = segments
    }
}

