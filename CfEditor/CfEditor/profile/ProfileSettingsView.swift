import SwiftUI

struct ProfileSettingsView: View {
    var body: some View {
        Form {
            Section {
                NavigationLink {
                    BindCFAccountView()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("绑定 Codeforces 账号")
                        Text("在官方网页登录，应用内 Codeforces 页面将共享该登录态")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("设置")
    }
}


