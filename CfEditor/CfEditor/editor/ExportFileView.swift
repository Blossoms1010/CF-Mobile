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
        case "cpp": return "cpp"
        case "python": return "python"
        case "java": return "java"
        case "plaintext": return "txt"
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
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Header Section
                    HStack(spacing: 16) {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .font(.system(size: 50, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Export File")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Choose destination and file name")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 8)
                    
                    // File Name Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("File Name")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        TextField("Enter file name...", text: $editableFileName)
                            .font(.system(size: 16, design: .rounded))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.3)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2
                                            )
                                    )
                            )
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.2), Color.cyan.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    
                    // File Info Section
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("File Info")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(spacing: 12) {
                            infoRow(icon: "text.bubble.fill", title: "Language", value: languageDisplayName, gradient: [.blue, .cyan])
                            infoRow(icon: "doc.text.fill", title: "Size", value: fileSizeString, gradient: [.orange, .yellow])
                            
                            if let modificationDate = fileModificationDate {
                                infoRow(icon: "clock.fill", title: "Modified", value: modificationDate, gradient: [.purple, .pink])
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.green.opacity(0.2), Color.mint.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    
                    // Preview Section
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.indigo, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("Preview")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        ScrollView {
                            Text(fileContent.isEmpty ? "（Empty File）" : fileContent)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(uiColor: .systemBackground))
                                )
                        }
                        .frame(maxHeight: 300)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.indigo.opacity(0.2), Color.purple.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button {
                            isShowingDocumentPicker = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Text("Choose Save Location")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .overlay(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(
                                color: Color.purple.opacity(0.4),
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                        }
                        .buttonStyle(PressEffectButtonStyle())
                        
                        Button {
                            onExportComplete(false, nil)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Text("Cancel")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                
                                Spacer()
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.red.opacity(0.3), lineWidth: 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.red.opacity(0.05))
                                    )
                            )
                        }
                        .buttonStyle(PressEffectButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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
    
    // MARK: - Info Row
    @ViewBuilder
    private func infoRow(icon: String, title: String, value: String, gradient: [Color]) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient.map { $0.opacity(0.15) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
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
