//
//  FavoritesSheetView.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//  收藏题目展示的 Sheet 视图
//

import SwiftUI

struct FavoritesSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var favoritesManager: FavoritesManager
    @ObservedObject var problemsetStore: ProblemsetStore  // 用于获取通过人数数据
    @Binding var selectedProblem: CFProblem?  // 传递外层的导航绑定
    @State private var searchText: String = ""
    @State private var sortBy: SortOption = .dateAdded
    @State private var showingStats = false
    
    enum SortOption: String, CaseIterable {
        case dateAdded = "最近添加"
        case rating = "难度"
        case name = "名称"
    }
    
    private var filteredAndSortedFavorites: [FavoriteProblem] {
        var result = favoritesManager.favorites
        
        // 搜索过滤
        if !searchText.isEmpty {
            let search = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(search) ||
                $0.id.lowercased().contains(search) ||
                $0.tags.contains(where: { $0.lowercased().contains(search) })
            }
        }
        
        // 排序
        switch sortBy {
        case .dateAdded:
            result.sort { $0.addedAt > $1.addedAt }
        case .rating:
            result.sort { ($0.rating ?? 0) > ($1.rating ?? 0) }
        case .name:
            result.sort { $0.name < $1.name }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索和排序工具栏
                toolbarView
                
                Divider()
                
                // 收藏列表
                if favoritesManager.favorites.isEmpty {
                    emptyStateView
                } else if filteredAndSortedFavorites.isEmpty {
                    emptySearchView
                } else {
                    List {
                        ForEach(filteredAndSortedFavorites) { favorite in
                            Section {
                                favoriteRow(favorite)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                                    .listRowBackground(Color.clear)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button {
                                            withAnimation {
                                                favoritesManager.toggleFavorite(CFProblem(
                                                    contestId: favorite.contestId,
                                                    index: favorite.problemIndex,
                                                    name: favorite.name,
                                                    type: "PROGRAMMING",
                                                    rating: favorite.rating,
                                                    tags: favorite.tags
                                                ))
                                            }
                                            performLightHaptic()
                                        } label: {
                                            Label("取消收藏", systemImage: "star.slash")
                                        }
                                        .tint(.gray)
                                    }
                            }
                        }
                        
                        // 底部占位空间
                        Section {
                            Color.clear
                                .frame(height: 60)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets())
                        }
                    }
                    .listStyle(.plain)
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("收藏的题目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingStats = true }) {
                            Label("统计信息", systemImage: "chart.bar")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: clearAllFavorites) {
                            Label("清空收藏", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingStats) {
                statsView
            }
        }
    }
    
    // MARK: - 工具栏
    
    private var toolbarView: some View {
        VStack(spacing: 12) {
            // 搜索框
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                TextField("搜索题目、标签...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // 排序选项
            HStack {
                Text("排序:")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Picker("排序", selection: $sortBy) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                
                Spacer()
                
                Text("\(filteredAndSortedFavorites.count) 题")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .font(.system(size: 13))
        }
        .padding()
    }
    
    // MARK: - 收藏题目行
    
    private func favoriteRow(_ favorite: FavoriteProblem) -> some View {
        let problem = CFProblem(
            contestId: favorite.contestId,
            index: favorite.problemIndex,
            name: favorite.name,
            type: "PROGRAMMING",
            rating: favorite.rating,
            tags: favorite.tags
        )
        
        return Button {
            performLightHaptic()
            selectedProblem = problem
            dismiss()
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    // 状态图标区域 - 固定在最左侧
                    let problemStatus = problemsetStore.getProblemStatus(for: problem)
                    circledStatusIcon(for: problemStatus)
                        .frame(width: 24)
                    
                    // 题目信息区域
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("\(problem.contestId ?? 0)\(problem.index)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Text(removeProblemPrefix(from: problem.name))
                                .font(.system(size: 16, weight: .medium))
                                .lineLimit(2)
                                .foregroundColor(.primary)
                        }
                        
                        // 添加时间
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.7))
                            
                            Text(timeAgoString(from: favorite.addedAt))
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .padding(.top, 2)
                        
                        // 标签行
                        if shouldShowTags(for: problem, store: problemsetStore) {
                            ProblemTagsView(tags: problem.tags ?? [])
                                .padding(.top, 4)
                        }
                    }
                    
                    Spacer(minLength: 8)
                    
                    // 右侧评分和收藏区域
                    VStack(alignment: .trailing, spacing: 4) {
                        // 收藏图标
                        Image(systemName: favoritesManager.isFavorite(id: problem.id) ? "star.fill" : "star")
                            .font(.system(size: 16))
                            .foregroundColor(favoritesManager.isFavorite(id: problem.id) ? .yellow : .gray.opacity(0.3))
                        
                        // 评分（如果有定义）
                        if let rating = favorite.rating {
                            HStack(spacing: 4) {
                                Text("●")
                                    .font(.system(size: 10))
                                    .foregroundColor(colorForProblemRating(rating))
                                
                                Text("\(rating)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(colorForProblemRating(rating))
                            }
                        }
                        
                        // 通过人数（总是显示，如果有数据）
                        if let solvedCount = problemsetStore.problemStatistics[problem.id] {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.green.opacity(0.7))
                                
                                Text(formatSolvedCount(solvedCount))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(colorForProblemRating(problem.rating).opacity(0.2), lineWidth: 1)
                )
            }
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 空状态视图
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("还没有收藏题目")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primary)
            
            Text("在题目列表或题面页点击星星图标收藏题目")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptySearchView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("没有找到题目")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primary)
            
            Text("试试其他搜索词")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 统计视图
    
    private var statsView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    let stats = favoritesManager.getStats()
                    
                    // 顶部统计卡片
                    overviewCards(stats: stats)
                    
                    // 难度分布
                    if !stats.byRating.isEmpty {
                        ratingDistributionSection(stats: stats)
                    }
                    
                    // 标签分布（前10）
                    if !stats.byTag.isEmpty {
                        tagDistributionSection(stats: stats)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("统计信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showingStats = false
                    }
                }
            }
        }
    }
    
    // MARK: - 概览卡片组
    
    private func overviewCards(stats: FavoritesManager.Stats) -> some View {
        VStack(spacing: 12) {
            // 总收藏数大卡片
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("总收藏")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(stats.total)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("题")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 装饰性图标
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.yellow.opacity(0.2), .orange.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
            )
            
            // 次级统计卡片
            HStack(spacing: 12) {
                // 难度种类
                miniStatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .blue,
                    title: "难度种类",
                    value: "\(stats.byRating.count)",
                    gradientColors: [.blue, .cyan]
                )
                
                // 标签种类
                miniStatCard(
                    icon: "tag.fill",
                    iconColor: .purple,
                    title: "标签种类",
                    value: "\(stats.byTag.count)",
                    gradientColors: [.purple, .pink]
                )
            }
        }
    }
    
    private func miniStatCard(icon: String, iconColor: Color, title: String, value: String, gradientColors: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Spacer()
            }
            
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                    .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - 难度分布区域
    
    private func ratingDistributionSection(stats: FavoritesManager.Stats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text("难度分布")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Text("\(stats.byRating.count) 级")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // 难度列表
            VStack(spacing: 10) {
                ForEach(stats.byRating.sorted(by: { $0.key > $1.key }), id: \.key) { rating, count in
                    ratingRow(rating: rating, count: count, total: stats.total)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
    }
    
    private func ratingRow(rating: Int, count: Int, total: Int) -> some View {
        let percentage = total > 0 ? Double(count) / Double(total) : 0
        let color = ratingColor(rating)
        
        return VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                // 难度标签
                Text("\(rating)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 65)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                
                // 数量和百分比
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(count)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("题")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(String(format: "%.1f%%", percentage * 100))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
            }
            
            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 背景
                    Capsule()
                        .fill(color.opacity(0.1))
                        .frame(height: 8)
                    
                    // 进度
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * percentage, height: 8)
                        .shadow(color: color.opacity(0.3), radius: 3, x: 0, y: 1)
                }
            }
            .frame(height: 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.05))
        )
    }
    
    // MARK: - 标签分布区域
    
    private func tagDistributionSection(stats: FavoritesManager.Stats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "tag.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("热门标签")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Text("Top 10")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // 标签列表
            VStack(spacing: 8) {
                ForEach(Array(stats.byTag.sorted(by: { $0.value > $1.value }).prefix(10).enumerated()), id: \.offset) { index, element in
                    tagRow(rank: index + 1, tag: element.key, count: element.value, total: stats.total)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
    }
    
    private func tagRow(rank: Int, tag: String, count: Int, total: Int) -> some View {
        let percentage = total > 0 ? Double(count) / Double(total) : 0
        let rankColor = rankGradientColors(for: rank)
        
        return HStack(spacing: 12) {
            // 排名
            Text("\(rank)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: rankColor,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: rankColor[0].opacity(0.4), radius: 3, x: 0, y: 2)
                )
            
            // 标签名称
            VStack(alignment: .leading, spacing: 2) {
                Text(tag)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(String(format: "%.1f%%", percentage * 100))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            
            Spacer()
            
            // 数量
            HStack(spacing: 4) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
                
                Text("\(count)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("题")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [rankColor[0].opacity(0.05), rankColor[1].opacity(0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [rankColor[0].opacity(0.2), rankColor[1].opacity(0.2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - 辅助方法
    
    private func rankGradientColors(for rank: Int) -> [Color] {
        switch rank {
        case 1:
            return [.yellow, .orange]
        case 2:
            return [.gray, .gray.opacity(0.7)]
        case 3:
            return [.orange, .red]
        case 4...6:
            return [.blue, .cyan]
        default:
            return [.purple, .pink]
        }
    }
    
    // MARK: - 辅助方法
    
    private func colorForProblemRating(_ rating: Int?) -> Color {
        guard let r = rating else { return .secondary }
        return colorForRating(r)
    }
    
    private func formatSolvedCount(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        } else if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        } else {
            return "\(count)"
        }
    }
    
    private func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case ..<1200:
            return .gray
        case 1200..<1400:
            return .green
        case 1400..<1600:
            return Color.cyan
        case 1600..<1900:
            return .blue
        case 1900..<2100:
            return .purple
        case 2100..<2300:
            return .orange
        case 2300..<2400:
            return Color.orange
        case 2400..<2600:
            return .red
        default:
            return Color(red: 0.5, green: 0, blue: 0)  // 深红
        }
    }
    
    private func removeProblemPrefix(from name: String) -> String {
        // 移除题目名称开头的 "A. ", "B. ", "C. " 等前缀
        if let range = name.range(of: "^[A-Z][0-9]*\\. ", options: .regularExpression) {
            return String(name[range.upperBound...])
        }
        return name
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) 分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) 小时前"
        } else {
            let days = Int(interval / 86400)
            if days == 1 {
                return "昨天"
            } else if days < 7 {
                return "\(days) 天前"
            } else if days < 30 {
                let weeks = days / 7
                return "\(weeks) 周前"
            } else if days < 365 {
                let months = days / 30
                return "\(months) 个月前"
            } else {
                let years = days / 365
                return "\(years) 年前"
            }
        }
    }
    
    private func clearAllFavorites() {
        favoritesManager.clearAll()
    }
}


// MARK: - 预览

#Preview {
    FavoritesSheetView(
        favoritesManager: FavoritesManager.shared,
        problemsetStore: ProblemsetStore(),
        selectedProblem: .constant(nil)
    )
}




