//
//  CfEditorApp.swift
//  CfEditor
//
//  Created by 赵勃翔 on 2025/8/16.
//

import SwiftUI
import SwiftData
import WebKit

extension Notification.Name {
    static let appReloadRequested = Notification.Name("app.reload.requested")
    static let openEditorFileRequested = Notification.Name("editor.open.file.requested")
}

@main
struct CfEditorApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var reloadKey = UUID()
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    
    private var appTheme: AppTheme {
        AppTheme(rawValue: appThemeRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(reloadKey)
                .preferredColorScheme(appTheme.colorScheme)
                .onReceive(NotificationCenter.default.publisher(for: .appReloadRequested)) { _ in
                    reloadKey = UUID()
                }
                .task {
                    // 启动后开始监听 WKWebView Cookie 变化，保持与 URLSession 同步
                    CFCookieBridge.shared.startObserving()
                    // 若本地未有 handle，尝试从已存在的 Codeforces 登录 Cookie 中恢复（免二次登录）
                    await CFCookieBridge.shared.syncFromWKToHTTPCookieStorage()
                    let existing = UserDefaults.standard.string(forKey: "cfHandle")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let cookies = HTTPCookieStorage.shared.cookies ?? []
                    if let xUser = cookies.first(where: { $0.name == "X-User" && $0.domain.contains("codeforces.com") })?.value
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                        !xUser.isEmpty,
                        Self.isValidHandle(xUser) {
                        // 启动同步：若本地没有 handle 或与 Cookie 中登录用户不一致，则覆盖为 Cookie 的 handle
                        if existing.isEmpty || existing.lowercased() != xUser.lowercased() {
                            UserDefaults.standard.set(xUser, forKey: "cfHandle")
                        }
                    }
                }
                // 全局监听 Cookie 变化：一旦 X-User 变更，立即同步到本地 handle，保证应用内统一登录态
                .onReceive(NotificationCenter.default.publisher(for: .NSHTTPCookieManagerCookiesChanged)) { _ in
                    Task {
                        if let h = await CFCookieBridge.shared.readCurrentCFHandleFromWK(), Self.isValidHandle(h) {
                            let existing = (UserDefaults.standard.string(forKey: "cfHandle") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                            if existing.lowercased() != h.lowercased() {
                                await MainActor.run { UserDefaults.standard.set(h, forKey: "cfHandle") }
                            }
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

private extension CfEditorApp {
    static func isValidHandle(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t.count <= 24 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return t.rangeOfCharacter(from: allowed.inverted) == nil
    }
}
