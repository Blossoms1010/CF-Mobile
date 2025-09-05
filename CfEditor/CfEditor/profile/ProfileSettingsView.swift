import SwiftUI

struct ProfileSettingsView: View {
    @AppStorage("aiTransModelName") private var aiTransModelName: String = ""
    @AppStorage("aiTransModel") private var aiTransModel: String = ""
    @AppStorage("aiTransProxyApi") private var aiTransProxyApi: String = ""
    @AppStorage("aiTransApiKey") private var aiTransApiKey: String = ""

    var body: some View {
        Form {
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
    }
}


