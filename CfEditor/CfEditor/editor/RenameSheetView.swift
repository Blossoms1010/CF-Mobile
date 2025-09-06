import SwiftUI

struct RenameSheetView: View {
    let originalURL: URL
    var onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var fileName: String
    @State private var isDirectory: Bool = false
    @State private var hasLoadedFileInfo: Bool = true
    @State private var fileInfoLoadFailed = false

    init(originalURL: URL, onConfirm: @escaping (String) -> Void) {
        self.originalURL = originalURL
        self.onConfirm = onConfirm
        // 确保正确初始化文件名，处理空字符串情况
        let initialName = originalURL.lastPathComponent.isEmpty ? "未命名文件" : originalURL.lastPathComponent
        self._fileName = State(initialValue: initialName)
        
        // 同步检查是否为文件夹，避免界面闪烁
        if let resourceIsDir = try? originalURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory {
            self._isDirectory = State(initialValue: resourceIsDir)
        } else {
            self._isDirectory = State(initialValue: false)
        }
    }

    private func loadFileInfo() {
        hasLoadedFileInfo = false
        fileInfoLoadFailed = false
        
        // 重新检查文件信息
        DispatchQueue.global(qos: .userInitiated).async {
            var success = false
            var isDir = false
            
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
                    TextField(isDirectory ? "Folder Name" : "File Name", text: $fileName)
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                } header: {
                    Text(isDirectory ? "Folder Name" : "File Name")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Original Name：")
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
                            Text("Please keep the file extension unchanged when renaming.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Cannot contain special characters：/ \\ : * ? \" < > |")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(isDirectory ? "Rename Folder" : "Rename File")
            .onAppear {
                // 文件信息已在初始化时获取，这里仅做备用检查
                if fileInfoLoadFailed {
                    loadFileInfo()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Rename") {
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
        .previewDisplayName("Rename Folder")
    }
}
#endif
