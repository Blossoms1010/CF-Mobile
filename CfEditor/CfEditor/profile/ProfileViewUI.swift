//
//  ProfileViewUI.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import SwiftUI
import Charts

// MARK: - ProfileView UI Extensions

extension ProfileView {
    
    // MARK: - 用户信息卡片
    
    @ViewBuilder
    func ratingBox(for user: CFUserInfo) -> some View {
        let cur = user.rating ?? ratings.last?.newRating ?? 0
        let mx  = user.maxRating ?? ratings.map{ $0.newRating }.max() ?? cur
        let isUnrated = (user.rating == nil)
        
        VStack(spacing: 16) {
            // 第一行：头像 + 基本信息
            HStack(spacing: 16) {
                AvatarView(urlString: correctedAvatarURL(for: user), size: 72)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let firstName = user.firstName, let lastName = user.lastName {
                            Text("\(firstName) \(lastName)")
                                .font(.title3).bold()
                                .foregroundStyle(.primary)
                        }
                        
                        Text(user.handle)
                            .font(.headline).bold()
                            .foregroundStyle(isUnrated ? .primary : colorForRating(cur))
                    }
                    
                    HStack(spacing: 8) {
                        if isUnrated {
                            Text("Unrated")
                                .font(.title3).bold()
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(colorForRating(cur))
                                    Text("\(cur)")
                                        .font(.title2).bold()
                                        .foregroundStyle(colorForRating(cur))
                                        .monospacedDigit()
                                    
                                    RankBadge(rank: user.rank)
                                }
                                
                                HStack(spacing: 4) {
                                    Text("max")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text("\(mx)")
                                        .font(.caption)
                                        .bold()
                                        .foregroundStyle(colorForRating(mx))
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
            
            Divider()
            
            // 第二行：详细信息网格
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                if let country = user.country, !country.isEmpty {
                    ProfileInfoItem(icon: "flag.fill", label: "Country", value: country)
                }
                
                if let city = user.city, !city.isEmpty {
                    ProfileInfoItem(icon: "building.2.fill", label: "City", value: city)
                }
                
                if let org = user.organization, !org.isEmpty {
                    ProfileInfoItem(icon: "building.columns.fill", label: "Organization", value: org)
                }
                
                if let contribution = user.contribution {
                    ProfileInfoItem(
                        icon: "heart.fill",
                        label: "Contribution",
                        value: "\(contribution)",
                        valueColor: contribution >= 0 ? .green : .red
                    )
                }
                
                if let friendCount = user.friendOfCount {
                    ProfileInfoItem(icon: "person.2.fill", label: "Friends", value: "\(friendCount)")
                }
                
                if let regTime = user.registrationTimeSeconds {
                    ProfileInfoItem(icon: "calendar.badge.plus", label: "Registered", value: formatDate(regTime))
                }
                
                if let blogCount = user.blogEntryCount {
                    ProfileInfoItem(icon: "doc.text.fill", label: "Blog entries", value: "\(blogCount)")
                }
                
                if let lastOnline = user.lastOnlineTimeSeconds {
                    let lastSeenDate = Date(timeIntervalSince1970: TimeInterval(lastOnline))
                    let timeAgo = timeAgoString(from: lastSeenDate)
                    ProfileInfoItem(icon: "clock.fill", label: "Last seen", value: timeAgo)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            isUnrated ? Color(.systemGray6) : colorForRating(cur).opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            isUnrated ? Color(.systemGray4) : colorForRating(cur).opacity(0.3),
                            isUnrated ? Color(.systemGray5) : colorForRating(cur).opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - 活动统计
    
    @ViewBuilder
    var activityStatsBox: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ProfileStatItem(
                    value: activityStats?.totalSolved,
                    label: "solved in total",
                    icon: "checkmark.circle.fill",
                    gradient: [.green, .teal],
                    loading: loading
                )

                ProfileStatItem(
                    value: activityStats?.solvedLast30Days,
                    label: "solved in 30d",
                    icon: "calendar.badge.clock",
                    gradient: [.blue, .cyan],
                    loading: loading
                )

                ProfileStatItem(
                    value: activityStats?.currentStreak,
                    label: "days in a row",
                    icon: "flame.fill",
                    gradient: [.orange, .red],
                    loading: loading
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            Color(.systemGray6).opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - 辅助方法
    
    func correctedAvatarURL(for user: CFUserInfo) -> String? {
        guard var urlString = user.titlePhoto ?? user.avatar else { return nil }
        if urlString.hasPrefix("//") { urlString = "https:" + urlString }
        else if urlString.hasPrefix("/") { urlString = "https://codeforces.com" + urlString }
        else if urlString.hasPrefix("http://") { urlString = urlString.replacingOccurrences(of: "http://", with: "https://") }
        return urlString
    }
}

