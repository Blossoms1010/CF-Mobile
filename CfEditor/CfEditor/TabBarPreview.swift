import SwiftUI

// MARK: - Tab Bar Preview
#Preview("Custom Tab Bar") {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            TabBarPreviewWrapper()
        }
    }
}

struct TabBarPreviewWrapper: View {
    @State private var selection: ContentView.Tab = .contests
    
    var body: some View {
        VStack(spacing: 40) {
            // 显示当前选中的 Tab
            VStack(spacing: 12) {
                Text("当前选中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(selection.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 20)
            
            // 自定义 Tab Bar
            CustomTabBar(selection: $selection)
        }
        .padding(.bottom, 20)
    }
}

#Preview("All Tabs") {
    VStack(spacing: 30) {
        ForEach([ContentView.Tab.contests, .editor, .oiwiki, .profile], id: \.self) { tab in
            HStack {
                Image(systemName: tab.iconName)
                    .font(.title2)
                Text(tab.displayName)
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(12)
        }
    }
    .padding()
}

