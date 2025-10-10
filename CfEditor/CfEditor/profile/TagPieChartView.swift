//
//  TagPieChartView.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import SwiftUI
import Charts

struct TagPieChartView: View {
    let tagSlices: [TagSlice]
    let loading: Bool
    @Binding var selectedTag: String?
    @Binding var isLegendExpanded: Bool
    
    private var tagSlicesNZ: [TagSlice] {
        tagSlices.filter { $0.count > 0 }
    }
    
    private var tagColorMapComputed: [String: Color] {
        tagColorMapping(for: tagSlicesNZ.map(\.tag))
    }
    
    private var tagDomain: [String] {
        tagSlicesNZ.map(\.tag)
    }
    
    private var tagRange: [Color] {
        tagDomain.map { tagColorMapComputed[$0] ?? .accentColor }
    }
    
    private var tagCountsByTag: [String: Int] {
        Dictionary(uniqueKeysWithValues: tagSlicesNZ.map { ($0.tag, $0.count) })
    }
    
    private var tagTotalCount: Int {
        max(1, tagSlicesNZ.reduce(0) { $0 + $1.count })
    }
    
    private var tagLegendsToShow: [String] {
        if isLegendExpanded || tagDomain.count <= 6 {
            return tagDomain
        } else {
            return Array(tagDomain.prefix(6))
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 顶部：扇形图
            tagPieChartView
                .frame(height: 200)
                .padding(.horizontal, 20)
                .opacity(loading ? 0 : 1)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: tagTotalCount)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: tagSlicesNZ.count)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedTag)
                .animation(.easeOut(duration: 0.30), value: loading)

            Divider().padding(.horizontal, 8)

            // 底部：图例区域
            VStack(spacing: 12) {
                let columns = [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ]
                
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(tagLegendsToShow, id: \.self) { tag in
                        tagLegendItem(tag: tag)
                    }
                }
                .padding(.horizontal, 12)
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: isLegendExpanded)
                
                if tagDomain.count > 6 {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            isLegendExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(isLegendExpanded ? "收起" : "展开全部 (\(tagDomain.count))")
                                .font(.caption)
                                .fontWeight(.medium)
                            Image(systemName: isLegendExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray6))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
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
    
    @ViewBuilder
    private var tagPieChartView: some View {
        if #available(iOS 17.0, *) {
            tagPieChart
        } else {
            tagBarChart
        }
    }
    
    @available(iOS 17.0, *)
    @ViewBuilder
    private var tagPieChart: some View {
        ZStack {
            Chart(tagSlicesNZ) { s in
                tagSectorMark(for: s)
            }
            .chartForegroundStyleScale(domain: tagDomain, range: tagRange)
            .chartLegend(.hidden)
            
            if let selected = selectedTag,
               let slice = tagSlicesNZ.first(where: { $0.tag == selected }) {
                VStack(spacing: 4) {
                    Text(selected)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("\(slice.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(tagColorMapComputed[selected] ?? .accentColor)
                    Text(tagPercentString(for: slice.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    @available(iOS 17.0, *)
    @ChartContentBuilder
    private func tagSectorMark(for slice: TagSlice) -> some ChartContent {
        let isSelected = selectedTag == slice.tag
        let outerRadius: MarkDimension = isSelected ? .ratio(1.04) : .ratio(1.0)
        
        return SectorMark(
            angle: .value("Count", slice.count),
            innerRadius: .ratio(0.50),
            outerRadius: outerRadius,
            angularInset: 1.5
        )
        .foregroundStyle(by: .value("Tag", slice.tag))
        .opacity(selectedTag == nil || isSelected ? 1.0 : 0.3)
        .cornerRadius(3.0)
    }
    
    @ViewBuilder
    private var tagBarChart: some View {
        Chart(tagSlicesNZ) { s in
            BarMark(
                x: .value("数量", s.count),
                y: .value("标签", s.tag)
            )
            .foregroundStyle(by: .value("Tag", s.tag))
            .opacity(selectedTag == nil || selectedTag == s.tag ? 1.0 : 0.3)
            .cornerRadius(3)
        }
        .chartForegroundStyleScale(domain: tagDomain, range: tagRange)
        .chartLegend(.hidden)
    }
    
    @ViewBuilder
    private func tagLegendItem(tag: String) -> some View {
        let isSelected = selectedTag == tag
        
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(tagColorMapComputed[tag] ?? .accentColor)
                    .frame(width: 8, height: 8)
                
                Text(tag)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            HStack(spacing: 3) {
                Text("\(tagCountsByTag[tag] ?? 0)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(tagPercentString(for: (tagCountsByTag[tag] ?? 0)))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((tagColorMapComputed[tag] ?? .accentColor).opacity(isSelected ? 0.2 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke((tagColorMapComputed[tag] ?? .accentColor).opacity(isSelected ? 0.6 : 0.2), lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                if selectedTag == tag {
                    selectedTag = nil
                } else {
                    selectedTag = tag
                }
            }
        }
    }
    
    private func tagPercentString(for count: Int) -> String {
        String(format: "%.1f%%", Double(count) * 100.0 / Double(tagTotalCount))
    }
    
    private func tagColorMapping(for tags: [String]) -> [String: Color] {
        var map: [String: Color] = ["Others": .secondary]
        let hues: [Double] = [0.00, 0.08, 0.16, 0.22, 0.30, 0.36, 0.44, 0.52, 0.60, 0.68, 0.76, 0.82, 0.90, 0.96, 0.12, 0.48]
        var i = 0
        for t in tags where t != "Others" {
            let h = hues[i % hues.count]
            map[t] = Color(hue: h, saturation: 0.78, brightness: 0.92)
            i += 1
        }
        return map
    }
}

