import SwiftUI

struct BindCFAccountView: View {
    @AppStorage("cfHandle") private var handle: String = ""
    @StateObject private var webModel = WebViewModel(enableProblemReader: false)
    @State private var detectedHandle: String?
    @State private var isLoggedIn = false
    @State private var hasNavigatedHomeAfterLogin = false
    @State private var isCheckingLogin = false
    @State private var currentUAMode: String = UserDefaults.standard.string(forKey: "web.uaMode") ?? "system"
    @State private var usingEphemeral: Bool = UserDefaults.standard.bool(forKey: "web.useEphemeral")

    var body: some View {
        VStack(spacing: 0) {
            if webModel.isLoading {
                ProgressView(value: webModel.progress)
                    .progressViewStyle(.linear)
            }
            WebView(model: webModel)
                .onAppear {
                    if !webModel.hasLoadedOnce {
                        Task { await decideInitialNavigation() }
                    }
                    currentUAMode = UserDefaults.standard.string(forKey: "web.uaMode") ?? "system"
                    usingEphemeral = UserDefaults.standard.bool(forKey: "web.useEphemeral")
                }
                .onChange(of: webModel.isLoading) { loading in
                    if !loading { performLoginPolling() }
                }
        }
        .navigationTitle(isLoggedIn ? "已登录" : "登录 Codeforces")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Section {
                        Label("UA: \(labelForUAMode(currentUAMode))", systemImage: "person.badge.key")
                        Label(usingEphemeral ? "临时会话（不持久）" : "持久会话", systemImage: usingEphemeral ? "bolt.horizontal.circle" : "internaldrive")
                    }
                    Section("快速修复") {
                        Button(action: { webModel.reloadIgnoringCache() }) {
                            Label("刷新（忽略缓存）", systemImage: "arrow.clockwise")
                        }
                        Button(action: {
                            webModel.clearCodeforcesSiteData {
                                DispatchQueue.main.async { webModel.reloadFromOrigin() }
                            }
                        }) {
                            Label("清理站点数据并重载", systemImage: "trash")
                        }
                        Button(action: {
                            webModel.clearCodeforcesSiteData {
                                DispatchQueue.main.async {
                                    webModel.load(urlString: "https://codeforces.com/enter?back=%2F")
                                }
                            }
                        }) {
                            Label("重新登录（清理并进入登录页）", systemImage: "person.crop.circle.badge.xmark")
                        }
                    }
                    Section("切换 UA") {
                        Button(action: {
                            webModel.setUserAgentSystem(); currentUAMode = "system"
                        }) { Label("系统 UA（推荐）", systemImage: "safari") }
                        Button(action: {
                            webModel.setUserAgentMobile(); currentUAMode = "mobile"
                        }) { Label("移动 UA", systemImage: "iphone") }
                        Button(action: {
                            webModel.setUserAgentDesktop(); currentUAMode = "desktop"
                        }) { Label("桌面 UA", systemImage: "macpro.gen3") }
                    }
                    Section("会话模式") {
                        if usingEphemeral {
                            Button(action: {
                                webModel.usePersistentSession(); usingEphemeral = false
                            }) { Label("切换为持久会话", systemImage: "internaldrive") }
                        } else {
                            Button(action: {
                                webModel.useEphemeralSession(); usingEphemeral = true
                            }) { Label("切换为临时会话", systemImage: "bolt.horizontal.circle") }
                        }
                    }
                } label: {
                    Image(systemName: "wrench.and.screwdriver")
                }
                .accessibilityLabel("修复登录")
            }
        }
    }

    // 在页面完成加载后短暂轮询，提升登录检测的稳定性（应对重定向/延迟写 Cookie）
    private func performLoginPolling() {
        if isCheckingLogin || hasNavigatedHomeAfterLogin { return }
        isCheckingLogin = true
        Task {
            let waits: [UInt64] = [0, 300_000_000, 800_000_000, 1_500_000_000, 2_500_000_000]
            for (idx, wait) in waits.enumerated() {
                if wait > 0 { try? await Task.sleep(nanoseconds: wait) }
                if let h = await detectHandleOnce(), Self.isValidHandle(h) {
                    await MainActor.run {
                        detectedHandle = h
                        isLoggedIn = true
                        // 若已存在的 handle 与登录账号不一致，则用登录账号的 handle 覆盖
                        let current = handle.trimmingCharacters(in: .whitespacesAndNewlines)
                        if current.isEmpty || current.lowercased() != h.lowercased() {
                            handle = h
                        }
                        if !hasNavigatedHomeAfterLogin {
                            hasNavigatedHomeAfterLogin = true
                            let ts = Int(Date().timeIntervalSince1970)
                            DispatchQueue.main.async {
                                let encoded = h.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? h
                                webModel.load(urlString: "https://codeforces.com/profile/\(encoded)?_cfed=\(ts)")
                            }
                        }
                    }
                    break
                }
                // 最后一轮也没检测到则结束
                if idx == waits.count - 1 {
                    break
                }
            }
            await MainActor.run { isCheckingLogin = false }
        }
    }

    // 若已登录则直接进入个人主页；未登录则进入登录页
    private func decideInitialNavigation() async {
        if let h = await CFCookieBridge.shared.readCurrentCFHandleFromWK(), Self.isValidHandle(h) {
            await MainActor.run {
                detectedHandle = h
                isLoggedIn = true
                let ts = Int(Date().timeIntervalSince1970)
                let encoded = h.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? h
                webModel.load(urlString: "https://codeforces.com/profile/\(encoded)?_cfed=\(ts)")
            }
        } else {
            await MainActor.run {
                webModel.load(urlString: "https://codeforces.com/enter?back=%2F")
            }
        }
    }

    private func detectHandleOnce() async -> String? {
        // 优先直接从 WKCookieStore 读取，避免共享 Cookie 存在旧值导致误判
        if let h = await CFCookieBridge.shared.readCurrentCFHandleFromWK(), Self.isValidHandle(h) { return h }
        // 退路：同步至共享 Cookie 再读取（兼容性）
        await CFCookieBridge.shared.syncFromWKToHTTPCookieStorage()
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        let xUsers = cookies.filter { $0.name == "X-User" && $0.domain.lowercased().contains("codeforces.com") }
        if let chosen = xUsers.max(by: { ($0.expiresDate ?? .distantFuture) < ($1.expiresDate ?? .distantFuture) })?.value { return chosen }
        return await withCheckedContinuation { (cc: CheckedContinuation<String?, Never>) in
            webModel.extractCodeforcesHandle { h in cc.resume(returning: h) }
        }
    }

    private static func isValidHandle(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t.count <= 24 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return t.rangeOfCharacter(from: allowed.inverted) == nil
    }

    private func labelForUAMode(_ mode: String) -> String {
        switch mode {
        case "mobile": return "移动 UA"
        case "desktop": return "桌面 UA"
        default: return "系统 UA"
        }
    }
}

