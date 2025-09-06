import SwiftUI

struct CreateFolderSheetView: View {
    var initialFolderName: String
    var onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var folderName: String

    init(initialFolderName: String = "新建文件夹", onConfirm: @escaping (String) -> Void) {
        self.initialFolderName = initialFolderName
        self.onConfirm = onConfirm
        self._folderName = State(initialValue: initialFolderName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("文件夹名", text: $folderName)
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                } header: {
                    Text("文件夹名")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("文件夹名称规则：")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("• 不能包含特殊字符：/ \\ : * ? \" < > |")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("• 如果重名会自动添加数字后缀")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("新建文件夹")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        let inputName = folderName.isEmpty ? initialFolderName : folderName
                        let finalName = inputName.trimmingCharacters(in: .whitespacesAndNewlines)
                        onConfirm(finalName)
                        dismiss()
                    }
                    .bold()
                    .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#if DEBUG
struct CreateFolderSheetView_Previews: PreviewProvider {
    static var previews: some View {
        CreateFolderSheetView { name in
            print("Creating folder: \(name)")
        }
    }
}
#endif
