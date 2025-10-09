import SwiftUI

// MARK: - 热力图视图
struct HeatmapView: View {
    let data: HeatmapData
    let availableYears: [Int]
    let selectedOption: YearSelection
    let onSelectionChange: (YearSelection) -> Void
    
    @State private var colorMode: HeatmapColorMode = .ratingBased

    private let cell: CGFloat = 10
    private let gap: CGFloat  = 1.5
    private let leftAxisWidth: CGFloat = 28
    private let topGap: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 顶部控制栏：着色模式切换 + 年份选择器
            HStack {
                // 左侧：着色模式切换器
                colorModeToggle
                
                Spacer()
                
                // 右侧：年份选择器
                yearSelector
            }
            
            // 热力图本体
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: topGap) {

                        // 顶部月份
                        HStack(spacing: gap) {
                            Spacer().frame(width: leftAxisWidth)
                            ForEach(data.weeks.indices, id: \.self) { w in
                                Text(data.monthLabels[w] ?? "")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.2)
                                    .frame(width: cell, alignment: .leading)
                            }
                        }

                        // 主体
                        HStack(alignment: .top, spacing: 6) {
                            // 左侧星期
                            VStack(alignment: .trailing, spacing: gap) {
                                ForEach(0..<7, id: \.self) { r in
                                    Text(weekdayLabel(forRow: r))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: leftAxisWidth, height: cell, alignment: .trailing)
                                }
                            }
                            // 网格
                            HStack(spacing: gap) {
                                ForEach(data.weeks.indices, id: \.self) { w in
                                    VStack(spacing: gap) {
                                        ForEach(0..<7, id: \.self) { r in
                                            let day = Calendar.current.startOfDay(for: data.weeks[w][r])
                                            let today = Calendar.current.startOfDay(for: Date())
                                            
                                            // 根据视图类型确定是否显示
                                            let shouldShow: Bool = {
                                                switch data.viewType {
                                                case .year(let year):
                                                    let dateYear = Calendar.current.component(.year, from: day)
                                                    // 显示属于指定年份的所有日期
                                                    return dateYear == year
                                                case .rolling365:
                                                    // 365天视图：只显示365天范围内的日期
                                                    let startDate = Calendar.current.date(byAdding: .day, value: -364, to: today)!
                                                    return day >= startDate && day <= today
                                                }
                                            }()
                                            
                                            // 确定颜色：根据着色模式选择
                                            let color: Color = {
                                                if !shouldShow {
                                                    return Color.clear
                                                }
                                                
                                                switch colorMode {
                                                case .ratingBased:
                                                    // Rating-based 模式：使用预计算的颜色
                                                    return data.dailyColors[day] ?? Color(.systemGray6)
                                                    
                                                case .normal:
                                                    // Normal 模式：基于提交数量和AC数量的绿色渐变
                                                    let submissionCount = data.dailySubmissions[day] ?? 0
                                                    let acCount = data.dailyAccepted[day] ?? 0
                                                    return colorForGitHubStyle(submissionCount: submissionCount, acCount: acCount)
                                                }
                                            }()
                                            
                                            RoundedRectangle(cornerRadius: 2.0)
                                                .fill(color)
                                                .frame(width: cell, height: cell)
                                                .opacity(shouldShow ? 1.0 : 0.0)
                                        }
                                    }
                                    .id(w)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onAppear {
                    let last = max(0, data.weeks.count - 1)
                    DispatchQueue.main.async {
                        proxy.scrollTo(last, anchor: .trailing)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var colorModeToggle: some View {
        Menu {
            Button {
                colorMode = .ratingBased
            } label: {
                HStack {
                    Text("Rating-based")
                    Spacer()
                    if colorMode == .ratingBased {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Button {
                colorMode = .normal
            } label: {
                HStack {
                    Text("Normal")
                    Spacer()
                    if colorMode == .normal {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: colorMode == .ratingBased ? "paintpalette.fill" : "square.fill")
                    .font(.caption)
                    .foregroundStyle(colorMode == .ratingBased ? .purple : .green)
                Text(colorMode == .ratingBased ? "Rating-based" : "Normal")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                LinearGradient(
                    colors: colorMode == .ratingBased 
                        ? [Color.purple.opacity(0.08), Color.pink.opacity(0.08)]
                        : [Color.green.opacity(0.08), Color.mint.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        colorMode == .ratingBased 
                            ? Color.purple.opacity(0.2) 
                            : Color.green.opacity(0.2), 
                        lineWidth: 1
                    )
            )
        }
        .foregroundStyle(.primary)
        .menuStyle(.automatic)
    }
    
    @ViewBuilder
    private var yearSelector: some View {
        Menu {
            // All选项（带图标和checkmark）
            Button {
                onSelectionChange(.all)
            } label: {
                Label {
                    Text("All")
                } icon: {
                    if case .all = selectedOption {
                        Image(systemName: "checkmark")
                    } else {
                        Image(systemName: "calendar")
                    }
                }
            }
            
            Divider()
            
            // 年份选项 - 使用 ScrollView 确保所有年份都可见
            Section {
                ForEach(availableYears, id: \.self) { year in
                    Button {
                        onSelectionChange(.year(year))
                    } label: {
                        HStack {
                            Text("\(year)")
                            Spacer()
                            if case .year(let selectedYear) = selectedOption, selectedYear == year {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text(data.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.08), Color.cyan.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
        .foregroundStyle(.primary)
        .menuStyle(.automatic)
    }

    private func weekdayLabel(forRow r: Int) -> String {
        switch r {
        case 0: return "Mon"
        case 2: return "Wed"
        case 4: return "Fri"
        default: return ""
        }
    }
}

