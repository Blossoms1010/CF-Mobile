import SwiftUI

struct ProfileSettingsView: View {
    @State private var boundHandle: String?
    @AppStorage("aiTransModelName") private var aiTransModelName: String = ""
    @AppStorage("aiTransModel") private var aiTransModel: String = ""
    @AppStorage("aiTransProxyApi") private var aiTransProxyApi: String = ""
    @AppStorage("aiTransApiKey") private var aiTransApiKey: String = ""

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    BindCFAccountView()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("绑定 Codeforces 账号")
                        if let h = boundHandle, !h.isEmpty {
                            Text("当前绑定：\(h)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("在官方网页登录，应用内 Codeforces 页面将共享该登录态")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("AI 翻译") {
                TextField("模型名称（自定义展示用）", text: $aiTransModelName)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                TextField("模型（如 gpt-4o-mini 或 qwen2.5:14b 等）", text: $aiTransModel)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                TextField("Proxy API（OpenAI 兼容 chat/completions 接口）", text: $aiTransProxyApi)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                SecureField("API Key（可选；若你的代理要求，或直连 OpenAI 等服务时使用）", text: $aiTransApiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                Text("填写模型名称、模型以及代理 API（如 https://your-proxy/v1/chat/completions）。配置后题面页“翻译”按钮可用。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
        .onAppear { refreshBoundHandle() }
        .onReceive(NotificationCenter.default.publisher(for: .NSHTTPCookieManagerCookiesChanged)) { _ in
            refreshBoundHandle()
        }
    }

    private func refreshBoundHandle() {
        Task {
            let handle = await CFCookieBridge.shared.readCurrentCFHandleFromWK()
            await MainActor.run {
                self.boundHandle = handle
            }
        }
    }
}


