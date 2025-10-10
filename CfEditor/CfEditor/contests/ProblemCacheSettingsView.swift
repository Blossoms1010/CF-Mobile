//
//  ProblemCacheSettingsView.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import SwiftUI

// MARK: - Problem Cache Settings View

/// 题目缓存设置页面
struct ProblemCacheSettingsView: View {
    @StateObject private var cache = ProblemCache.shared
    @AppStorage("preferNativeRenderer") private var preferNativeRenderer: Bool = true
    @State private var showingClearAlert: Bool = false
    @State private var stats: ProblemCache.CacheStats? = nil
    
    var body: some View {
        List {
            // 渲染模式设置
            Section {
                Toggle(isOn: $preferNativeRenderer) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("优先使用原生渲染", systemImage: "doc.text")
                            .font(.system(size: 16, weight: .medium))
                        Text("启用后默认使用原生题面渲染，关闭后默认使用网页模式")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("渲染设置")
            }
            
            // 缓存统计
            Section {
                if let stats = stats {
                    StatRow(
                        icon: "doc.on.doc",
                        label: "已缓存题目",
                        value: "\(stats.totalProblems) 道"
                    )
                    
                    StatRow(
                        icon: "internaldrive",
                        label: "缓存大小",
                        value: formatBytes(stats.totalSize)
                    )
                    
                    if let oldest = stats.oldestCache {
                        StatRow(
                            icon: "clock",
                            label: "最早缓存",
                            value: formatDate(oldest)
                        )
                    }
                    
                    if let newest = stats.newestCache {
                        StatRow(
                            icon: "clock.badge.checkmark",
                            label: "最新缓存",
                            value: formatDate(newest)
                        )
                    }
                } else {
                    HStack {
                        ProgressView()
                        Text("加载中...")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("缓存统计")
            }
            
            // 缓存管理
            Section {
                Button(role: .destructive) {
                    showingClearAlert = true
                } label: {
                    Label("清空所有缓存", systemImage: "trash")
                }
            } header: {
                Text("缓存管理")
            } footer: {
                Text("清空缓存后，下次查看题目时会重新下载。缓存会在 7 天后自动过期。")
                    .font(.caption)
            }
            
            // 功能说明
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(
                        icon: "bolt.fill",
                        title: "快速加载",
                        description: "原生渲染速度更快，无需等待网页加载"
                    )
                    
                    Divider()
                    
                    FeatureRow(
                        icon: "wifi.slash",
                        title: "离线查看",
                        description: "已缓存的题目可在离线状态下查看"
                    )
                    
                    Divider()
                    
                    FeatureRow(
                        icon: "textformat.size",
                        title: "字体调节",
                        description: "原生渲染支持真正的字体大小调节"
                    )
                    
                    Divider()
                    
                    FeatureRow(
                        icon: "doc.on.clipboard",
                        title: "快速复制",
                        description: "一键复制样例输入，方便测试"
                    )
                }
                .padding(.vertical, 4)
            } header: {
                Text("功能特性")
            }
        }
        .navigationTitle("题面渲染设置")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadStats()
        }
        .refreshable {
            loadStats()
        }
        .alert("清空缓存", isPresented: $showingClearAlert) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                Task {
                    await cache.clearAll()
                    loadStats()
                }
            }
        } message: {
            Text("确定要清空所有已缓存的题目吗？此操作不可恢复。")
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadStats() {
        stats = cache.getStats()
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Stat Row

private struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.system(size: 15))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProblemCacheSettingsView()
    }
}

