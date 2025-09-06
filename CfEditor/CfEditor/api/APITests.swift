import Foundation

// MARK: - API Performance Test Helper

class APITestHelper {
    static let shared = APITestHelper()
    
    private init() {}
    
    /// 测试缓存性能
    func testCachePerformance() async {
        print("🧪 开始测试 API 缓存性能...")
        
        let api = CFAPI.shared
        await api.resetPerformanceStats()
        
        do {
            // 第一次请求 - 应该从网络获取
            let start1 = Date()
            let contests1 = try await api.allFinishedContests(forceRefresh: true)
            let duration1 = Date().timeIntervalSince(start1)
            print("📊 首次请求耗时: \(String(format: "%.2f", duration1 * 1000))ms, 获取到 \(contests1.count) 个比赛")
            
            // 第二次请求 - 应该从缓存获取
            let start2 = Date()
            let contests2 = try await api.allFinishedContests(forceRefresh: false)
            let duration2 = Date().timeIntervalSince(start2)
            print("📊 缓存请求耗时: \(String(format: "%.2f", duration2 * 1000))ms, 获取到 \(contests2.count) 个比赛")
            
            // 性能提升比例
            let improvement = duration1 > 0 ? (duration1 - duration2) / duration1 * 100 : 0
            print("⚡ 缓存性能提升: \(String(format: "%.1f", improvement))%")
            
            // 获取性能统计
            let stats = await api.getPerformanceStats()
            print("📈 总请求数: \(stats.totalRequests)")
            print("📈 缓存命中率: \(String(format: "%.1f", stats.totalCacheHitRate * 100))%")
            
            if let contestStats = stats.methodStats["contest.list"] {
                print("📈 contest.list 平均耗时: \(String(format: "%.2f", contestStats.averageTime * 1000))ms")
                print("📈 contest.list 缓存命中率: \(String(format: "%.1f", contestStats.cacheHitRate * 100))%")
            }
            
        } catch {
            print("❌ 测试失败: \(error)")
        }
    }
    
    /// 测试限流机制
    func testRateLimiting() async {
        print("\n🧪 开始测试限流机制...")
        
        let api = CFAPI.shared
        await api.resetPerformanceStats()
        
        // 快速发送多个请求
        let requests = (1...5).map { i in
            Task {
                let start = Date()
                do {
                    let _ = try await api.allFinishedContests(forceRefresh: true)
                    let duration = Date().timeIntervalSince(start)
                    print("📊 请求 \(i) 完成，耗时: \(String(format: "%.2f", duration * 1000))ms")
                } catch {
                    print("❌ 请求 \(i) 失败: \(error)")
                }
            }
        }
        
        // 等待所有请求完成
        for request in requests {
            await request.value
        }
        
        let stats = await api.getPerformanceStats()
        print("📈 总请求数: \(stats.totalRequests)")
        print("📈 缓存命中率: \(String(format: "%.1f", stats.totalCacheHitRate * 100))%")
    }
    
    /// 测试磁盘缓存
    func testDiskCache() async {
        print("\n🧪 开始测试磁盘缓存...")
        
        let api = CFAPI.shared
        await api.clearAllCache()
        await api.resetPerformanceStats()
        
        do {
            // 请求历史比赛数据（应该使用磁盘缓存）
            let start1 = Date()
            let contests1 = try await api.allFinishedContests(forceRefresh: true)
            let duration1 = Date().timeIntervalSince(start1)
            print("📊 首次请求耗时: \(String(format: "%.2f", duration1 * 1000))ms")
            
            // 清理内存缓存但保留磁盘缓存
            await api.clearAllCache()
            
            // 再次请求 - 应该从磁盘缓存恢复
            let start2 = Date()
            let contests2 = try await api.allFinishedContests(forceRefresh: false)
            let duration2 = Date().timeIntervalSince(start2)
            print("📊 磁盘缓存请求耗时: \(String(format: "%.2f", duration2 * 1000))ms")
            
            let improvement = duration1 > 0 ? (duration1 - duration2) / duration1 * 100 : 0
            print("⚡ 磁盘缓存性能提升: \(String(format: "%.1f", improvement))%")
            
        } catch {
            print("❌ 磁盘缓存测试失败: \(error)")
        }
    }
    
    /// 运行所有测试
    func runAllTests() async {
        print("🚀 开始 API 性能测试套件...")
        
        await testCachePerformance()
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 等待1秒
        
        await testRateLimiting()
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 等待1秒
        
        await testDiskCache()
        
        print("\n✅ 所有测试完成!")
    }
}
