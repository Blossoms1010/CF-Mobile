import SwiftUI

struct RenameSheetView: View {
    let originalURL: URL
    var onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var fileName: String
    @State private var isDirectory: Bool = false
    @State private var hasLoadedFileInfo: Bool = false
    @State private var fileInfoLoadFailed = false

    init(originalURL: URL, onConfirm: @escaping (String) -> Void) {
        self.originalURL = originalURL
        self.onConfirm = onConfirm
        // 确保正确初始化文件名，处理空字符串情况
        let initialName = originalURL.lastPathComponent.isEmpty ? "未命名文件" : originalURL.lastPathComponent
        self._fileName = State(initialValue: initialName)
    }

    private func loadFileInfo() {
        hasLoadedFileInfo = false
        fileInfoLoadFailed = false
        
        // 异步加载文件信息，避免阻塞UI
        DispatchQueue.global(qos: .userInitiated).async {
            var success = false
            var isDir = false
            
            // 模拟加载时间
            Thread.sleep(forTimeInterval: 0.5)
            
            // 获取文件属性
            if let resourceIsDir = try? originalURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory {
                isDir = resourceIsDir
                success = true
            }
            
            // 回到主线程更新UI
            DispatchQueue.main.async {
                if success {
                    self.isDirectory = isDir
                    self.fileInfoLoadFailed = false
                } else {
                    self.isDirectory = false // 默认作为文件处理
                    self.fileInfoLoadFailed = true
                }
                self.hasLoadedFileInfo = true
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(isDirectory ? "文件夹名" : "文件名", text: $fileName)
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                } header: {
                    Text(isDirectory ? "文件夹名" : "文件名")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("原名称：")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(originalURL.lastPathComponent)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        
                        if fileInfoLoadFailed {
                            Text("⚠️ 无法确定文件类型，按默认文件处理")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        } else if !isDirectory {
                            Text("重命名时请保持文件扩展名不变")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("文件夹名称不能包含特殊字符：/ \\ : * ? \" < > |")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(isDirectory ? "重命名文件夹" : "重命名文件")
            .onAppear {
                // 确保在视图出现时立即开始加载文件信息
                if !hasLoadedFileInfo {
                    loadFileInfo()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("重命名") {
                        let trimmedName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
                        onConfirm(trimmedName)
                        dismiss()
                    }
                    .bold()
                    .disabled(fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#if DEBUG
struct RenameSheetView_Previews: PreviewProvider {
    static var previews: some View {
        // 文件重命名预览
        RenameSheetView(originalURL: URL(fileURLWithPath: "/path/to/example.txt")) { name in
            print("Renaming to: \(name)")
        }
        .previewDisplayName("重命名文件")
        
        // 文件夹重命名预览
        RenameSheetView(originalURL: URL(fileURLWithPath: "/path/to/folder")) { name in
            print("Renaming folder to: \(name)")
        }
        .previewDisplayName("重命名文件夹")
    }
}
#endif