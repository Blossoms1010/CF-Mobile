import SwiftUI

struct SubmissionStatusView: View {
    @ObservedObject var vm: SubmissionStatusViewModel
    let problem: CFProblemIdentifier
    let handle: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Capsule().fill(Color.secondary.opacity(0.5)).frame(width: 38, height: 5).padding(.top, 6)
            HStack {
                Text("判题状态").font(.headline)
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark") }
            }
            .padding(.horizontal, 12)

            if let err = vm.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
                    Text(err).foregroundColor(.orange)
                    Spacer()
                    Button("重试") { vm.clearError() }
                }
                .padding(.horizontal, 12)
            }

            List {
                ForEach(vm.items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("#\(item.runId)").font(.subheadline).foregroundColor(.secondary)
                            Text(format(item.createdAt)).font(.subheadline).foregroundColor(.secondary)
                            Spacer()
                            Text(item.verdict.displayText)
                                .fontWeight(item.verdict == .ok ? .semibold : .regular)
                                .foregroundColor(color(for: item.verdict))
                        }
                        if let u = vm.submitterInfo {
                            HStack(spacing: 6) {
                                Text("提交者:").foregroundColor(.secondary)
                                Text(u.handle)
                                    .font(.subheadline).bold()
                                    .foregroundStyle(colorForRank(u.rank))
                            }
                            .font(.caption)
                        }
                        HStack(spacing: 12) {
                            Text("题目: \(item.problem.contestId)\(item.problem.index)")
                            if let lang = item.language { Text(lang).foregroundColor(.secondary).lineLimit(1) }
                        }
                        .font(.caption)
                        HStack(spacing: 12) {
                            Text("通过: \(item.passedTests)")
                            Text("时间: \(item.timeMs)ms")
                            Text("内存: \(formatBytes(item.memBytes))")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)

            HStack(spacing: 12) {
                if vm.isLoadingAll {
                    ProgressView().controlSize(.small)
                    Text("正在加载历史提交…").font(.footnote).foregroundColor(.secondary)
                    Spacer()
                } else if vm.isPolling {
                    ProgressView().controlSize(.small)
                    Text("正在查询最新提交…").font(.footnote).foregroundColor(.secondary)
                    Spacer()
                    Button("停止") { vm.stopPolling() }
                } else {
                    Image(systemName: "checkmark.circle").foregroundColor(.green)
                    Text("已停止轮询").font(.footnote).foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .presentationDetents([.fraction(0.25), .fraction(0.5), .large])
        .presentationDragIndicator(.visible)
        .task {
            let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                vm.errorMessage = "未配置 Handle，无法获取你的提交状态"
            } else {
                await vm.loadAll(for: problem, handle: trimmed)
                vm.startTrackingLatest(for: problem, handle: trimmed)
            }
        }
        .onDisappear { vm.stopPolling() }
    }

    private func color(for v: CFVerdict) -> Color {
        switch v {
        case .ok: return .green
        case .wrongAnswer, .runtimeError, .compilationError: return .red
        case .timeLimit, .memoryLimit: return .orange
        case .testing, .idlen: return .blue
        default: return .primary
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1<<20 { return String(format: "%.1fMB", Double(bytes)/1048576.0) }
        if bytes >= 1<<10 { return String(format: "%.1fKB", Double(bytes)/1024.0) }
        return "\(bytes)B"
    }

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    private func format(_ date: Date) -> String {
        SubmissionStatusView.df.string(from: date)
    }
}


