import SwiftUI

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct RunSheetView: View {
    @Binding var testCases: [TestCase]
    var language: String
    @Binding var code: String
    @State private var selectedIndex: Int = 0
    @State private var toastText: String = ""
    @State private var showToast: Bool = false
    @State private var testCaseToDeleteIndex: Int? = nil
    @State private var runningIndices: Set<Int> = []
    private let judgeClient = Judge0Client(fromManager: Judge0ConfigManager.shared)

    private func presentToast(_ text: String) {
        toastText = text
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut) { showToast = false }
        }
    }

    private func editorColumn(title: String, text: Binding<String>, isEditable: Bool, placeholder: String, onSet: (() -> Void)? = nil, onCopy: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 🎨 精美的头部区域
            HStack(spacing: 8) {
                // 图标区分不同类型
                Image(systemName: title == "Input" ? "arrow.down.doc.fill" : 
                                   title.contains("Expected") ? "checkmark.circle.fill" : 
                                   "arrow.up.doc.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        title == "Input" ? 
                            LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        title.contains("Expected") ? 
                            LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: title == "Input" ? [.blue, .cyan] : 
                                    title.contains("Expected") ? [.green, .mint] : 
                                    [.orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Spacer()
                
                // 美化的按钮组
                HStack(spacing: 8) {
                    if let onSet = onSet {
                        Button(action: onSet) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Set")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            )
                        }
                        .buttonStyle(PressEffectButtonStyle())
                    }
                    
                    Button {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = text.wrappedValue
                        #endif
                        onCopy?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("Copy")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                    }
                    .buttonStyle(PressEffectButtonStyle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    // 渐变背景
                    LinearGradient(
                        colors: title == "Input" ? 
                            [Color.blue.opacity(0.08), Color.cyan.opacity(0.05)] :
                        title.contains("Expected") ? 
                            [Color.green.opacity(0.08), Color.mint.opacity(0.05)] :
                            [Color.orange.opacity(0.08), Color.yellow.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // 顶部高光
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
            )
            
            Divider()
                .overlay(
                    LinearGradient(
                        colors: title == "Input" ? [.blue.opacity(0.3), .cyan.opacity(0.3)] :
                                title.contains("Expected") ? [.green.opacity(0.3), .mint.opacity(0.3)] :
                                [.orange.opacity(0.3), .yellow.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            // 📝 编辑器区域
            ZStack(alignment: .topLeading) {
                // 背景纹理
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color(uiColor: .tertiarySystemBackground))
                
                TextEditor(text: text)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.none)
                    .autocorrectionDisabled(true)
                    .disabled(!isEditable)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 140)
                    .padding(4)
                
                if text.wrappedValue.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.cursor")
                                .font(.system(size: 13))
                            Text(isEditable ? "Tap to edit..." : "No output yet")
                                .font(.system(size: 14, design: .rounded))
                        }
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.secondary.opacity(0.6), .secondary.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }
                    .padding(.top, 16)
                    .padding(.leading, 12)
                }
            }
            .padding(.bottom, 8)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
        .shadow(
            color: title == "Input" ? Color.blue.opacity(0.15) :
                   title.contains("Expected") ? Color.green.opacity(0.15) :
                   Color.orange.opacity(0.15),
            radius: 8,
            x: 0,
            y: 4
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: title == "Input" ? 
                            [Color.blue.opacity(0.3), Color.cyan.opacity(0.2)] :
                        title.contains("Expected") ? 
                            [Color.green.opacity(0.3), Color.mint.opacity(0.2)] :
                            [Color.orange.opacity(0.3), Color.yellow.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(testCases.indices, id: \.self) { idx in
                            let isSelected = (idx == selectedIndex)
                            Button(action: { withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85)) { selectedIndex = idx } }) {
                                HStack(spacing: 6) {
                                    // 测试用例状态指示器
                                    Circle()
                                        .fill(
                                            testCases[idx].verdict == .passed ? Color.green :
                                            testCases[idx].verdict == .failed ? Color.red :
                                            Color.gray.opacity(0.3)
                                        )
                                        .frame(width: 8, height: 8)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                        )
                                    
                                    Text("TC \(idx + 1)")
                                        .font(.system(size: 14, weight: isSelected ? .bold : .semibold, design: .rounded))
                                }
                                .foregroundColor(isSelected ? .white : .primary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 14)
                                .background(
                                    ZStack {
                                        if isSelected {
                                            // 选中状态：渐变背景
                                            LinearGradient(
                                                colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                            .cornerRadius(12)
                                            .shadow(color: Color.accentColor.opacity(0.4), radius: 6, x: 0, y: 3)
                                        } else {
                                            // 未选中状态
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(uiColor: .secondarySystemBackground))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                                )
                                        }
                                    }
                                )
                            }
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                        }
                        
                        // 添加新测试用例按钮
                        Button(action: { addTestCase() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("New")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.accentColor)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.accentColor.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [Color.accentColor.opacity(0.5), Color.accentColor.opacity(0.2)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5,
                                                antialiased: true
                                            )
                                    )
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: testCases.count)
                }
                .background(Color(uiColor: .systemGroupedBackground))

                TabView(selection: $selectedIndex) {
                    ForEach(testCases.indices, id: \.self) { idx in
                        testCasePage(for: idx)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.85), value: selectedIndex)
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: testCases.count)
            }
            .navigationTitle("Run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        #if canImport(UIKit)
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        #endif
                    } label: { Label("done", systemImage: "keyboard.chevron.compact.down") }
                    .accessibilityLabel("收起键盘")
                }
            }
            .overlay(alignment: .top) {
                if showToast {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.green)
                        
                        Text(toastText)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                }
            }
            .confirmationDialog("删除该样例？", isPresented: Binding(get: { testCaseToDeleteIndex != nil }, set: { if !$0 { testCaseToDeleteIndex = nil } })) {
                Button("Delete", role: .destructive) { if let idx = testCaseToDeleteIndex { removeTestCase(at: idx) }; testCaseToDeleteIndex = nil }
                Button("Cancel", role: .cancel) { testCaseToDeleteIndex = nil }
            }
        }
    }

    private func addTestCase() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            testCases.append(TestCase(input: "", expected: "", received: ""))
            selectedIndex = max(0, testCases.count - 1)
        }
        presentToast("New test case added")
    }

    private func removeTestCase(at index: Int) {
        guard testCases.indices.contains(index) else { return }
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85)) {
            testCases.remove(at: index)
        }
        if testCases.isEmpty {
            selectedIndex = 0
        } else {
            selectedIndex = min(selectedIndex, max(0, testCases.count - 1))
        }
        presentToast("Have deleted test case")
    }

    private func runTestCase(at index: Int) {
        guard testCases.indices.contains(index) else { return }
        runningIndices.insert(index)
        testCases[index].timedOut = false
        let stdin = testCases[index].input
        let expectedAtRun = testCases[index].expected
        let source = code
        let lang = language
        judgeClient.submitAndWait(languageKey: lang, sourceCode: source, stdin: stdin) { result in
            DispatchQueue.main.async {
                runningIndices.remove(index)
                switch result {
                case .failure(let error):
                    if testCases.indices.contains(index) {
                        let nsError = error as NSError
                        if nsError.domain == "Judge0Client" && nsError.code == -2 {
                            testCases[index].timedOut = true
                            testCases[index].received = ""
                            testCases[index].verdict = .none
                            presentToast("运行超时")
                        } else {
                            testCases[index].received = ""
                            testCases[index].verdict = .failed
                            presentToast("运行失败：\(error.localizedDescription)")
                        }
                    }
                case .success(let res):
                    let output = (res.stdout?.isEmpty == false) ? res.stdout! : (res.compile_output ?? res.stderr ?? res.message ?? "")
                    if testCases.indices.contains(index) {
                        // 使用 Judge0 的 time 字段（CPU执行时间）
                        testCases[index].lastRunMs = res.runTimeMs
                        testCases[index].received = output
                        let statusId = res.status.id
                        let desc = res.status.description.lowercased()
                        let isTLE = statusId == 5 || desc.contains("time limit") || desc.contains("timeout") || desc == "tle"
                        if isTLE {
                            testCases[index].timedOut = true
                            testCases[index].verdict = .none
                            presentToast("运行超时")
                        } else {
                            testCases[index].timedOut = false
                            let passed = normalizeForCompare(output) == normalizeForCompare(expectedAtRun)
                            testCases[index].verdict = passed ? .passed : .failed
                            presentToast("Run Over")
                        }
                    }
                }
            }
        }
    }

    private func normalizeForCompare(_ text: String) -> String {
        let unified = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var lines = unified.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        lines = lines.map { line in
            var s = line
            while let last = s.last, last == " " || last == "\t" { s.removeLast() }
            return s
        }
        while let last = lines.last, last.isEmpty { lines.removeLast() }
        return lines.joined(separator: "\n")
    }

    @ViewBuilder
    private func statusBadge(for index: Int) -> some View {
        HStack(spacing: 8) {
            if runningIndices.contains(index) {
                // 运行中状态
                HStack(spacing: 5) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                    
                    Text("Running")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange, Color.orange.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.orange.opacity(0.3), radius: 4, x: 0, y: 2)
                )
                .accessibilityLabel("Running")
            } else if testCases.indices.contains(index) {
                switch testCases[index].verdict {
                case .passed:
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Accepted")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color.green.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
                    .accessibilityLabel("Accepted")
                    
                case .failed:
                    HStack(spacing: 5) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Wrong answer")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.red, Color.red.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color.red.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
                    .accessibilityLabel("Wrong answer")
                    
                case .none:
                    EmptyView()
                }
            } else {
                EmptyView()
            }
            
            // 时间显示（超时时也显示时间）
            if !runningIndices.contains(index), testCases.indices.contains(index), let ms = testCases[index].lastRunMs {
                if testCases[index].timedOut {
                    // 超时时显示完整的 Time limit exceeded 标签
                    HStack(spacing: 5) {
                        Image(systemName: "clock.badge.exclamationmark.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Time limit exceeded")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange, Color.orange.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color.orange.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
                    .accessibilityLabel("Time limit exceeded")
                } else {
                    // 正常完成时显示灰色时间标签
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(ms)ms")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.gray.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .accessibilityLabel("Runtime: \(ms) milliseconds")
                }
            }
        }
    }
}

// MARK: - 分离子视图，降低类型检查复杂度
extension RunSheetView {
    @ViewBuilder
    fileprivate func testCaseHeader(for idx: Int) -> some View {
        HStack(spacing: 12) {
            // 左侧：测试用例信息
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Test Case \(idx + 1)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                // 状态标签
                statusBadge(for: idx)
            }
            
            Spacer()
            
            // 右侧：操作按钮
            HStack(spacing: 12) {
                // 运行按钮
                Button { runTestCase(at: idx) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: runningIndices.contains(idx) ? "hourglass" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                        
                        if !runningIndices.contains(idx) {
                            Text("Run")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            LinearGradient(
                                colors: runningIndices.contains(idx) ? 
                                    [Color.orange, Color.orange.opacity(0.8)] :
                                    [Color.green, Color.green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .cornerRadius(12)
                            
                            // 高光效果
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .cornerRadius(12)
                        }
                    )
                    .shadow(
                        color: runningIndices.contains(idx) ? 
                            Color.orange.opacity(0.4) : 
                            Color.green.opacity(0.4),
                        radius: 6,
                        x: 0,
                        y: 3
                    )
                }
                .disabled(runningIndices.contains(idx))
                .buttonStyle(PressEffectButtonStyle())
                .accessibilityLabel("启动该样例")

                // 删除按钮
                Button { testCaseToDeleteIndex = idx } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(
                            ZStack {
                                LinearGradient(
                                    colors: [Color.red, Color.red.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .cornerRadius(12)
                                
                                // 高光效果
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .cornerRadius(12)
                            }
                        )
                        .shadow(color: Color.red.opacity(0.4), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(PressEffectButtonStyle())
                .accessibilityLabel("删除该样例")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                // 背景卡片
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemBackground))
                
                // 顶部高光
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .cornerRadius(16)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.2), Color.cyan.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    fileprivate func testCaseEditors(for idx: Int) -> some View {
        editorColumn(title: "Input", text: Binding(
            get: { testCases[idx].input },
            set: { newValue in testCases[idx].input = newValue; testCases[idx].verdict = .none }
        ), isEditable: true, placeholder: "", onSet: nil, onCopy: { presentToast("Copied Input") })

        editorColumn(title: "Expected Output", text: Binding(
            get: { testCases[idx].expected },
            set: { newValue in testCases[idx].expected = newValue; testCases[idx].verdict = .none }
        ), isEditable: true, placeholder: "", onSet: nil, onCopy: { presentToast("Copied Expected Output") })

        editorColumn(title: "Received Output", text: Binding(
            get: { testCases[idx].received },
            set: { _ in }
        ), isEditable: false, placeholder: "", onSet: {
            testCases[idx].expected = testCases[idx].received
            testCases[idx].verdict = .none
            presentToast("Replaced with Expected Output")
        }, onCopy: { presentToast("Copied Received Output") })
    }

    @ViewBuilder
    fileprivate func testCasePage(for idx: Int) -> some View {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                testCaseHeader(for: idx)
                
                // 优雅的分隔线
                HStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.blue.opacity(0.3), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                }
                .padding(.horizontal, 8)
                
                testCaseEditors(for: idx)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .opacity(selectedIndex == idx ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.2), value: selectedIndex)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .tag(idx)
    }
}


