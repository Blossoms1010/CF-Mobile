import Foundation

/// 文件类型枚举
enum FileType: String, CaseIterable {
    case cpp = "C++"
    case java = "Java"
    case python = "Python"
    case txt = "TXT"
    case other = "其他"
    
    /// 根据文件扩展名判断文件类型
    static func from(fileExtension: String) -> FileType {
        let lowercased = fileExtension.lowercased()
        switch lowercased {
        case "cpp", "cc", "cxx", "c++", "hpp", "h", "hxx":
            return .cpp
        case "java":
            return .java
        case "py", "pyw", "pyi":
            return .python
        case "txt":
            return .txt
        default:
            return .other
        }
    }
    
    /// 文件类型对应的图标
    var iconName: String {
        switch self {
        case .cpp:
            return "doc.text.fill"
        case .java:
            return "cup.and.saucer.fill"
        case .python:
            return "chevron.left.forwardslash.chevron.right"
        case .txt:
            return "doc.plaintext.fill"
        case .other:
            return "doc"
        }
    }
    
    /// 文件类型对应的颜色
    var color: String {
        switch self {
        case .cpp:
            return "blue"
        case .java:
            return "orange"
        case .python:
            return "green"
        case .txt:
            return "gray"
        case .other:
            return "secondary"
        }
    }
}

/// 文件信息结构体
struct FileInfo {
    let url: URL
    let name: String
    let size: Int64?
    let fileType: FileType
    let modificationDate: Date?
    let isDirectory: Bool
    
    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        
        // 获取文件属性
        let resourceValues = try? url.resourceValues(forKeys: [
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey
        ])
        
        self.isDirectory = resourceValues?.isDirectory ?? false
        self.size = resourceValues?.fileSize.map { Int64($0) }
        self.modificationDate = resourceValues?.contentModificationDate
        
        // 判断文件类型
        if self.isDirectory {
            self.fileType = .other
        } else {
            let fileExtension = url.pathExtension
            self.fileType = FileType.from(fileExtension: fileExtension)
        }
    }
    
    /// 格式化文件大小显示
    var formattedSize: String {
        guard !isDirectory, let size = size else {
            return isDirectory ? "Folder" : "Unknown Size"
        }
        
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    /// 文件类型显示文本（只对支持的类型显示）
    var typeDisplayText: String? {
        guard !isDirectory && fileType != .other else {
            return nil
        }
        return fileType.rawValue
    }
    
    /// 获取文件图标名称
    var iconName: String {
        if isDirectory {
            return "folder.fill"
        } else {
            return fileType.iconName
        }
    }
    
    /// 获取文件图标颜色
    var iconColor: String {
        if isDirectory {
            return "blue"
        } else {
            return fileType.color
        }
    }
}

/// 文件大小格式化扩展
extension ByteCountFormatter {
    static let fileSize: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()
}
