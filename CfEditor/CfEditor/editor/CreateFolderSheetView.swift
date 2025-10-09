import SwiftUI

struct CreateFolderSheetView: View {
    var initialFolderName: String
    var onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var folderName: String

    init(initialFolderName: String = "New Folder", onConfirm: @escaping (String) -> Void) {
        self.initialFolderName = initialFolderName
        self.onConfirm = onConfirm
        self._folderName = State(initialValue: initialFolderName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Folder Name", text: $folderName)
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                } header: {
                    Text("Folder Name")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Folder Naming Rules:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("• Cannot contain special characters: / \\ : * ? \" < > |")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("• If there is a duplicate name, a numeric suffix will be automatically added")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("New Folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
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
