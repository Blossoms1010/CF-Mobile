import SwiftUI

struct SaveFileSheetView: View {
    var initialFileName: String
    var isCreatingFolder: Bool = false
    var isRenaming: Bool = false  // 新增：标识是否为重命名操作
    var onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(initialFileName: String, isCreatingFolder: Bool = false, isRenaming: Bool = false, onConfirm: @escaping (String) -> Void) {
        self.initialFileName = initialFileName
        self.isCreatingFolder = isCreatingFolder
        self.isRenaming = isRenaming
        self.onConfirm = onConfirm
        self._name = State(initialValue: initialFileName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("File Name", text: $name)
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                } header: {
                    Text(isCreatingFolder ? "Folder Name" : "File Name")
                } footer: {
                    if !isCreatingFolder {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Language Supported：")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("• C/C++ (.c, .cpp, .cxx, .cc, .hpp, .h)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("• Java (.java)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("• Python (.py)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text("其他文件将自动添加 .txt 后缀")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(getNavigationTitle())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(getConfirmButtonText()) {
                        let inputName = name.isEmpty ? initialFileName : name
                        let finalName = shouldProcessFileName() ? processFileName(inputName) : inputName.trimmingCharacters(in: .whitespacesAndNewlines)
                        onConfirm(finalName)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func getNavigationTitle() -> String {
        if isRenaming {
            return isCreatingFolder ? "Rename Folder" : "Rename File"
        } else {
            return isCreatingFolder ? "New Folder" : "New File"
        }
    }
    
    private func getConfirmButtonText() -> String {
        if isRenaming {
            return "Rename"
        } else {
            return isCreatingFolder ? "Create" : "Create"
        }
    }
    
    private func shouldProcessFileName() -> Bool {
        // 只有在创建新文件（非重命名、非文件夹）时才自动处理文件名
        return !isRenaming && !isCreatingFolder
    }
    
    private func processFileName(_ fileName: String) -> String {
        let trimmedName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果文件名已经有 .txt 后缀，直接返回
        if trimmedName.lowercased().hasSuffix(".txt") {
            return trimmedName
        }
        
        // 检查是否是支持的编程语言后缀
        let supportedExtensions = ["cpp", "cxx", "cc", "c", "hpp", "h", "java", "py"]
        let lowercaseName = trimmedName.lowercased()
        
        for ext in supportedExtensions {
            if lowercaseName.hasSuffix(".\(ext)") {
                return trimmedName // 已经有支持的编程语言后缀，直接返回
            }
        }
        
        // 如果没有支持的后缀且不是 .txt，自动添加 .txt
        return trimmedName + ".txt"
    }
}


