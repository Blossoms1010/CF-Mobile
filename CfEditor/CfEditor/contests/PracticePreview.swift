import SwiftUI

// MARK: - Practice 界面美化效果预览
#Preview("Practice Enhancements") {
    TabView {
        NavigationStack {
            PracticeComponentsPreview()
                .navigationTitle("Practice Preview")
        }
        .tabItem {
            Label("Components", systemImage: "square.grid.2x2")
        }
        
        NavigationStack {
            AnimationsPreview()
                .navigationTitle("Animations")
        }
        .tabItem {
            Label("Animations", systemImage: "sparkles")
        }
    }
}

// MARK: - 组件预览
struct PracticeComponentsPreview: View {
    @State private var selectedMode: PracticeMode = .contests
    @State private var searchText = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // 分段控制器预览
                VStack(alignment: .leading, spacing: 12) {
                    Text("自定义分段控制器")
                        .font(.headline)
                    CustomSegmentedPicker(selection: $selectedMode)
                }
                
                // 搜索框预览
                VStack(alignment: .leading, spacing: 12) {
                    Text("增强搜索框")
                        .font(.headline)
                    EnhancedSearchField(
                        text: $searchText,
                        placeholder: "Search Problems...",
                        onSubmit: {}
                    )
                }
                
                // 骨架屏预览
                VStack(alignment: .leading, spacing: 12) {
                    Text("骨架屏加载")
                        .font(.headline)
                    VStack(spacing: 12) {
                        SkeletonListRow()
                        SkeletonListRow()
                        SkeletonListRow()
                    }
                }
                
                // 进度条示例
                VStack(alignment: .leading, spacing: 12) {
                    Text("进度条示例")
                        .font(.headline)
                    
                    ForEach([0.3, 0.6, 0.9], id: \.self) { progress in
                        HStack(spacing: 12) {
                            Text("\(Int(progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 40)
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 4)
                                    
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.green, .blue],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * progress, height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // 状态图标示例
                VStack(alignment: .leading, spacing: 12) {
                    Text("状态图标")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            circledStatusIcon(for: .solved)
                            Text("已解决")
                                .font(.caption2)
                        }
                        
                        VStack(spacing: 4) {
                            circledStatusIcon(for: .tried)
                            Text("尝试过")
                                .font(.caption2)
                        }
                        
                        VStack(spacing: 4) {
                            circledStatusIcon(for: .none)
                            Text("未尝试")
                                .font(.caption2)
                        }
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - 动画预览
struct AnimationsPreview: View {
    @State private var isExpanded = false
    @State private var showContent = false
    @State private var progress: Double = 0.0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // 展开/收起动画
                VStack(alignment: .leading, spacing: 12) {
                    Text("展开/收起动画")
                        .font(.headline)
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.accentColor)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            
                            Text("点击展开/收起")
                                .font(.system(size: 16, weight: .medium))
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                    
                    if isExpanded {
                        VStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { index in
                                HStack {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 8, height: 8)
                                    Text("展开内容 \(index + 1)")
                                        .font(.subheadline)
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                ))
                                .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(Double(index) * 0.05), value: isExpanded)
                            }
                        }
                        .padding(.leading, 20)
                    }
                }
                
                // 滑入动画
                VStack(alignment: .leading, spacing: 12) {
                    Text("滑入动画")
                        .font(.headline)
                    
                    Button("触发滑入效果") {
                        showContent = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                showContent = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if showContent {
                        ForEach(0..<5, id: \.self) { index in
                            HStack {
                                Text("列表项 \(index + 1)")
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 2)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .opacity
                            ))
                            .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: showContent)
                        }
                    }
                }
                
                // 进度条动画
                VStack(alignment: .leading, spacing: 12) {
                    Text("进度条动画")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 40)
                            .monospacedDigit()
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 6)
                                
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.green, .blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * progress, height: 6)
                                    .animation(.easeOut(duration: 0.5), value: progress)
                            }
                        }
                        .frame(height: 6)
                    }
                    
                    HStack {
                        Button("25%") { progress = 0.25 }
                        Button("50%") { progress = 0.50 }
                        Button("75%") { progress = 0.75 }
                        Button("100%") { progress = 1.00 }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer(minLength: 40)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            showContent = true
        }
    }
}
