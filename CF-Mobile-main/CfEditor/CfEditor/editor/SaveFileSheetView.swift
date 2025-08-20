import SwiftUI

struct SaveFileSheetView: View {
    var initialFileName: String
    var onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("文件名", text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .navigationTitle("另存为")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onConfirm(name.isEmpty ? initialFileName : name)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .onAppear { name = initialFileName }
    }
}


