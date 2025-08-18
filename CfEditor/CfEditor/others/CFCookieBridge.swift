import Foundation
import WebKit

/// 将 WKWebView 的 Cookie 与 URLSession 使用的 HTTPCookieStorage 进行同步，
/// 以便网络层能携带网站登录态（用于 Codeforces 网页端接口，例如提交等）。
final class CFCookieBridge: NSObject, WKHTTPCookieStoreObserver {
    static let shared = CFCookieBridge()
    private override init() {}

    private var observing = false
    private var lastObservedEphemeral: Bool?

    func startObserving() {
        // 与 WebView 配置保持一致：若使用临时会话则监听对应的 cookieStore
        let currentEphemeral = UserDefaults.standard.bool(forKey: "web.useEphemeral")
        let currentStore: WKHTTPCookieStore = currentEphemeral ? WKWebsiteDataStore.nonPersistent().httpCookieStore : WKWebsiteDataStore.default().httpCookieStore

        if observing {
            // 若会话模式已切换，则重新绑定监听的 cookieStore
            if lastObservedEphemeral != currentEphemeral {
                let prevStore: WKHTTPCookieStore = (lastObservedEphemeral ?? false) ? WKWebsiteDataStore.nonPersistent().httpCookieStore : WKWebsiteDataStore.default().httpCookieStore
                prevStore.remove(self)
                currentStore.add(self)
                lastObservedEphemeral = currentEphemeral
                Task { await syncFromWKToHTTPCookieStorage() }
            }
            return
        }

        currentStore.add(self)
        observing = true
        lastObservedEphemeral = currentEphemeral
        Task { await syncFromWKToHTTPCookieStorage() }
    }

    func stopObserving() {
        guard observing else { return }
        let store: WKHTTPCookieStore
        if UserDefaults.standard.bool(forKey: "web.useEphemeral") {
            store = WKWebsiteDataStore.nonPersistent().httpCookieStore
        } else {
            store = WKWebsiteDataStore.default().httpCookieStore
        }
        store.remove(self)
        observing = false
        lastObservedEphemeral = nil
    }

    // MARK: - WKHTTPCookieStoreObserver
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task { await self.syncFromWKToHTTPCookieStorage() }
    }

    // MARK: - 同步方向：WK -> URLSession
    func syncFromWKToHTTPCookieStorage() async {
        let store: WKHTTPCookieStore
        if UserDefaults.standard.bool(forKey: "web.useEphemeral") {
            store = WKWebsiteDataStore.nonPersistent().httpCookieStore
        } else {
            store = WKWebsiteDataStore.default().httpCookieStore
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.getAllCookies { cookies in
                let shared = HTTPCookieStorage.shared
                for c in cookies {
                    shared.setCookie(c)
                }
                continuation.resume()
            }
        }
    }

    // MARK: - 同步方向：URLSession -> WK（通常不需要，但保留以备后续使用）
    func syncFromHTTPCookieStorageToWK() async {
        let store: WKHTTPCookieStore
        if UserDefaults.standard.bool(forKey: "web.useEphemeral") {
            store = WKWebsiteDataStore.nonPersistent().httpCookieStore
        } else {
            store = WKWebsiteDataStore.default().httpCookieStore
        }
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        for cookie in cookies {
            await withCheckedContinuation { (cc: CheckedContinuation<Void, Never>) in
                store.setCookie(cookie) { cc.resume() }
            }
        }
    }

    // MARK: - 读取当前 WK 会话中的 Codeforces 登录账号（X-User）
    /// 直接从当前使用的 WKHTTPCookieStore 读取 `X-User`，避免 HTTPCookieStorage 中存在旧值/重复导致的误判。
    /// 返回值为 handle（大小写按站点返回）。
    func readCurrentCFHandleFromWK() async -> String? {
        let store: WKHTTPCookieStore = UserDefaults.standard.bool(forKey: "web.useEphemeral")
            ? WKWebsiteDataStore.nonPersistent().httpCookieStore
            : WKWebsiteDataStore.default().httpCookieStore
        return await withCheckedContinuation { (cc: CheckedContinuation<String?, Never>) in
            store.getAllCookies { cookies in
                let candidates = cookies.filter { $0.name == "X-User" && $0.domain.lowercased().hasSuffix("codeforces.com") }
                if candidates.isEmpty {
                    cc.resume(returning: nil)
                    return
                }
                // 选取 expiresDate 最大（或无过期时间视为最大）的条目，避免旧条目干扰
                let chosen = candidates.max { a, b in
                    let da = a.expiresDate ?? .distantFuture
                    let db = b.expiresDate ?? .distantFuture
                    return da < db
                }
                cc.resume(returning: chosen?.value)
            }
        }
    }
}


