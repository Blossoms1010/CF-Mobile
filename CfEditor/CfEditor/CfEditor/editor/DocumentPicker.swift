import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

struct DocumentPicker: View {
    var onPick: (URL?) -> Void
    
    var body: some View {
        Button("选择文件") {
            openDocumentPicker()
        }
    }
    
    private func openDocumentPicker() {
        #if canImport(AppKit)
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [UTType.item]
        
        openPanel.begin { response in
            if response == .OK {
                onPick(openPanel.url)
            } else {
                onPick(nil)
            }
        }
        #else
        // iOS implementation would go here if needed
        onPick(nil)
        #endif
    }
}


// 选择文件夹
struct FolderPicker: View {
    var onPick: (URL?) -> Void
    
    var body: some View {
        Button("Choose Folder") {
            openFolderPicker()
        }
    }
    
    private func openFolderPicker() {
        #if canImport(AppKit)
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowedContentTypes = [UTType.folder]
        
        openPanel.begin { response in
            if response == .OK {
                onPick(openPanel.url)
            } else {
                onPick(nil)
            }
        }
        #else
        // iOS implementation would go here if needed
        onPick(nil)
        #endif
    }
}


