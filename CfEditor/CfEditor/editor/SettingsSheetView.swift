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
    

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("File").font(.headline)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Button(action: onUndo) { Label("Go Back", systemImage: "arrow.uturn.backward") }
                                Button(action: onRedo) { Label("Go Forward", systemImage: "arrow.uturn.forward") }
                                    .disabled(!canRedo)
                                Button { code = "" } label: { Label("Clear All", systemImage: "trash") }
                            }
                            HStack(spacing: 12) {
                                Button(action: onSave) { Label("Save", systemImage: "square.and.arrow.down") }
                                Button {
                                    #if canImport(UIKit)
                                    UIPasteboard.general.string = code
                                    #endif
                                } label: { Label("Copy All", systemImage: "doc.on.doc") }
                            }
                        }
                    }

                    Divider()

                    Group {
                        Text("Edit").font(.headline)
                        HStack {
                            Text("Front Size")
                            Spacer()
                            Stepper(value: $fontSize, in: 10...24) { Text("\(fontSize)") }
                        }
                        Toggle("Read Only", isOn: $readOnly)
                        Toggle("auto Save", isOn: $autosaveEnabled)
                    }

                    Divider()

                    Group {
                        Text("Display").font(.headline)
                        Toggle("Minimap", isOn: $minimap)
                    }

                    Spacer(minLength: 8)

                    
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("Settings")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

