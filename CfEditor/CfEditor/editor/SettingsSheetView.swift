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
                VStack(alignment: .leading, spacing: 24) {
                    // File Section
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader(icon: "folder.fill", title: "File", gradient: [.blue, .cyan])
                        
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                actionButton(
                                    icon: "arrow.uturn.backward",
                                    title: "Undo",
                                    gradient: [.orange, .pink],
                                    action: onUndo,
                                    disabled: !canUndo
                                )
                                
                                actionButton(
                                    icon: "arrow.uturn.forward",
                                    title: "Redo",
                                    gradient: [.purple, .blue],
                                    action: onRedo,
                                    disabled: !canRedo
                                )
                            }
                            
                            HStack(spacing: 12) {
                                actionButton(
                                    icon: "square.and.arrow.down",
                                    title: "Save",
                                    gradient: [.green, .mint],
                                    action: onSave
                                )
                                
                                actionButton(
                                    icon: "doc.on.doc",
                                    title: "Copy All",
                                    gradient: [.blue, .cyan],
                                    action: {
                                        #if canImport(UIKit)
                                        UIPasteboard.general.string = code
                                        #endif
                                    }
                                )
                            }
                            
                            actionButton(
                                icon: "trash.fill",
                                title: "Clear All",
                                gradient: [.red, .orange],
                                action: { code = "" },
                                fullWidth: true
                            )
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    
                    // Edit Section
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader(icon: "pencil.circle.fill", title: "Editor", gradient: [.purple, .pink])
                        
                        VStack(spacing: 16) {
                            // Font Size
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "textformat.size")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.purple, .pink],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    Text("Font Size")
                                        .font(.system(size: 16, weight: .semibold))
                                    Spacer()
                                    Text("\(fontSize)")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .frame(width: 40, alignment: .trailing)
                                }
                                
                                Slider(value: Binding(
                                    get: { Double(fontSize) },
                                    set: { fontSize = Int($0) }
                                ), in: 10...24, step: 1)
                                .tint(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            }
                            
                            Divider()
                            
                            // Read Only Toggle
                            toggleRow(
                                icon: "lock.fill",
                                title: "Read Only",
                                subtitle: "Prevent editing",
                                isOn: $readOnly,
                                gradient: [.orange, .red]
                            )
                            
                            Divider()
                            
                            // Auto Save Toggle
                            toggleRow(
                                icon: "arrow.triangle.2.circlepath",
                                title: "Auto Save",
                                subtitle: "Automatically save changes",
                                isOn: $autosaveEnabled,
                                gradient: [.green, .mint]
                            )
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    
                    // Display Section
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader(icon: "eye.fill", title: "Display", gradient: [.cyan, .blue])
                        
                        VStack(spacing: 16) {
                            toggleRow(
                                icon: "map.fill",
                                title: "Minimap",
                                subtitle: "Show code overview",
                                isOn: $minimap,
                                gradient: [.cyan, .blue]
                            )
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Settings")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
    
    // MARK: - Section Header
    @ViewBuilder
    private func sectionHeader(icon: String, title: String, gradient: [Color]) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Spacer()
        }
    }
    
    // MARK: - Action Button
    @ViewBuilder
    private func actionButton(
        icon: String,
        title: String,
        gradient: [Color],
        action: @escaping () -> Void,
        disabled: Bool = false,
        fullWidth: Bool = false
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                
                if fullWidth {
                    Spacer()
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, fullWidth ? 16 : 20)
            .padding(.vertical, 12)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                LinearGradient(
                    colors: disabled ? [.gray.opacity(0.5), .gray.opacity(0.3)] : gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .clipShape(Capsule())
            .shadow(
                color: disabled ? .clear : gradient[0].opacity(0.4),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .disabled(disabled)
        .buttonStyle(PressEffectButtonStyle())
    }
    
    // MARK: - Toggle Row
    @ViewBuilder
    private func toggleRow(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        gradient: [Color]
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient.map { $0.opacity(0.15) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
}

