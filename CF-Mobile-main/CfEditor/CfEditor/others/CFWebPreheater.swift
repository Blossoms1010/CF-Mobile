import Foundation
import WebKit

/// 在后台用 WKWebView 预热 Codeforces 会话（触发 Cloudflare JS 挑战、写入站点 Cookie），
/// 以便 URLSession 随后请求更稳定。不会呈现任何 UI。
/// 注意：若遇到验证码类挑战，仍需要用户交互，本预热仅能处理无需交互的 JS/跳转类挑战。
final class CFWebPreheater: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var didFinishOrFail = false

    private override init() {}

    static let shared = CFWebPreheater()

    /// 预热提交相关页面。会按顺序访问首页与目标页面，并在每步结束后同步 Cookie。
    /// - Returns: 是否成功完成至少一次导航（用于判断是否值得重试业务请求）。
    @discardableResult
    func preheatForSubmit(contestId: Int, index: String, timeout: TimeInterval = 8.0) async -> Bool {
        let normalized = index.uppercased()
        let home = URL(string: "https://codeforces.com")!
        let submit = URL(string: "https://codeforces.com/contest/\(contestId)/submit?submittedProblemIndex=\(normalized)")!
        var ok = false
        if await loadSilently(url: home, timeout: timeout * 0.5) { ok = true }
        _ = await CFCookieBridge.shared.syncFromWKToHTTPCookieStorage()
        if await loadSilently(url: submit, timeout: timeout * 0.5) { ok = true }
        _ = await CFCookieBridge.shared.syncFromWKToHTTPCookieStorage()
        return ok
    }

    /// 通用静默加载入口
    private func loadSilently(url: URL, timeout: TimeInterval) async -> Bool {
        await MainActor.run {
            // 复用统一的数据存储，确保与可见 WebView/URLSession 共用 Cookie
            let cfg = WKWebViewConfiguration()
            cfg.websiteDataStore = WebDataStoreProvider.shared.currentStore()
            if #available(iOS 14.0, *) {
                cfg.defaultWebpagePreferences.allowsContentJavaScript = true
                cfg.defaultWebpagePreferences.preferredContentMode = .mobile
            }
            let web = WKWebView(frame: .zero, configuration: cfg)
            web.navigationDelegate = self
            // 不设置自定义 UA，沿用系统默认（更兼容 Cloudflare）
            self.webView = web
            self.didFinishOrFail = false
            var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            // 带上基础浏览器式头部
            req.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")
            req.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
            req.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
            req.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
            req.setValue("?1", forHTTPHeaderField: "Sec-Fetch-User")
            web.load(req)
        }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if didFinishOrFail { break }
        }
        await MainActor.run { self.webView = nil }
        return didFinishOrFail
    }

    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        didFinishOrFail = true
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        didFinishOrFail = true
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        didFinishOrFail = true
    }
}


