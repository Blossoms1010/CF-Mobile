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
            Form {
                // 难度范围
                Section("Difficulty Range") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Max. Difficulty")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("from", selection: Binding(
                                get: { tempFilter.minRating ?? 0 },
                                set: { tempFilter.minRating = $0 == 0 ? nil : $0 }
                            )) {
                                Text("any").tag(0)
                                ForEach(Array(stride(from: 800, through: 3500, by: 100)), id: \.self) { rating in
                                    Text("\(rating)").tag(rating)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Min. Difficulty")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("to", selection: Binding(
                                get: { tempFilter.maxRating ?? 9999 },
                                set: { tempFilter.maxRating = $0 == 9999 ? nil : $0 }
                            )) {
                                Text("any").tag(9999)
                                ForEach(Array(stride(from: 800, through: 3500, by: 100)), id: \.self) { rating in
                                    Text("\(rating)").tag(rating)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // 分数范围验证提示
                    if let minRating = tempFilter.minRating,
                       let maxRating = tempFilter.maxRating,
                       maxRating < minRating {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Maximum difficulty cannot be less than the minimum.")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
                
                // 显示选项
                Section("View Options") {
                    Toggle("Hide solved problems", isOn: $tempFilter.hideSolved)
                    Toggle("Show tags on unsolved problems", isOn: $tempFilter.showUnsolvedTags)
                }
                
                // 已选择的标签
                if !tempFilter.tags.isEmpty {
                    Section {
                        HStack {
                            Text("Tags Chosen")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("clear all") {
                                tempFilter.tags.removeAll()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(tempFilter.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .clipShape(Capsule())
                                        .onTapGesture {
                                            tempFilter.tags.removeAll { $0 == tag }
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // 算法标签
                Section("Algorithm Tags") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
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
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("apply") {
                        applyFilter()
                    }
                    .fontWeight(.semibold)
                    .disabled(isFilterInvalid)
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button("reset") {
                        tempFilter = ProblemsetFilter()
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
    
    private func applyFilter() {
        Task { @MainActor in
            store.updateFilter(tempFilter)
            dismiss()
        }
    }
}

// MARK: - 标签切换按钮
private struct TagToggleButton: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                )
                .foregroundColor(isSelected ? .blue : .primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProblemsetFilterView(store: ProblemsetStore())
}
