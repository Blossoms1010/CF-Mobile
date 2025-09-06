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
    @State private var isLoading: Bool = true

    // 当前浏览目录（默认为应用文档目录）
    @State private var currentDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    @State private var rootDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    // 导入
    @State private var isImportPresented: Bool = false
    // 打开文件夹
    @State private var isFolderPickerPresented: Bool = false
    // 新建/重命名
    // 新建文件/文件夹相关状态
    @State private var isCreateSheetPresented: Bool = false
    @State private var pendingName: String = ""
    @State private var isCreatingFolder: Bool = false
    
    // 重命名相关状态
    @State private var isRenameSheetPresented: Bool = false
    @State private var renameTargetURL: URL? = nil
    // 删除
    @State private var deleteErrorMessage: String = ""
    @State private var showDeleteError: Bool = false
    
    // 重命名错误处理
    @State private var renameErrorMessage: String = ""
    @State private var showRenameError: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if files.isEmpty {
                    VStack(spacing: 16) {
                        ContentUnavailableView("没有文件", systemImage: "folder")
                    }
                } else {
                    List(files, id: \.self) { url in
                        Button {
                            if isDirectory(url) {
                                currentDirectory = url
                                loadFiles()
                            } else {
                                onSelect(url)
                                dismiss()
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: iconName(for: url))
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(url.lastPathComponent)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    if let date = modificationDate(for: url) {
                                        Text("上次修改：\(Self.shortDateFormatter.string(from: date))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.systemGray6))
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .contextMenu {
                            Button {
                                // 重命名
                                prepareRename(for: url)
                            } label: { Label("重命名", systemImage: "pencil") }
                            Button(role: .destructive) {
                                performDelete(url: url)
                            } label: { Label("删除", systemImage: "trash") }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                performDelete(url: url)
                            } label: { Label("删除", systemImage: "trash") }
                            Button {
                                prepareRename(for: url)
                            } label: { Label("重命名", systemImage: "pencil") }
                            .tint(.blue)
                        }
                    }
                }
            }
            .navigationTitle("文件管理")
            .listStyle(.plain)
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
                        } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("返回")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            // 准备新建文件
                            isCreatingFolder = false
                            pendingName = suggestedFileName()
                            isCreateSheetPresented = true
                        } label: { Label("新建文件", systemImage: "doc.badge.plus") }
                        Button {
                            // 准备新建文件夹
                            isCreatingFolder = true
                            pendingName = suggestedFolderName()
                            isCreateSheetPresented = true
                        } label: { Label("新建文件夹", systemImage: "folder.badge.plus") }
                        Divider()
                        Button {
                            isImportPresented = true
                        } label: { Label("打开文件", systemImage: "doc") }
                        Button {
                            isFolderPickerPresented = true
                        } label: { Label("打开文件夹", systemImage: "folder") }
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel("添加")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onAppear(perform: loadFiles)
        // 导入
        .sheet(isPresented: $isImportPresented) {
            DocumentPicker { importedURL in
                if let importedURL {
                    // 复制到文档目录
                    let dest = uniqueURL(forProposedName: importedURL.lastPathComponent)
                    do {
                        if FileManager.default.fileExists(atPath: dest.path) {
                            try? FileManager.default.removeItem(at: dest)
                        }
                        try FileManager.default.copyItem(at: importedURL, to: dest)
                        loadFiles()
                        onSelect(dest)
                        dismiss()
                    } catch {
                        // 忽略错误
                    }
                }
            }
        }
        // 打开文件夹
        .sheet(isPresented: $isFolderPickerPresented) {
            FolderPicker { pickedFolder in
                if let folder = pickedFolder {
                    rootDirectory = folder
                    currentDirectory = folder
                    loadFiles()
                }
            }
        }
        // 新建文件/文件夹
        .sheet(isPresented: $isCreateSheetPresented) {
            SaveFileSheetView(initialFileName: pendingName, isCreatingFolder: isCreatingFolder, isRenaming: false) { name in
                if isCreatingFolder {
                    // 新建文件夹
                    performCreateFolder(name: name)
                } else {
                    // 新建文件
                    performCreateFile(name: name)
                }
                // 重置状态
                isCreatingFolder = false
            }
        }
        // 重命名
        .sheet(isPresented: $isRenameSheetPresented) {
            SaveFileSheetView(
                initialFileName: renameTargetURL?.lastPathComponent ?? "", 
                isCreatingFolder: renameTargetURL != nil ? isDirectory(renameTargetURL!) : false, 
                isRenaming: true
            ) { name in
                if let target = renameTargetURL {
                    performRename(from: target, to: name)
                }
                // 重置状态
                renameTargetURL = nil
            }
        }
        // 删除错误提示
        .alert("删除失败", isPresented: $showDeleteError) {
            Button("确定") { }
        } message: {
            Text(deleteErrorMessage)
        }
        // 重命名错误提示
        .alert("重命名失败", isPresented: $showRenameError) {
            Button("确定") { }
        } message: {
            Text(renameErrorMessage)
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
        if let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey], options: [.skipsHiddenFiles]) {
            files = contents.sorted { (lhs, rhs) in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return l > r
            }
        } else {
            files = []
        }
        if didStart {
            dir.stopAccessingSecurityScopedResource()
        }
        isLoading = false
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
        "新建文件夹"
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
    
    // MARK: - 重命名和删除功能
    
    /// 准备重命名操作
    private func prepareRename(for url: URL) {
        // 设置重命名相关状态
        renameTargetURL = url
        isRenameSheetPresented = true
    }
    
    /// 执行重命名操作
    private func performRename(from sourceURL: URL, to newName: String) {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            renameErrorMessage = "文件名不能为空"
            showRenameError = true
            return
        }
        
        // 验证文件名是否合法
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        if newName.rangeOfCharacter(from: invalidChars) != nil {
            renameErrorMessage = "文件名包含非法字符：/ \\ : * ? \" < > |"
            showRenameError = true
            return
        }
        
        let finalName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let destinationURL = sourceURL.deletingLastPathComponent().appendingPathComponent(finalName)
        
        // 检查目标文件是否已存在
        if FileManager.default.fileExists(atPath: destinationURL.path) && destinationURL != sourceURL {
            renameErrorMessage = "已存在同名的文件或文件夹"
            showRenameError = true
            return
        }
        
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            loadFiles()
        } catch {
            renameErrorMessage = "重命名失败：\(error.localizedDescription)"
            showRenameError = true
        }
    }
    
    
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



