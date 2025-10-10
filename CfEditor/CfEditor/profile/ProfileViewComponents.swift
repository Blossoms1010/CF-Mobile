//
//  ProfileViewComponents.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import SwiftUI

// MARK: - 信息项组件

struct ProfileInfoItem: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color? = nil
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .bold()
                    .foregroundStyle(valueColor ?? .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(.systemBackground).opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - 统计项组件

struct ProfileStatItem: View {
    let value: Int?
    let label: String
    let icon: String
    let gradient: [Color]
    let loading: Bool
    
    var body: some View {
        VStack(spacing: 10) {
            // 图标背景圆
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient.map { $0.opacity(0.15) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // 数值
            if let value {
                Text(String(value))
                    .font(.title).bold().monospacedDigit()
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .transition(.opacity.combined(with: .scale))
            } else if loading {
                ProgressView().progressViewStyle(.circular)
            } else {
                Text("--").font(.title).bold().monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            // 标签
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: value)
    }
}

// MARK: - 最近提交行组件

struct RecentSubmissionRow: View {
    let submission: CFSubmission
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                // 左：判题结果圆点
                Circle()
                    .fill(colorForVerdict(CFVerdict.from(submission.verdict)))
                    .frame(width: 10, height: 10)
                
                // 中：题号 + 名称 + 提交编号
                VStack(alignment: .leading, spacing: 4) {
                    Text(problemTitle(submission))
                        .font(.subheadline).bold()
                        .lineLimit(2)
                        .truncationMode(.tail)
                    
                    // 提交编号
                    Text("#\(submission.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // 判题状态 - 允许换行
                    Text(CFVerdict.from(submission.verdict).textWithTestInfo(passedTests: submission.passedTestCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // 语言和性能指标
                    HStack(spacing: 6) {
                        if let lang = submission.programmingLanguage, !lang.isEmpty {
                            Text(lang)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        
                        if let timeMs = submission.timeConsumedMillis {
                            Text("\(timeMs) ms")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let memoryBytes = submission.memoryConsumedBytes {
                            Text("\(memoryBytes / 1024) KB")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // 右：提交时间
                Text(shortTime(from: submission.creationTimeSeconds))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func problemTitle(_ s: CFSubmission) -> String {
        let idx = s.problem.index
        let name = s.problem.name
        if let cid = s.contestId ?? s.problem.contestId {
            return "\(cid) \(idx) · \(name)"
        } else {
            return "\(idx) · \(name)"
        }
    }
    
    private func shortTime(from epoch: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epoch))
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: date)
    }
    
    private func colorForVerdict(_ v: CFVerdict) -> Color {
        switch v {
        case .ok: return .green
        case .wrongAnswer: return .red
        case .timeLimit, .memoryLimit, .runtimeError, .compilationError, .presentationError: return .orange
        case .testing, .idlen: return .gray
        default: return .gray
        }
    }
}

// MARK: - 比赛记录行组件

struct ContestRecordRow: View {
    let contest: ContestRecord
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 左侧：比赛名称和信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(contest.contestName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        // 比赛序号
                        Text("#\(contest.contestNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // 日期
                        Text(contestDate(from: contest.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // 通过题目数
                        if contest.solvedCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text("\(contest.solvedCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 右侧：排名和rating变化
                VStack(alignment: .trailing, spacing: 4) {
                    if let rank = contest.rank {
                        HStack(spacing: 4) {
                            Text("rank")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(rank)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    if contest.isRated {
                        if let ratingChange = contest.ratingChange, let newRating = contest.newRating {
                            HStack(spacing: 4) {
                                let changeColor: Color = ratingChange >= 0 ? .green : .red
                                let changePrefix = ratingChange >= 0 ? "+" : ""
                                
                                Text("\(changePrefix)\(ratingChange)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(changeColor)
                                
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                Text("\(newRating)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(colorForRating(newRating))
                            }
                        }
                    } else {
                        Text("Unrated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
            }
        }
    }
    
    private func contestDate(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd HH:mm"
        return df.string(from: date)
    }
}

// MARK: - 辅助函数

func formatDate(_ timestamp: Int) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter.string(from: date)
}

func timeAgoString(from date: Date) -> String {
    let now = Date()
    let diff = now.timeIntervalSince(date)
    
    if diff < 60 {
        return "just now"
    } else if diff < 3600 {
        let mins = Int(diff / 60)
        return "\(mins)m ago"
    } else if diff < 86400 {
        let hours = Int(diff / 3600)
        return "\(hours)h ago"
    } else if diff < 604800 {
        let days = Int(diff / 86400)
        return "\(days)d ago"
    } else {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

