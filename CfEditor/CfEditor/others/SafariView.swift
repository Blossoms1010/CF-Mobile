import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct SafariView: View {
    let url: URL
    
    var body: some View {
        Button("在浏览器中打开") {
            openInBrowser()
        }
        .onAppear {
            openInBrowser()
        }
    }
    
    private func openInBrowser() {
        #if canImport(AppKit)
        NSWorkspace.shared.open(url)
        #else
        // iOS implementation would go here if needed
        #endif
    }
}


