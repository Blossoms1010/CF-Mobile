import Foundation
import WebKit

/// 统一管理 WKWebsiteDataStore，确保全局共享同一个“非持久”实例，
/// 避免在不同位置各自创建 .nonPersistent() 导致 Cookie/存储彼此不通。
final class WebDataStoreProvider {
    static let shared = WebDataStoreProvider()
    private init() {}

    // 单例的非持久数据存储（内存中，应用退出即清空）
    private let ephemeralStore: WKWebsiteDataStore = .nonPersistent()

    func currentStore() -> WKWebsiteDataStore {
        if UserDefaults.standard.bool(forKey: "web.useEphemeral") {
            return ephemeralStore
        } else {
            return .default()
        }
    }

    func persistentStore() -> WKWebsiteDataStore { .default() }
    func sharedEphemeralStore() -> WKWebsiteDataStore { ephemeralStore }
}


