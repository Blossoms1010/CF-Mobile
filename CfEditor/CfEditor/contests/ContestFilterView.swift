//
//  ContestFilterView.swift
//  CfEditor
//
//  Created by AI Assistant on 2025/09/06.
//

import SwiftUI

// MARK: - 参与情况枚举
enum ParticipationStatus: String, CaseIterable, Identifiable {
    case participated = "参与"
    case notParticipated = "未参与"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
}

// MARK: - 比赛过滤器数据模型
class ContestFilter: ObservableObject {
    @Published var searchText = ""
    @Published var selectedDivisions: Set<ContestDivision> = Set(ContestDivision.allCases)
    @Published var selectedParticipations: Set<ParticipationStatus> = Set(ParticipationStatus.allCases)
    @Published var showOnlyParticipated: Bool = false
    @Published var showOnlyRated: Bool = false
    @Published var showOnlyUnrated: Bool = false
    @Published var timeRange: ContestTimeRange = .all
    @Published var sortOrder: ContestSortOrder = .newest
    
    var hasActiveFilters: Bool {
        return selectedDivisions != Set(ContestDivision.allCases) ||
               selectedParticipations != Set(ParticipationStatus.allCases) ||
               showOnlyParticipated ||
               showOnlyRated ||
               showOnlyUnrated ||
               timeRange != .all ||
               sortOrder != .newest
    }
    
    func reset() {
        selectedDivisions = Set(ContestDivision.allCases)
        selectedParticipations = Set(ParticipationStatus.allCases)
        showOnlyParticipated = false
        showOnlyRated = false
        showOnlyUnrated = false
        timeRange = .all
        sortOrder = .newest
    }
}

// MARK: - 比赛阶段枚举
enum ContestPhase: String, CaseIterable, Identifiable {
    case before = "BEFORE"
    case coding = "CODING"
    case pending = "PENDING_SYSTEM_TEST"
    case system = "SYSTEM_TEST"
    case finished = "FINISHED"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .before: return "即将开始"
        case .coding: return "进行中"
        case .pending: return "等待系统测试"
        case .system: return "系统测试中"
        case .finished: return "已结束"
        }
    }
    
    var color: Color {
        switch self {
        case .before: return .blue
        case .coding: return .green
        case .pending: return .orange
        case .system: return .yellow
        case .finished: return .gray
        }
    }
}

// MARK: - 比赛类型/难度枚举
enum ContestDivision: String, CaseIterable, Identifiable {
    case div1 = "Div1"
    case div2 = "Div2"
    case div3 = "Div3"
    case div4 = "Div4"
    case div1Plus2 = "Div 1 + 2"
    case educational = "Edu"
    case global = "Global"
    case other = "Other"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var color: Color {
        switch self {
        case .div1: return .red
        case .div2: return .blue
        case .div3: return .green
        case .div4: return .purple
        case .div1Plus2: return .indigo
        case .educational: return .orange
        case .global: return .pink
        case .other: return .gray
        }
    }
    
    static func from(contestName: String) -> ContestDivision {
        let name = contestName.lowercased()
        // Educational 检查要优先，因为有 "Educational Round rated for Div. 2" 这种情况
        if name.contains("educational") {
            return .educational
        } else if name.contains("div. 1") && name.contains("div. 2") {
            return .div1Plus2
        } else if name.contains("div. 1") || name.contains("division 1") {
            return .div1
        } else if name.contains("div. 2") || name.contains("division 2") {
            return .div2
        } else if name.contains("div. 3") || name.contains("division 3") {
            return .div3
        } else if name.contains("div. 4") || name.contains("division 4") {
            return .div4
        } else if name.contains("global") {
            return .global
        } else {
            return .other
        }
    }
}

// MARK: - 时间范围枚举
enum ContestTimeRange: String, CaseIterable, Identifiable {
    case all = "all"
    case week = "week"
    case month = "month"
    case quarter = "quarter"
    case year = "year"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .all: return "全部时间"
        case .week: return "最近一周"
        case .month: return "最近一月"
        case .quarter: return "最近三月"
        case .year: return "最近一年"
        }
    }
    
    var dateRange: DateInterval? {
        let now = Date()
        let calendar = Calendar.current
        
        switch self {
        case .all:
            return nil
        case .week:
            let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            return DateInterval(start: weekAgo, end: now)
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return DateInterval(start: monthAgo, end: now)
        case .quarter:
            let quarterAgo = calendar.date(byAdding: .month, value: -3, to: now)!
            return DateInterval(start: quarterAgo, end: now)
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            return DateInterval(start: yearAgo, end: now)
        }
    }
}

// MARK: - 排序方式枚举
enum ContestSortOrder: String, CaseIterable, Identifiable {
    case newest = "newest"
    case oldest = "oldest"
    case nameAsc = "nameAsc"
    case nameDesc = "nameDesc"
    case idAsc = "idAsc"
    case idDesc = "idDesc"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .newest: return "最新在前"
        case .oldest: return "最旧在前"
        case .nameAsc: return "名称升序"
        case .nameDesc: return "名称降序"
        case .idAsc: return "ID升序"
        case .idDesc: return "ID降序"
        }
    }
}

// MARK: - 比赛过滤器视图
struct ContestFilterView: View {
    @ObservedObject var store: ContestsStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // 比赛类型
                Section("比赛类型") {
                    ForEach(ContestDivision.allCases) { division in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { store.filter.selectedDivisions.contains(division) },
                                set: { isSelected in
                                    if isSelected {
                                        store.filter.selectedDivisions.insert(division)
                                    } else {
                                        store.filter.selectedDivisions.remove(division)
                                    }
                                }
                            )) {
                                HStack(spacing: 8) {
                                    Rectangle()
                                        .fill(division.color)
                                        .frame(width: 12, height: 12)
                                        .cornerRadius(2)
                                    Text(division.displayName)
                                }
                            }
                        }
                    }
                }
                
                // 参与情况
                Section("参与情况") {
                    ForEach(ParticipationStatus.allCases) { participation in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { store.filter.selectedParticipations.contains(participation) },
                                set: { isSelected in
                                    if isSelected {
                                        store.filter.selectedParticipations.insert(participation)
                                    } else {
                                        store.filter.selectedParticipations.remove(participation)
                                    }
                                }
                            )) {
                                Text(participation.displayName)
                            }
                        }
                    }
                }
                
                // 时间范围
                Section("时间范围") {
                    Picker("时间范围", selection: $store.filter.timeRange) {
                        ForEach(ContestTimeRange.allCases) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // 排序方式
                Section("排序方式") {
                    Picker("排序", selection: $store.filter.sortOrder) {
                        ForEach(ContestSortOrder.allCases) { order in
                            Text(order.displayName).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("比赛过滤")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("重置") {
                        store.filter.reset()
                    }
                    .disabled(!store.filter.hasActiveFilters)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        store.applyFilters()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - 预览
#Preview {
    ContestFilterView(store: ContestsStore())
}
