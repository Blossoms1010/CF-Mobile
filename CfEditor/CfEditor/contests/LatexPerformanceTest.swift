import SwiftUI

/// LaTeX渲染性能测试视图
struct LatexPerformanceTest: View {
    @State private var renderTimes: [Double] = []
    @State private var isRunning = false
    @State private var testIndex = 0
    
    let testCases = [
        "简单文本：这是一个不含数学公式的文本。",
        "内联公式：计算 $E = mc^2$ 的结果。",
        "显示公式：$$\\sum_{i=1}^{n} i = \\frac{n(n+1)}{2}$$",
        "复杂公式：$$\\int_{-\\infty}^{\\infty} e^{-\\frac{x^2}{2\\sigma^2}} dx = \\sigma\\sqrt{2\\pi}$$",
        "混合内容：在数组 $p=[1,4,3,2]$ 中，满足条件 $s_i = 1$ 的位置是 $i = 3$。\n\n对于区间 $[l, r]$，我们有：$$\\max(p[l:r]) \\neq p_i$$",
        "长文本：" + String(repeating: "这是一段很长的文本，用来测试渲染性能。", count: 20) + " 最后加个公式：$\\sum_{k=1}^{\\infty} \\frac{1}{k^2} = \\frac{\\pi^2}{6}$"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 性能指标显示
                if !renderTimes.isEmpty {
                    VStack {
                        Text("渲染性能统计")
                            .font(.headline)
                        
                        HStack {
                            StatView(title: "平均时间", value: String(format: "%.2f ms", renderTimes.reduce(0, +) / Double(renderTimes.count)))
                            StatView(title: "最短时间", value: String(format: "%.2f ms", renderTimes.min() ?? 0))
                            StatView(title: "最长时间", value: String(format: "%.2f ms", renderTimes.max() ?? 0))
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // 控制按钮
                HStack {
                    Button(isRunning ? "停止测试" : "开始性能测试") {
                        if isRunning {
                            stopTest()
                        } else {
                            startTest()
                        }
                    }
                    .disabled(isRunning && testIndex >= testCases.count)
                    
                    Button("清除结果") {
                        renderTimes.removeAll()
                        testIndex = 0
                    }
                    .disabled(isRunning)
                }
                .buttonStyle(.bordered)
                
                if isRunning {
                    ProgressView("正在测试第 \(testIndex + 1)/\(testCases.count) 个案例...")
                        .progressViewStyle(CircularProgressViewStyle())
                }
                
                // 测试内容显示
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(testCases.enumerated()), id: \.offset) { index, testCase in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("测试案例 \(index + 1)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    if index < renderTimes.count {
                                        Text("\(String(format: "%.2f", renderTimes[index])) ms")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                                
                                LatexRenderedTextView(testCase, fontSize: 14)
                                    .border(Color.gray.opacity(0.3), width: 1)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("LaTeX 性能测试")
        }
    }
    
    private func startTest() {
        renderTimes.removeAll()
        testIndex = 0
        isRunning = true
        runNextTest()
    }
    
    private func stopTest() {
        isRunning = false
    }
    
    private func runNextTest() {
        guard isRunning && testIndex < testCases.count else {
            isRunning = false
            return
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 模拟渲染时间测量（实际应该通过WebView回调测量）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let endTime = CFAbsoluteTimeGetCurrent()
            let renderTime = (endTime - startTime) * 1000 // 转换为毫秒
            
            renderTimes.append(renderTime)
            testIndex += 1
            
            runNextTest()
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LatexPerformanceTest_Previews: PreviewProvider {
    static var previews: some View {
        LatexPerformanceTest()
    }
}
