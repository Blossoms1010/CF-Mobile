import SwiftUI
import WebKit

// WebView管理器，确保WebView在视图重建时保持状态
class OIWikiWebViewManager: ObservableObject {
    let webView = WKWebView()
    @Published var isLoading = true
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var hasLoaded = false
}

struct OIWikiView: View {
    @StateObject private var webViewManager = OIWikiWebViewManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // 导航工具栏
            HStack {
                Button(action: { webViewManager.webView.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(webViewManager.canGoBack ? .primary : .secondary)
                }
                .disabled(!webViewManager.canGoBack)
                
                Button(action: { webViewManager.webView.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(webViewManager.canGoForward ? .primary : .secondary)
                }
                .disabled(!webViewManager.canGoForward)
                
                Spacer()
                
                Button(action: { webViewManager.webView.reload() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                }
                
                Button(action: { 
                    if let url = URL(string: "https://oi-wiki.org") {
                        webViewManager.webView.load(URLRequest(url: url))
                    }
                }) {
                    Image(systemName: "house")
                        .font(.title2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(UIColor.separator)),
                alignment: .bottom
            )
            
            // WebView容器
            ZStack {
                OIWikiWebViewRepresentable(
                    webView: webViewManager.webView,
                    isLoading: $webViewManager.isLoading,
                    canGoBack: $webViewManager.canGoBack,
                    canGoForward: $webViewManager.canGoForward
                )
                
                if webViewManager.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("正在加载 OI Wiki...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
                }
            }
        }
        .navigationTitle("OI Wiki")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            // 只在第一次加载时才请求网页，之后保持状态
            if !webViewManager.hasLoaded {
                loadOIWiki()
                webViewManager.hasLoaded = true
            }
        }
    }
    
    private func loadOIWiki() {
        guard let url = URL(string: "https://oi-wiki.org") else { return }
        webViewManager.webView.load(URLRequest(url: url))
    }
}

struct OIWikiWebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // 配置WebView设置
        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        #if !os(macOS)
        webView.configuration.allowsInlineMediaPlayback = true
        #endif
        webView.configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // 设置用户代理，避免移动端适配问题
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 更新导航状态
        DispatchQueue.main.async {
            canGoBack = uiView.canGoBack
            canGoForward = uiView.canGoForward
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: OIWikiWebViewRepresentable
        
        init(_ parent: OIWikiWebViewRepresentable) {
            self.parent = parent
        }
        
        // 控制导航，只允许在oi-wiki.org域名内跳转
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            
            // 允许的域名
            let allowedHosts = ["oi-wiki.org", "www.oi-wiki.org"]
            
            if let host = url.host, allowedHosts.contains(host) {
                decisionHandler(.allow)
            } else {
                // 禁止跳转到外部网站
                decisionHandler(.cancel)
                print("阻止跳转到外部链接: \(url)")
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        // *** 修改部分：移除了所有JavaScript注入 ***
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
            
            // 这里不再注入任何脚本
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
        
        // 禁止打开新窗口
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // 在当前WebView中加载，而不是创建新窗口
            if let url = navigationAction.request.url {
                if let host = url.host, ["oi-wiki.org", "www.oi-wiki.org"].contains(host) {
                    webView.load(navigationAction.request)
                }
            }
            return nil
        }
    }
}

#Preview {
    NavigationView {
        OIWikiView()
    }
}