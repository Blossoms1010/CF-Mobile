import SwiftUI

struct FilesBrowserView: View {
    let onSelect: (URL) -> Void
    let onDelete: (URL) -> Void

    init(onSelect: @escaping (URL) -> Void, onDelete: @escaping (URL) -> Void = { _ in }) {
        self.onSelect = onSelect
        self.onDelete = onDelete
    }

    @Environment(\.dismiss) private var dismiss
    @State private var files: [URL] = []
    @State private var fileInfos: [FileInfo] = []
    @State private var isLoading: Bool = true

    // 当前浏览目录（默认为应用文档目录）
    @State private var currentDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    @State private var rootDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    // 新建文件/文件夹相关状态
    @State private var isCreateFileSheetPresented: Bool = false
    @State private var isCreateFolderSheetPresented: Bool = false
    
    // 删除
    @State private var deleteErrorMessage: String = ""
    @State private var showDeleteError: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if fileInfos.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 60, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("No Files")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Create a new file or folder to get started")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                } else {
                    List(fileInfos, id: \.url) { fileInfo in
                        Button {
                            if fileInfo.isDirectory {
                                currentDirectory = fileInfo.url
                                loadFiles()
                            } else {
                                onSelect(fileInfo.url)
                                dismiss()
                            }
                        } label: {
                            HStack(alignment: .center, spacing: 14) {
                                // 图标
                                Image(systemName: fileInfo.iconName)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: gradientFromString(fileInfo.iconColor),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: gradientFromString(fileInfo.iconColor).map { $0.opacity(0.15) },
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    // 文件名
                                    Text(fileInfo.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    // 修改时间
                                    if let date = fileInfo.modificationDate {
                                        HStack(spacing: 6) {
                                            Image(systemName: "clock")
                                                .font(.system(size: 11))
                                            Text(Self.shortDateFormatter.string(from: date))
                                                .font(.system(size: 12))
                                        }
                                        .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer(minLength: 0)
                                
                                // 右侧信息栏
                                VStack(alignment: .trailing, spacing: 6) {
                                    // 文件大小
                                    Text(fileInfo.formattedSize)
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                    
                                    // 文件类型标签（仅对支持的类型显示）
                                    if let typeText = fileInfo.typeDisplayText {
                                        Text(typeText)
                                            .font(.system(size: 11, weight: .semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: gradientFromString(fileInfo.iconColor).map { $0.opacity(0.2) },
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        )
                                                    )
                                            )
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: gradientFromString(fileInfo.iconColor),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    }
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: gradientFromString(fileInfo.iconColor).map { $0.opacity(0.2) },
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                    .shadow(
                                        color: gradientFromString(fileInfo.iconColor)[0].opacity(0.1),
                                        radius: 4,
                                        x: 0,
                                        y: 2
                                    )
                            )
                        }
                        .buttonStyle(PressEffectButtonStyle())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .contextMenu {
                            Button(role: .destructive) {
                                performDelete(url: fileInfo.url)
                            } label: { Label("删除", systemImage: "trash") }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                performDelete(url: fileInfo.url)
                            } label: { Label("删除", systemImage: "trash") }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("File Browser")
            .listStyle(.plain)
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if currentDirectory != rootDirectory {
                        Button {
                            // 返回上一级，但不越过根目录
                            let parent = currentDirectory.deletingLastPathComponent()
                            if parent.path.hasPrefix(rootDirectory.path) {
                                currentDirectory = parent
                            } else {
                                currentDirectory = rootDirectory
                            }
                            loadFiles()
                        } label: { 
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .accessibilityLabel("back")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            // 准备新建文件
                            isCreateFileSheetPresented = true
                        } label: { 
                            Label("New File", systemImage: "doc.badge.plus")
                        }
                        Button {
                            // 准备新建文件夹
                            isCreateFolderSheetPresented = true
                        } label: { 
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                    } label: { 
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .accessibilityLabel("add")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
        }
        .onAppear(perform: loadFiles)
        // 新建文件
        .sheet(isPresented: $isCreateFileSheetPresented) {
            CreateFileSheetView(initialFileName: suggestedFileName()) { name in
                performCreateFile(name: name)
            }
        }
        // 新建文件夹
        .sheet(isPresented: $isCreateFolderSheetPresented) {
            CreateFolderSheetView(initialFolderName: suggestedFolderName()) { name in
                performCreateFolder(name: name)
            }
        }
        // 删除错误提示
        .alert("Failed to delete", isPresented: $showDeleteError) {
            Button("confirm") { }
        } message: {
            Text(deleteErrorMessage)
        }
    }

    private func modificationDate(for url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? nil
    }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private func loadFiles() {
        isLoading = true
        let dir = currentDirectory
        let didStart = dir.startAccessingSecurityScopedResource()
        if let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles]) {
            files = contents.sorted { (lhs, rhs) in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return l > r
            }
            // 创建 FileInfo 对象
            fileInfos = files.map { FileInfo(url: $0) }
        } else {
            files = []
            fileInfos = []
        }
        if didStart {
            dir.stopAccessingSecurityScopedResource()
        }
        isLoading = false
    }

    /// 将字符串转换为颜色
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "blue":
            return .blue
        case "orange":
            return .orange
        case "green":
            return .green
        case "gray":
            return .gray
        case "secondary":
            return .secondary
        default:
            return .primary
        }
    }
    
    /// 将字符串转换为渐变色数组
    private func gradientFromString(_ colorString: String) -> [Color] {
        switch colorString.lowercased() {
        case "blue":
            return [.blue, .cyan]
        case "orange":
            return [.orange, .yellow]
        case "green":
            return [.green, .mint]
        case "gray":
            return [.gray, .gray.opacity(0.7)]
        case "secondary":
            return [.secondary, .secondary.opacity(0.7)]
        default:
            return [.purple, .pink]
        }
    }
    
    private func iconName(for url: URL) -> String {
        if isDirectory(url) { return "folder" }
        let ext = url.pathExtension
        switch ext.lowercased() {
        case "cpp", "cc", "cxx": return "curlybraces"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "swift": return "swift"
        case "java": return "cup.and.saucer"
        case "js", "ts": return "chevron.left.forwardslash.chevron.right"
        case "txt": return "doc.text"
        default: return "doc"
        }
    }

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private func suggestedFileName() -> String {
        "untitled"
    }

    private func suggestedFolderName() -> String {
        "Folder"
    }

    private func uniqueURL(forProposedName name: String) -> URL {
        let base = currentDirectory.appendingPathComponent(name)
        return uniqueURL(for: base)
    }

    private func uniqueURL(for url: URL) -> URL {
        if !FileManager.default.fileExists(atPath: url.path) { return url }
        let ext = url.pathExtension
        var baseName = url.deletingPathExtension().lastPathComponent
        var index = 1
        while true {
            let candidateName = ext.isEmpty ? "\(baseName) (\(index))" : "\(baseName) (\(index)).\(ext)"
            let candidate = url.deletingLastPathComponent().appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    private func uniqueDirectoryURL(forProposedName name: String) -> URL {
        let base = currentDirectory.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: base.path) { return base }
        var index = 1
        while true {
            let candidate = currentDirectory.appendingPathComponent("\(name) (\(index))")
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
    
    // MARK: - 删除功能
    
    
    /// 执行删除操作
    private func performDelete(url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            loadFiles()
            onDelete(url)
        } catch {
            deleteErrorMessage = "删除失败：\(error.localizedDescription)"
            showDeleteError = true
        }
    }
    
    
    /// 执行创建文件夹
    private func performCreateFolder(name: String) {
        let folderURL = uniqueDirectoryURL(forProposedName: name)
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            loadFiles()
        } catch {
            // 可以添加错误处理
        }
    }
    
    /// 执行创建文件
    private func performCreateFile(name: String) {
        let dest = uniqueURL(forProposedName: name)
        FileManager.default.createFile(atPath: dest.path, contents: Data())
        loadFiles()
        onSelect(dest)
        dismiss()
    }
}



