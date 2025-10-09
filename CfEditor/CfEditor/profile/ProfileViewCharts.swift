//
//  ProfileViewCharts.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import SwiftUI
import Charts

// MARK: - Rating Chart Component

struct RatingChartView: View {
    let ratings: [CFRatingUpdate]
    let loading: Bool
    
    private let darkRed = Color(red: 0.7, green: 0, blue: 0)
    private let deepRed = Color(red: 0.54, green: 0, blue: 0)
    private let cfYellow = Color(red: 1.0, green: 0.8, blue: 0.0)
    
    private var ratingTiers: [(name: String, range: ClosedRange<Int>, color: Color)] {
        [
            ("Newbie", 0...1199, .gray),
            ("Pupil", 1200...1399, .green),
            ("Specialist", 1400...1599, .cyan),
            ("Expert", 1600...1899, .blue),
            ("Candidate Master", 1900...2099, .purple),
            ("Master", 2100...2299, .yellow),
            ("International Master", 2300...2399, .orange),
            ("Grandmaster", 2400...2599, .red),
            ("International Grandmaster", 2600...2999, darkRed),
            ("Legendary Grandmaster", 3000...4999, deepRed)
        ]
    }
    
    private var yAxisDomain: ClosedRange<Int> {
        guard !ratings.isEmpty else { return 1000...2000 }
        let allRatings = ratings.flatMap { [$0.oldRating, $0.newRating] }
        let minRating = allRatings.min() ?? 1200
        let maxRating = allRatings.max() ?? 1600
        
        let dataRange = maxRating - minRating
        let bottomPadding = max(10, min(80, dataRange / 10))
        let topPadding = max(10, min(80, dataRange / 10))
        
        let lowerBound = max(0, minRating - bottomPadding)
        let upperBound = maxRating + topPadding
        return lowerBound...upperBound
    }
    
    private var intelligentlyFilteredBoundaries: [Int] {
        let visibleBoundaries = ratingTiers.map { $0.range.lowerBound }.filter { yAxisDomain.contains($0) && $0 > 0 }
        guard !visibleBoundaries.isEmpty else { return [] }
        
        var finalBoundaries: [Int] = []
        var lastAddedBoundary = -1000
        let minSeparation = 150
        
        for boundary in visibleBoundaries {
            if boundary - lastAddedBoundary >= minSeparation {
                finalBoundaries.append(boundary)
                lastAddedBoundary = boundary
            }
        }
        return finalBoundaries
    }
    
    var body: some View {
        if ratings.isEmpty {
            if loading {
                SkeletonChartBlock(height: 260)
            } else {
                emptyStateView
            }
        } else {
            Chart {
                backgroundMarks
                seriesMarks
            }
            .chartYScale(domain: yAxisDomain)
            .chartYAxis { AxisMarks(position: .leading, values: intelligentlyFilteredBoundaries) }
            .chartXAxis {
                AxisMarks(preset: .automatic, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(); AxisTick()
                    if value.as(Date.self) != nil {
                        let timeSpan = (ratings.last?.date.timeIntervalSince1970 ?? 0) - (ratings.first?.date.timeIntervalSince1970 ?? 0)
                        let twoYears: TimeInterval = 2 * 365 * 24 * 60 * 60
                        let format = timeSpan > twoYears ? Date.FormatStyle.dateTime.year() : Date.FormatStyle.dateTime.month(.abbreviated)
                        AxisValueLabel(format: format, centered: true)
                    }
                }
            }
            .frame(height: 260)
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
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("暂无 rating 数据")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
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
    
    @ChartContentBuilder
    private var backgroundMarks: some ChartContent {
        ForEach(ratingTiers, id: \.name) { tier in
            if let firstDate = ratings.first?.date, let lastDate = ratings.last?.date {
                let viewDomain = yAxisDomain
                let tierDomain = tier.range
                let visibleStartY = max(viewDomain.lowerBound, tierDomain.lowerBound)
                let visibleEndY = min(viewDomain.upperBound, tierDomain.upperBound)
                
                if visibleEndY >= visibleStartY {
                    RectangleMark(
                        xStart: .value("Start Time", firstDate),
                        xEnd: .value("End Time", lastDate),
                        yStart: .value("Bottom Rating", visibleStartY),
                        yEnd: .value("Top Rating", visibleEndY + 1)
                    )
                    .foregroundStyle(tier.color.opacity(0.7))
                }
            }
        }
    }
    
    @ChartContentBuilder
    private var seriesMarks: some ChartContent {
        ForEach(ratings) { rating in
            LineMark(
                x: .value("Date", rating.date),
                y: .value("Rating", rating.newRating)
            )
        }
        .interpolationMethod(.catmullRom)
        .foregroundStyle(cfYellow)
        .lineStyle(StrokeStyle(lineWidth: 1.5))
        
        ForEach(ratings) { r in
            PointMark(
                x: .value("时间", r.date),
                y: .value("Rating", r.newRating)
            )
            .symbolSize(10)
            .foregroundStyle(cfYellow)
        }
    }
}

