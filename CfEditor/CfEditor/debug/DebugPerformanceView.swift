import SwiftUI

// MARK: - Debug Performance View

struct DebugPerformanceView: View {
    @State private var stats: (totalRequests: Int, totalCacheHitRate: Double, methodStats: [String: CFPerformanceMonitor.RequestStats]) = (0, 0, [:])
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 总体统计
                    overallStatsView
                    
                    // 方法统计
                    methodStatsView
                    
                    // 操作按钮
                    actionButtonsView
                    
                    // 测试按钮
                    testButtonsView
                }
                .padding()
            }
            .navigationTitle("API 性能监控")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                refreshStats()
            }
        }
    }
    
    private var overallStatsView: some View {
        VStack(spacing: 12) {
            Text("总体统计")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                StatCard(
                    title: "总请求数",
                    value: "\(stats.totalRequests)",
                    icon: "network",
                    color: .blue
                )
                
                StatCard(
                    title: "缓存命中率",
                    value: String(format: "%.1f%%", stats.totalCacheHitRate * 100),
                    icon: "speedometer",
                    color: .green
                )
            }
        }
    }
    
    private var methodStatsView: some View {
        VStack(spacing: 12) {
            Text("方法统计")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if stats.methodStats.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(stats.methodStats.keys).sorted(), id: \.self) { method in
                        if let methodStat = stats.methodStats[method] {
                            MethodStatRow(method: method, stat: methodStat)
                        }
                    }
                }
            }
        }
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            Text("操作")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Button("刷新统计") {
                    refreshStats()
                }
                .buttonStyle(.bordered)
                
                Button("重置统计") {
                    resetStats()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                
                Button("清理缓存") {
                    clearCache()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
            }
        }
    }
    
    private var testButtonsView: some View {
        VStack(spacing: 12) {
            Text("性能测试")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                Button("运行缓存测试") {
                    runCacheTest()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                
                Button("运行限流测试") {
                    runRateLimitTest()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                
                Button("运行磁盘缓存测试") {
                    runDiskCacheTest()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                
                Button("运行完整测试套件") {
                    runAllTests()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
            }
            
            if isLoading {
                ProgressView("测试进行中...")
                    .padding(.top)
            }
        }
    }
    
    private func refreshStats() {
        Task {
            stats = await CFAPI.shared.getPerformanceStats()
        }
    }
    
    private func resetStats() {
        Task {
            await CFAPI.shared.resetPerformanceStats()
            refreshStats()
        }
    }
    
    private func clearCache() {
        Task {
            await CFAPI.shared.clearAllCache()
            refreshStats()
        }
    }
    
    private func runCacheTest() {
        isLoading = true
        Task {
            await APITestHelper.shared.testCachePerformance()
            refreshStats()
            isLoading = false
        }
    }
    
    private func runRateLimitTest() {
        isLoading = true
        Task {
            await APITestHelper.shared.testRateLimiting()
            refreshStats()
            isLoading = false
        }
    }
    
    private func runDiskCacheTest() {
        isLoading = true
        Task {
            await APITestHelper.shared.testDiskCache()
            refreshStats()
            isLoading = false
        }
    }
    
    private func runAllTests() {
        isLoading = true
        Task {
            await APITestHelper.shared.runAllTests()
            refreshStats()
            isLoading = false
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct MethodStatRow: View {
    let method: String
    let stat: CFPerformanceMonitor.RequestStats
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(method)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(stat.count) 次")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("平均耗时")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0fms", stat.averageTime * 1000))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("缓存命中率")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", stat.cacheHitRate * 100))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(stat.cacheHitRate > 0.5 ? .green : .orange)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

#Preview {
    DebugPerformanceView()
}
