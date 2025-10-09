//
//  ContestsViewComponents.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import SwiftUI

// MARK: - 自定义分段控制器

struct CustomSegmentedPicker: View {
    @Binding var selection: PracticeMode
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(PracticeMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = mode
                    }
                    #if canImport(UIKit)
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    #endif
                } label: {
                    VStack(spacing: 4) {
                        Text(mode.rawValue)
                            .font(.system(size: 15, weight: selection == mode ? .semibold : .regular))
                            .foregroundColor(selection == mode ? .primary : .secondary)
                        
                        if selection == mode {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentColor)
                                .frame(height: 3)
                                .matchedGeometryEffect(id: "segment", in: animation)
                        } else {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.clear)
                                .frame(height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - 美化搜索框组件

struct EnhancedSearchField: View {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isFocused ? .accentColor : .secondary)
                .font(.system(size: 16))
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFocused)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit(onSubmit)
            
            if !text.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        text = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - 骨架屏加载组件

struct SkeletonListRow: View {
    @State private var shimmerOffset: CGFloat = -300
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 16)
                .frame(maxWidth: .infinity)
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.white.opacity(0.5), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset)
                )
                .clipped()
            
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 12)
                
                Spacer()
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 12)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 300
            }
        }
    }
}

// MARK: - 题目标签视图组件

struct ProblemTagsView: View {
    let tags: [String]
    
    var body: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.15))
                            )
                            .foregroundColor(Color.secondary)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }
}

// MARK: - 圆圈状态图标组件

@ViewBuilder
func circledStatusIcon(for attempt: ProblemAttemptState) -> some View {
    let icon = statusIcon(for: attempt)
    let iconColor = statusIconColor(for: attempt)
    
    ZStack {
        Circle()
            .stroke(iconColor, lineWidth: 1.5)
            .frame(width: 18, height: 18)
        
        if !icon.isEmpty {
            Text(icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(iconColor)
        }
    }
    .frame(width: 20, height: 20)
}

// MARK: - 状态图标工具

func statusIcon(for attempt: ProblemAttemptState) -> String {
    switch attempt {
    case .solved: return "✓"
    case .tried: return "✗"
    case .none: return ""
    }
}

func statusIconColor(for attempt: ProblemAttemptState) -> Color {
    switch attempt {
    case .solved: return .green
    case .tried: return .red
    case .none: return .secondary
    }
}

// MARK: - 颜色工具

func colorForProblemRating(_ rating: Int?) -> Color {
    guard let r = rating else { return .black }
    return colorForRating(r)
}

// MARK: - 工具函数

func formatSolvedCount(_ count: Int) -> String {
    if count >= 1000000 {
        return String(format: "%.1fM", Double(count) / 1000000)
    } else if count >= 1000 {
        return String(format: "%.1fK", Double(count) / 1000)
    } else {
        return String(count)
    }
}

// MARK: - 轻触反馈

func performLightHaptic() {
    #if os(iOS)
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
    #endif
}

// MARK: - 标签显示逻辑

@MainActor
func shouldShowTags(for problem: CFProblem, store: ProblemsetStore) -> Bool {
    let status = store.getProblemStatus(for: problem)
    if status == .solved {
        return true
    }
    return store.filter.showUnsolvedTags
}

