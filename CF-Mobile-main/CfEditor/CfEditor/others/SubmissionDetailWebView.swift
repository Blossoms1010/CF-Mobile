import SwiftUI
import WebKit

struct SubmissionDetailWebView: UIViewRepresentable {
    let url: URL
    let targetURLString: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
            config.defaultWebpagePreferences.preferredContentMode = .mobile
        }
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.websiteDataStore = WebDataStoreProvider.shared.currentStore()

        // Basic dark-mode and rendering fixes
        let css = """
        (function(){try{
          var style=document.createElement('style');
          style.textContent=':root{color-scheme: light dark;} html,body{background:transparent !important} img,svg{filter:none !important;m ix-blend-mode:normal !important}';
          document.documentElement.appendChild(style);
        }catch(e){}})();
        """
        let script = WKUserScript(source: css, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true

        // Initial load
        web.load(URLRequest(url: url))

        // Observe external reload requests
        context.coordinator.observeReload(for: web)
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private var reloadObserver: NSObjectProtocol?

        func observeReload(for webView: WKWebView) {
            reloadObserver = NotificationCenter.default.addObserver(forName: .init("SubmissionWebView.ReloadRequested"), object: nil, queue: .main) { _ in
                webView.reload()
            }
        }

        deinit { if let o = reloadObserver { NotificationCenter.default.removeObserver(o) } }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
            return nil
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}


