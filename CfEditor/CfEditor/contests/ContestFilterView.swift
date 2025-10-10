//
//  ContestFilterView.swift
//  CfEditor
//
//  Created by AI Assistant on 2025/09/06.
//

import SwiftUI

// MARK: - 参与情况枚举
enum ParticipationStatus: String, CaseIterable, Identifiable {
    case participated = "Yes"
    case notParticipated = "No"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
}

// MARK: - 比赛过滤器数据模型
struct ContestFilter: Equatable {
    var searchText = ""
    var selectedDivisions: Set<ContestDivision> = Set(ContestDivision.allCases)
    var selectedParticipations: Set<ParticipationStatus> = Set(ParticipationStatus.allCases)
    var showOnlyParticipated: Bool = false
    var showOnlyRated: Bool = false
    var showOnlyUnrated: Bool = false
    var timeRange: ContestTimeRange = .all
    var sortOrder: ContestSortOrder = .newest
    
    var hasActiveFilters: Bool {
        return selectedDivisions != Set(ContestDivision.allCases) ||
               selectedParticipations != Set(ParticipationStatus.allCases) ||
               showOnlyParticipated ||
               showOnlyRated ||
               showOnlyUnrated ||
               timeRange != .all ||
               sortOrder != .newest
    }
    
    mutating func reset() {
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
        case .all: return "All"
        case .week: return "Last 7 days"
        case .month: return "Last 30 days"
        case .quarter: return "Last 3 months"
        case .year: return "Last 12 months"
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
        case .newest: return "Newest First"
        case .oldest: return "Oldest First"
        case .nameAsc: return "A to Z"
        case .nameDesc: return "Z to A"
        case .idAsc: return "ID(Ascending)"
        case .idDesc: return "ID(Descending)"
        }
    }
}

// MARK: - 比赛过滤器视图
struct ContestFilterView: View {
    @ObservedObject var store: ContestsStore
    @Environment(\.dismiss) private var dismiss
    
    // 使用临时状态，避免直接修改 store.filter 导致性能问题
    @State private var tempFilter: ContestFilter
    
    init(store: ContestsStore) {
        self.store = store
        self._tempFilter = State(initialValue: store.filter)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 比赛类型
                    FilterSection(
                        title: "Contest Type",
                        icon: "trophy.fill",
                        iconColor: .orange
                    ) {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(ContestDivision.allCases) { division in
                                DivisionToggleButton(
                                    division: division,
                                    isSelected: tempFilter.selectedDivisions.contains(division),
                                    action: {
                                        if tempFilter.selectedDivisions.contains(division) {
                                            tempFilter.selectedDivisions.remove(division)
                                        } else {
                                            tempFilter.selectedDivisions.insert(division)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    // 参与情况
                    FilterSection(
                        title: "Participation Status",
                        icon: "person.2.fill",
                        iconColor: .blue
                    ) {
                        HStack(spacing: 12) {
                            ForEach(ParticipationStatus.allCases) { participation in
                                ParticipationToggleButton(
                                    participation: participation,
                                    isSelected: tempFilter.selectedParticipations.contains(participation),
                                    action: {
                                        if tempFilter.selectedParticipations.contains(participation) {
                                            tempFilter.selectedParticipations.remove(participation)
                                        } else {
                                            tempFilter.selectedParticipations.insert(participation)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    // 时间范围
                    FilterSection(
                        title: "Time Range",
                        icon: "calendar",
                        iconColor: .green
                    ) {
                        VStack(spacing: 8) {
                            ForEach(ContestTimeRange.allCases) { range in
                                TimeRangeButton(
                                    range: range,
                                    isSelected: tempFilter.timeRange == range,
                                    action: {
                                        tempFilter.timeRange = range
                                    }
                                )
                            }
                        }
                    }
                    
                    // 排序方式
                    FilterSection(
                        title: "Sort By",
                        icon: "arrow.up.arrow.down",
                        iconColor: .purple
                    ) {
                        VStack(spacing: 8) {
                            ForEach(ContestSortOrder.allCases) { order in
                                SortOrderButton(
                                    order: order,
                                    isSelected: tempFilter.sortOrder == order,
                                    action: {
                                        tempFilter.sortOrder = order
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Contest Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        tempFilter.reset()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Reset")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(tempFilter.hasActiveFilters ? .red : .gray)
                    }
                    .disabled(!tempFilter.hasActiveFilters)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        applyFilter()
                    } label: {
                        Text("Apply")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.blue)
                            )
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func applyFilter() {
        // 应用过滤器到 store
        store.filter = tempFilter
        store.applyFilters()
        dismiss()
    }
}

// MARK: - 过滤器分组视图
private struct FilterSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Division 切换按钮
private struct DivisionToggleButton: View {
    let division: ContestDivision
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(isSelected ? division.color : Color.gray.opacity(0.2))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isSelected ? division.color : Color.gray.opacity(0.4),
                                lineWidth: isSelected ? 0 : 1
                            )
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(isSelected ? 1 : 0)
                    )
                
                Text(division.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? division.color : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? division.color.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isSelected ? division.color.opacity(0.5) : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Participation 切换按钮
private struct ParticipationToggleButton: View {
    let participation: ParticipationStatus
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? .blue : .gray)
                
                Text(participation.displayName)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isSelected ? Color.blue.opacity(0.5) : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Time Range 按钮
private struct TimeRangeButton: View {
    let range: ContestTimeRange
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(range.displayName)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.green : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sort Order 按钮
private struct SortOrderButton: View {
    let order: ContestSortOrder
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: iconForOrder(order))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .purple)
                    .frame(width: 20)
                
                Text(order.displayName)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.purple : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
    
    private func iconForOrder(_ order: ContestSortOrder) -> String {
        switch order {
        case .newest: return "arrow.down"
        case .oldest: return "arrow.up"
        case .nameAsc: return "textformat.abc"
        case .nameDesc: return "textformat.abc"
        case .idAsc: return "number"
        case .idDesc: return "number"
        }
    }
}

// MARK: - 预览
#Preview {
    ContestFilterView(store: ContestsStore())
}
