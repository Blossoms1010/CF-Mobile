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
    private let judgeClient = Judge0Client()

    private func presentToast(_ text: String) {
        toastText = text
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut) { showToast = false }
        }
    }

    private func editorColumn(title: String, text: Binding<String>, isEditable: Bool, placeholder: String, onSet: (() -> Void)? = nil, onCopy: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                HStack(spacing: 12) {
                    if let onSet = onSet {
                        Button("Set", action: onSet)
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .buttonStyle(PressEffectButtonStyle())
                    }
                    Button("Copy") {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = text.wrappedValue
                        #endif
                        onCopy?()
                    }
                    .font(.footnote)
                    .foregroundColor(.blue)
                    .buttonStyle(PressEffectButtonStyle())
                }
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: text)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.none)
                    .autocorrectionDisabled(true)
                    .disabled(!isEditable)
                    .frame(minHeight: 160)
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2))
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(testCases.indices, id: \.self) { idx in
                            let isSelected = (idx == selectedIndex)
                            Button(action: { withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85)) { selectedIndex = idx } }) {
                                Text("Test Case \(idx + 1)")
                                    .font(.subheadline)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                                    .foregroundColor(isSelected ? .accentColor : .primary)
                                    .cornerRadius(8)
                            }
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                        }
                        Button(action: { addTestCase() }) {
                            Label("New", systemImage: "plus")
                                .font(.subheadline)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.horizontal, 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: testCases.count)
                }

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
                    Text(toastText)
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
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
                        if let tStr = res.time, let tSec = Double(tStr) {
                            testCases[index].lastRunMs = max(0, Int(tSec * 1000))
                        } else {
                            testCases[index].lastRunMs = nil
                        }
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
        HStack(spacing: 6) {
            if runningIndices.contains(index) {
                Text("Running")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.orange))
                    .accessibilityLabel("Running")
            } else if testCases.indices.contains(index) {
                switch testCases[index].verdict {
                case .passed:
                    Text("Passed")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.green))
                        .accessibilityLabel("Pased")
                case .failed:
                    Text("Failed")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                        .accessibilityLabel("Failed")
                case .none:
                    EmptyView()
                }
            } else {
                EmptyView()
            }
            if !runningIndices.contains(index), testCases.indices.contains(index) {
                if testCases[index].timedOut {
                    Text("Time Out")
                        .font(.caption2)
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.yellow.opacity(0.6)))
                        .accessibilityLabel("Time Out")
                } else if let ms = testCases[index].lastRunMs {
                    Text("\(ms)ms")
                        .font(.caption2)
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.yellow.opacity(0.3)))
                        .accessibilityLabel("Run Time")
                }
            }
        }
    }
}

// MARK: - 分离子视图，降低类型检查复杂度
extension RunSheetView {
    @ViewBuilder
    fileprivate func testCaseHeader(for idx: Int) -> some View {
        HStack {
            Text("TC \(idx + 1)").font(.headline)
            statusBadge(for: idx)
            Spacer()
            HStack(spacing: 10) {
                Button { runTestCase(at: idx) } label: {
                    ZStack {
                        Circle().fill(Color.green)
                        Image(systemName: runningIndices.contains(idx) ? "hourglass" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 30, height: 30)
                }
                .disabled(runningIndices.contains(idx))
                .buttonStyle(PressEffectButtonStyle())
                .accessibilityLabel("启动该样例")

                Button { testCaseToDeleteIndex = idx } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(Color.red))
                }
                .buttonStyle(PressEffectButtonStyle())
                .accessibilityLabel("删除该样例")
            }
        }
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
            VStack(alignment: .leading, spacing: 12) {
                testCaseHeader(for: idx)
                Divider()
                testCaseEditors(for: idx)
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 16)
            .opacity(selectedIndex == idx ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.2), value: selectedIndex)
        }
        .tag(idx)
    }
}


