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
    @Environment(\.colorScheme) var colorScheme
    
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
                    canGoForward: $webViewManager.canGoForward,
                    colorScheme: colorScheme
                )
                .padding(.bottom, 60) // 留出 TabBar 空间
                
                if webViewManager.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading OI Wiki...")
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
    let colorScheme: ColorScheme
    
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
        
        // 检查系统主题是否发生了变化
        if let previous = context.coordinator.previousColorScheme, previous == colorScheme {
            // 主题没有变化，不执行任何操作（允许用户手动切换）
            return
        }
        
        // 系统主题发生了变化，更新 OI Wiki 主题
        context.coordinator.previousColorScheme = colorScheme
        
        let targetTheme = colorScheme == .dark ? "slate" : "default"
        let script = """
        (function() {
            try {
                // Material for MkDocs 的主题切换
                var root = document.documentElement;
                
                // 查找所有主题选项的 input 元素
                var inputs = document.querySelectorAll('input[data-md-color-scheme]');
                var targetInput = null;
                
                // 找到目标主题的 input（slate 是深色，default 是浅色）
                for (var i = 0; i < inputs.length; i++) {
                    if (inputs[i].getAttribute('data-md-color-scheme') === '\(targetTheme)') {
                        targetInput = inputs[i];
                        break;
                    }
                }
                
                // 如果找到了对应的 input 且未被选中，则点击它
                if (targetInput && !targetInput.checked) {
                    targetInput.click();
                } else if (!targetInput) {
                    // 如果没找到 input，直接修改 attribute
                    root.setAttribute('data-md-color-scheme', '\(targetTheme)');
                    
                    // 同时更新 localStorage 以保持状态
                    var palette = JSON.parse(localStorage.getItem('.__palette') || '{}');
                    palette.index = '\(targetTheme)' === 'slate' ? 1 : 0;
                    localStorage.setItem('.__palette', JSON.stringify(palette));
                }
            } catch(e) {
                console.log('Theme toggle error:', e);
            }
        })();
        """
        uiView.evaluateJavaScript(script, completionHandler: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: OIWikiWebViewRepresentable
        var previousColorScheme: ColorScheme?
        
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
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
            
            // 页面首次加载时，初始化主题为系统主题
            if previousColorScheme == nil {
                previousColorScheme = parent.colorScheme
                
                let targetTheme = parent.colorScheme == .dark ? "slate" : "default"
                
                // 延迟执行，确保页面 DOM 完全加载
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let script = """
                    (function() {
                        try {
                            // Material for MkDocs 的主题切换
                            var root = document.documentElement;
                            
                            // 查找所有主题选项的 input 元素
                            var inputs = document.querySelectorAll('input[data-md-color-scheme]');
                            var targetInput = null;
                            
                            // 找到目标主题的 input（slate 是深色，default 是浅色）
                            for (var i = 0; i < inputs.length; i++) {
                                if (inputs[i].getAttribute('data-md-color-scheme') === '\(targetTheme)') {
                                    targetInput = inputs[i];
                                    break;
                                }
                            }
                            
                            // 如果找到了对应的 input 且未被选中，则点击它
                            if (targetInput && !targetInput.checked) {
                                targetInput.click();
                            } else if (!targetInput) {
                                // 如果没找到 input，直接修改 attribute
                                root.setAttribute('data-md-color-scheme', '\(targetTheme)');
                                
                                // 同时更新 localStorage 以保持状态
                                var palette = JSON.parse(localStorage.getItem('.__palette') || '{}');
                                palette.index = '\(targetTheme)' === 'slate' ? 1 : 0;
                                localStorage.setItem('.__palette', JSON.stringify(palette));
                            }
                        } catch(e) {
                            console.log('Theme toggle error:', e);
                        }
                    })();
                    """
                    webView.evaluateJavaScript(script, completionHandler: nil)
                }
            }
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
