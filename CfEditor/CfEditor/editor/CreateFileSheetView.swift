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
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Icon and Title Section
                    HStack(spacing: 16) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 50, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("New File")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Choose a file name")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 8)
                    
                    // Input Section
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
                        
                        TextField("Enter file name...", text: $fileName)
                            .font(.system(size: 16, design: .rounded))
                            #if !os(macOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()
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
                    
                    // Help Section
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
                            
                            Text("Supported Languages")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            languageRow(icon: "c.circle.fill", title: "C/C++", extensions: ".c, .cpp, .cxx, .cc, .hpp, .h", gradient: [.blue, .cyan])
                            languageRow(icon: "cup.and.saucer.fill", title: "Java", extensions: ".java", gradient: [.orange, .red])
                            languageRow(icon: "chevron.left.forwardslash.chevron.right", title: "Python", extensions: ".py", gradient: [.green, .mint])
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                            
                            Text("Files without supported extensions will get .txt added")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.yellow.opacity(0.1))
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
                                            colors: [Color.green.opacity(0.2), Color.mint.opacity(0.2)],
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
                            let inputName = fileName.isEmpty ? initialFileName : fileName
                            let finalName = processFileName(inputName)
                            onConfirm(finalName)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Text("Create File")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .cyan],
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
                                color: Color.blue.opacity(0.4),
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                        }
                        .buttonStyle(PressEffectButtonStyle())
                        
                        Button {
                            dismiss()
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
        }
    }
    
    // MARK: - Language Row
    @ViewBuilder
    private func languageRow(icon: String, title: String, extensions: String, gradient: [Color]) -> some View {
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
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(extensions)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
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
