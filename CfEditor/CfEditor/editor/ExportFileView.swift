import SwiftUI
import UniformTypeIdentifiers

struct ExportFileView: View {
    let fileName: String
    let fileContent: String
    let language: String
    let fileURL: URL?
    let onExportComplete: (Bool, String?) -> Void
    
    @State private var isShowingDocumentPicker = false
    @State private var editableFileName: String
    
    init(fileName: String, fileContent: String, language: String, fileURL: URL? = nil, onExportComplete: @escaping (Bool, String?) -> Void) {
        self.fileName = fileName
        self.fileContent = fileContent
        self.language = language
        self.fileURL = fileURL
        self.onExportComplete = onExportComplete
        self._editableFileName = State(initialValue: fileName)
    }
    
    // 计算属性
    private var languageDisplayName: String {
        switch language {
        case "cpp": return "C++"
        case "python": return "Python"
        case "java": return "Java"
        case "plaintext": return "纯文本"
        default: return language.capitalized
        }
    }
    
    private var fileSizeString: String {
        let bytes = fileContent.utf8.count
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
    
    private var fileModificationDate: String? {
        guard let fileURL = fileURL else { return nil }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let modificationDate = attributes[.modificationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                formatter.locale = Locale(identifier: "zh_CN")
                return formatter.string(from: modificationDate)
            }
        } catch {
            print("获取文件修改时间失败: \(error)")
        }
        
        return nil
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("导出文件")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("选择要保存的位置和文件名")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("文件名")
                        .font(.headline)
                    
                    TextField("输入文件名", text: $editableFileName)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                // 文件信息
                VStack(alignment: .leading, spacing: 12) {
                    Text("文件信息")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("语言:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(languageDisplayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("大小:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(fileSizeString)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        if let modificationDate = fileModificationDate {
                            HStack {
                                Text("修改时间:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(modificationDate)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("预览")
                        .font(.headline)
                    
                    ScrollView {
                        Text(fileContent.isEmpty ? "（空文件）" : fileContent)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 150)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: {
                        isShowingDocumentPicker = true
                    }) {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                            Text("选择保存位置")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button("取消") {
                        onExportComplete(false, nil)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
            }
            .padding()
            .sheet(isPresented: $isShowingDocumentPicker) {
                DocumentPickerView(
                    fileName: editableFileName,
                    fileContent: fileContent,
                    language: language,
                    onComplete: onExportComplete
                )
            }
        }
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {
    let fileName: String
    let fileContent: String
    let language: String
    let onComplete: (Bool, String?) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [createTemporaryFileURL()], asCopy: true)
        picker.delegate = context.coordinator
        picker.modalPresentationStyle = .formSheet
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createTemporaryFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try fileContent.write(to: tempFileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error creating temporary file: \(error)")
        }
        
        return tempFileURL
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onComplete(true, "文件已成功导出到所选位置")
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onComplete(false, "导出已取消")
        }
    }
}

#Preview {
    ExportFileView(
        fileName: "example.cpp",
        fileContent: "#include <iostream>\nusing namespace std;\n\nint main() {\n    cout << \"Hello World!\" << endl;\n    return 0;\n}",
        language: "cpp",
        fileURL: nil
    ) { success, message in
        print("Export result: \(success), message: \(message ?? "nil")")
    }
}
