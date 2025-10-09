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
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    .padding(.top, 8)
                    
                    inputSection
                    
                    if !isCreatingFolder {
                        helpSection
                    }
                    
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - View Components
    private var headerSection: some View {
        HStack(spacing: 16) {
            Image(systemName: getHeaderIcon())
                .font(.system(size: 50, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: getHeaderGradientColors(),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(getNavigationTitle())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: getHeaderGradientColors(),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text(isRenaming ? "Enter new name" : "Choose a name")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: isCreatingFolder ? "folder.fill" : "doc.text.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: getHeaderGradientColors(),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text(isCreatingFolder ? "Folder Name" : "File Name")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            TextField("Enter name...", text: $name)
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
                                        colors: getHeaderGradientColors().map { $0.opacity(0.3) },
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
                                colors: getHeaderGradientColors().map { $0.opacity(0.2) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private var helpSection: some View {
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
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                let inputName = name.isEmpty ? initialFileName : name
                let finalName = shouldProcessFileName() ? processFileName(inputName) : inputName.trimmingCharacters(in: .whitespacesAndNewlines)
                onConfirm(finalName)
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: getConfirmIcon())
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(getConfirmButtonText())
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: getHeaderGradientColors(),
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
                    color: getHeaderGradientColors()[0].opacity(0.4),
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
    
    private func getHeaderIcon() -> String {
        if isCreatingFolder {
            return isRenaming ? "folder.fill.badge.gearshape" : "folder.badge.plus"
        } else {
            return isRenaming ? "doc.badge.gearshape" : "doc.badge.plus"
        }
    }
    
    private func getConfirmIcon() -> String {
        if isRenaming {
            return "checkmark.circle.fill"
        } else {
            return isCreatingFolder ? "folder.badge.plus" : "plus.circle.fill"
        }
    }
    
    private func getHeaderGradientColors() -> [Color] {
        if isCreatingFolder {
            return [.purple, .pink]
        } else {
            return [.blue, .cyan]
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


