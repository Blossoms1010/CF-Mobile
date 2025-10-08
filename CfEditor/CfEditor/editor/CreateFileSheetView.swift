import SwiftUI

struct CreateFileSheetView: View {
    var initialFileName: String
    var onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var fileName: String

    init(initialFileName: String = "untitled", onConfirm: @escaping (String) -> Void) {
        self.initialFileName = initialFileName
        self.onConfirm = onConfirm
        self._fileName = State(initialValue: initialFileName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("文件名", text: $fileName)
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                } header: {
                    Text("File Name")
                } footer: {
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
                        Text("Other files will be added .txt as suffix automatically.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("New File")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let inputName = fileName.isEmpty ? initialFileName : fileName
                        let finalName = processFileName(inputName)
                        onConfirm(finalName)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
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

#if DEBUG
struct CreateFileSheetView_Previews: PreviewProvider {
    static var previews: some View {
        CreateFileSheetView { name in
            print("Creating file: \(name)")
        }
    }
}
#endif
