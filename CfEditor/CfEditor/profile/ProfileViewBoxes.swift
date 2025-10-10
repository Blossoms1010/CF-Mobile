//
//  ProfileViewBoxes.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import SwiftUI
import Charts

// MARK: - ProfileView Box Extensions

extension ProfileView {
    
    // MARK: - Rating Chart Box
    
    @ViewBuilder
    var ratingChartBox: some View {
        RatingChartView(ratings: ratings, loading: loading)
    }
    
    // MARK: - 热力图
    
    @ViewBuilder
    var heatmapBox: some View {
        if let heatmapData {
            HeatmapView(
                data: heatmapData,
                availableYears: availableYears,
                selectedOption: selectedHeatmapOption,
                onSelectionChange: { selection in
                    selectedHeatmapOption = selection
                    updateHeatmapData()
                }
            )
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
            .opacity(loading ? 0 : 1)
            .animation(.easeOut(duration: 0.30), value: loading)
        } else {
            SkeletonChartBlock(height: 150)
        }
    }
    
    // 计算可用的年份列表
    var availableYears: [Int] {
        guard !allSubmissions.isEmpty else {
            return [Calendar.current.component(.year, from: Date())]
        }
        
        let years = Set(allSubmissions.map { submission in
            let date = Date(timeIntervalSince1970: TimeInterval(submission.creationTimeSeconds))
            return Calendar.current.component(.year, from: date)
        })
        
        return Array(years).sorted(by: >)
    }
    
    // MARK: - 练习柱状图
    
    private var practiceBarWidth: CGFloat { 10 }
    
    private var importantTickKeys: [String] {
        let maxRated = practiceBuckets.compactMap { $0.ratingFloor }.max() ?? 2600
        var ticks: [String] = []
        var x = 800
        while x <= maxRated {
            ticks.append("\(x)")
            x += 300
        }
        return ticks
    }
    
    private var practiceChartMinWidth: CGFloat {
        CGFloat(practiceBuckets.count) * 16.0 + 32.0
    }
    
    @ViewBuilder
    var practiceHistogramBox: some View {
        if practiceBuckets.isEmpty {
            if loading {
                SkeletonChartBlock(height: 220)
            } else {
                Text("暂无可统计的练习数据")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 220)
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                Chart(practiceBuckets) { b in
                    BarMark(
                        x: .value("难度", b.key),
                        y: .value("数量", b.count),
                        width: .fixed(practiceBarWidth)
                    )
                    .foregroundStyle(
                        b.ratingFloor == nil ? Color.secondary : colorForRating((b.ratingFloor ?? 800) + 1)
                    )
                    .cornerRadius(2)
                }
                .chartXScale(domain: practiceBuckets.map(\.key))
                .chartXAxis {
                    AxisMarks(values: importantTickKeys) { v in
                        AxisGridLine()
                        AxisTick()
                        if let label = v.as(String.self) {
                            AxisValueLabel(centered: true) {
                                Text(label)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.4)
                            }
                        }
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(minWidth: practiceChartMinWidth, alignment: .leading)
                .frame(height: 230)
                .padding(12)
                .opacity(loading ? 0 : 1)
                .animation(.easeOut(duration: 0.35), value: practiceBuckets.map(\.count).reduce(0, +))
                .animation(.easeOut(duration: 0.30), value: loading)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        }
    }
    
    // MARK: - 标签饼图
    
    @ViewBuilder
    var tagPieBox: some View {
        if tagSlices.isEmpty {
            if loading {
                SkeletonChartBlock(height: 240)
            } else {
                Text("暂无可统计的标签数据")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 240)
            }
        } else {
            TagPieChartView(
                tagSlices: tagSlices,
                loading: loading,
                selectedTag: $selectedTag,
                isLegendExpanded: $isTagLegendExpanded
            )
        }
    }
    
    // MARK: - 比赛记录
    
    @ViewBuilder
    var contestHistoryBox: some View {
        if loading {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.18))
                        .frame(height: 60)
                        .shimmer()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        } else if recentContests.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "trophy")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("暂无比赛记录")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        } else {
            VStack(spacing: 0) {
                let displayContests = Array(recentContests.prefix(maxRecentContestsToShow))
                ForEach(Array(displayContests.enumerated()), id: \.element.id) { index, contest in
                    ContestRecordRow(contest: contest)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    
                    if index < displayContests.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
                
                Button {
                    showAllContestsSheet = true
                } label: {
                    HStack {
                        Spacer()
                        Label("查看全部", systemImage: "list.bullet")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6).opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        }
    }
    
    // MARK: - 最近提交
    
    @ViewBuilder
    var recentSubmissionsBox: some View {
        if loading {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.18))
                        .frame(height: 44)
                        .shimmer()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        } else if recentSubmissions.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("暂无提交记录")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        } else {
            VStack(spacing: 0) {
                let displaySubmissions = Array(recentSubmissions.prefix(maxRecentSubmissionsToShow))
                ForEach(Array(displaySubmissions.enumerated()), id: \.element.id) { index, s in
                    RecentSubmissionRow(submission: s)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    
                    if index < displaySubmissions.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
                
                Button {
                    showAllSubmissionsSheet = true
                } label: {
                    HStack {
                        Spacer()
                        Label("查看全部", systemImage: "list.bullet")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6).opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        }
    }
}

