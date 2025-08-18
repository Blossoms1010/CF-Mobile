import SwiftUI

struct SettingsSheetView: View {
    @Binding var fontSize: Int
    @Binding var minimap: Bool
    @Binding var readOnly: Bool
    @Binding var autosaveEnabled: Bool
    @Binding var code: String
    var onUndo: () -> Void = {}
    var onRedo: () -> Void = {}
    var canUndo: Bool = false
    var canRedo: Bool = false
    var onSave: () -> Void
    var onSaveAs: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("文件").font(.headline)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Button(action: onUndo) { Label("撤销", systemImage: "arrow.uturn.backward") }
                                Button(action: onRedo) { Label("重做", systemImage: "arrow.uturn.forward") }
                                    .disabled(!canRedo)
                                Button { code = "" } label: { Label("清空", systemImage: "trash") }
                            }
                            HStack(spacing: 12) {
                                Button(action: onSave) { Label("保存", systemImage: "square.and.arrow.down") }
                                Button(action: onSaveAs) { Label("另存为", systemImage: "square.and.arrow.down.on.square") }
                                Button {
                                    #if canImport(UIKit)
                                    UIPasteboard.general.string = code
                                    #endif
                                } label: { Label("复制全部", systemImage: "doc.on.doc") }
                            }
                        }
                    }

                    Divider()

                    Group {
                        Text("编辑").font(.headline)
                        HStack {
                            Text("字号")
                            Spacer()
                            Stepper(value: $fontSize, in: 10...24) { Text("\(fontSize)") }
                        }
                        Toggle("只读", isOn: $readOnly)
                        Toggle("自动保存", isOn: $autosaveEnabled)
                    }

                    Divider()

                    Group {
                        Text("显示").font(.headline)
                        Toggle("Minimap", isOn: $minimap)
                    }

                    Spacer(minLength: 8)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}


