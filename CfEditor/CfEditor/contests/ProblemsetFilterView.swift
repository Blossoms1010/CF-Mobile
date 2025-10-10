import SwiftUI

struct ProblemsetFilterView: View {
    @ObservedObject var store: ProblemsetStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempFilter: ProblemsetFilter
    
    init(store: ProblemsetStore) {
        self.store = store
        self._tempFilter = State(initialValue: store.filter)
    }
    
    private var isFilterInvalid: Bool {
        if let minRating = tempFilter.minRating,
           let maxRating = tempFilter.maxRating {
            return maxRating < minRating
        }
        return false
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 难度范围
                    ProblemFilterSection(
                        title: "Difficulty Range",
                        icon: "chart.bar.fill",
                        iconColor: .orange
                    ) {
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                // 最小难度
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.green)
                                        Text("Min")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Menu {
                                        Button("Any") {
                                            tempFilter.minRating = nil
                                        }
                                        ForEach(Array(stride(from: 800, through: 3500, by: 100)), id: \.self) { rating in
                                            Button("\(rating)") {
                                                tempFilter.minRating = rating
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(tempFilter.minRating.map { "\($0)" } ?? "Any")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(.systemGray6))
                                        )
                                    }
                                }
                                
                                // 箭头
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 24)
                                
                                // 最大难度
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.red)
                                        Text("Max")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Menu {
                                        Button("Any") {
                                            tempFilter.maxRating = nil
                                        }
                                        ForEach(Array(stride(from: 800, through: 3500, by: 100)), id: \.self) { rating in
                                            Button("\(rating)") {
                                                tempFilter.maxRating = rating
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(tempFilter.maxRating.map { "\($0)" } ?? "Any")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(.systemGray6))
                                        )
                                    }
                                }
                            }
                            
                            // 验证错误提示
                            if isFilterInvalid {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.orange)
                                    Text("Max difficulty cannot be less than min")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.orange.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                    
                    // 显示选项
                    ProblemFilterSection(
                        title: "Display Options",
                        icon: "eye.fill",
                        iconColor: .blue
                    ) {
                        VStack(spacing: 12) {
                            OptionToggleRow(
                                icon: "checkmark.circle.fill",
                                title: "Hide solved problems",
                                isOn: $tempFilter.hideSolved,
                                color: .green
                            )
                            
                            OptionToggleRow(
                                icon: "tag.fill",
                                title: "Show tags on unsolved problems",
                                isOn: $tempFilter.showUnsolvedTags,
                                color: .purple
                            )
                        }
                    }
                    
                    // 已选择的标签
                    if !tempFilter.tags.isEmpty {
                        ProblemFilterSection(
                            title: "Selected Tags (\(tempFilter.tags.count))",
                            icon: "bookmark.fill",
                            iconColor: .pink
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                Button {
                                    tempFilter.tags.removeAll()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text("Clear All")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.red)
                                    )
                                }
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(tempFilter.tags, id: \.self) { tag in
                                        SelectedTagChip(
                                            tag: tag,
                                            onRemove: {
                                                tempFilter.tags.removeAll { $0 == tag }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    
                    // 算法标签
                    ProblemFilterSection(
                        title: "Algorithm Tags",
                        icon: "text.book.closed.fill",
                        iconColor: .indigo
                    ) {
                        FlowLayout(spacing: 8) {
                            ForEach(store.allTags, id: \.self) { tag in
                                TagToggleButton(
                                    tag: tag,
                                    isSelected: tempFilter.tags.contains(tag),
                                    action: {
                                        if tempFilter.tags.contains(tag) {
                                            tempFilter.tags.removeAll { $0 == tag }
                                        } else {
                                            tempFilter.tags.append(tag)
                                        }
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
            .navigationTitle("Problem Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        tempFilter = ProblemsetFilter()
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
                                    .fill(isFilterInvalid ? Color.gray : Color.blue)
                            )
                    }
                    .disabled(isFilterInvalid)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    private func applyFilter() {
        Task { @MainActor in
            store.updateFilter(tempFilter)
            dismiss()
        }
    }
}

// MARK: - 问题过滤器分组视图
private struct ProblemFilterSection<Content: View>: View {
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

// MARK: - 选项切换行
private struct OptionToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isOn ? color : .gray)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isOn ? color.opacity(0.1) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isOn ? color.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 已选中标签芯片
private struct SelectedTagChip: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.blue)
        )
    }
}

// MARK: - 标签切换按钮
private struct TagToggleButton: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text(tag)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.indigo : Color(.systemGray6))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                isSelected ? Color.clear : Color.gray.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 流式布局
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(
                width: maxWidth,
                height: currentY + lineHeight
            )
        }
    }
}

#Preview {
    ProblemsetFilterView(store: ProblemsetStore())
}
