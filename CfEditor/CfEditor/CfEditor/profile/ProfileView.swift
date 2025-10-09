import SwiftUI
import Charts
import WebKit
import Kingfisher

// MARK: - 比赛记录数据结构
struct ContestRecord: Identifiable {
    let id: Int // contestId
    let contestName: String
    let date: Date
    let rank: Int?
    let oldRating: Int?
    let newRating: Int?
    let ratingChange: Int?
    let contestNumber: Int // 第几场比赛（从1开始）
    let solvedCount: Int // 赛时通过的题目数量
    
    var isRated: Bool {
        ratingChange != nil
    }
}

// MARK: - 主视图 (ProfileView)
struct ProfileView: View {
    @AppStorage("cfHandle") private var handle: String = ""

    // 登录表单
    @State private var input: String = ""
    @State private var loginError: String?
    @FocusState private var focused: Bool
    @State private var isSaving = false
    // 仅输入 handle 的绑定方式

    // 登录后数据
    @State private var loading = true
    @State private var fetchError: String?
    @State private var user: CFUserInfo?
    @State private var ratings: [CFRatingUpdate] = []
    @State private var activityStats: ActivityStats?
    @State private var heatmapData: HeatmapData?
    @State private var practiceBuckets: [PracticeBucket] = []
    @State private var tagSlices: [TagSlice] = []
    @State private var lastLoadedAt: Date?
    private let profileSoftTTL: TimeInterval = 600 // 10 分钟软 TTL，减少频繁刷新
    @State private var recentSubmissions: [CFSubmission] = []
    // @State private var presentedURL: IdentifiedURL? = nil // 已禁用提交详情查看
    @State private var showAllSubmissionsSheet: Bool = false
    private let maxRecentSubmissionsToShow: Int = 7 // 默认显示的提交数量
    
    // 比赛记录
    @State private var recentContests: [ContestRecord] = [] // 存储最近的比赛记录（包括 unrated）
    @State private var showAllContestsSheet: Bool = false
    private let maxRecentContestsToShow: Int = 5 // 默认显示的比赛数量
    
    // 热力图选择
    @State private var selectedHeatmapOption: YearSelection = .all
    @State private var allSubmissions: [CFSubmission] = [] // 存储所有提交数据用于年份筛选

    var body: some View {
        Group {
            if handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                loginForm
            } else {
                profileDetails
            }
        }
    }

    // MARK: - 登录页（仅输入 Handle）
    private var loginForm: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("输入 Codeforces Handle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        TextField("Handle", text: $input)
                            .textInputAutocapitalization(.none)
                            .autocorrectionDisabled(true)
                            .focused($focused)
                        Button(isSaving ? "绑定中…" : "绑定") {
                            Task { await save() }
                        }
                        .disabled(isSaving || !isValid(input))
                    }
                    if let loginError { Text(loginError).foregroundStyle(.red) }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("绑定 Handle")
    }
    
    // MARK: - 详情页
    private var profileDetails: some View {
        Form {
            if let fetchError {
                Section { Text(fetchError).foregroundStyle(.red) }
            }
            
            // 用户信息：Skeleton + 淡入 + 缩放动画
            Section {
                if loading {
                    SkeletonUserCard()
                } else if let user {
                    ratingBox(for: user)
                        .opacity(loading ? 0 : 1)
                        .scaleEffect(loading ? 0.95 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: loading)
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            
            // 活动统计：Skeleton + 淡入 + 滑动动画
            Section {
                if loading {
                    SkeletonStatsRow()
                } else {
                    activityStatsBox
                        .opacity(loading ? 0 : 1)
                        .offset(y: loading ? 20 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: loading)
                }
            } header: {
                Label("Info", systemImage: "chart.bar.doc.horizontal")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)

            // Rating 曲线：Skeleton + 淡入 + 滑动动画
            Section { 
                ratingChartBox
                    .opacity(loading ? 0 : 1)
                    .offset(y: loading ? 20 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: loading)
            } header: {
                Label("Rating graph", systemImage: "chart.xyaxis.line")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            
            // 比赛记录：Skeleton + 淡入 + 滑动动画
            Section { 
                contestHistoryBox
                    .opacity(loading ? 0 : 1)
                    .offset(y: loading ? 20 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: loading)
            } header: {
                Label("Contest History", systemImage: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            
            // 热力图：Skeleton + 淡入 + 滑动动画
            Section { 
                heatmapBox
                    .opacity(loading ? 0 : 1)
                    .offset(y: loading ? 20 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: loading)
            } header: {
                Label("Heatmap", systemImage: "calendar.day.timeline.left")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            
            // 练习柱状图：Skeleton + 淡入 + 数据变化动画
            Section { 
                practiceHistogramBox
                    .opacity(loading ? 0 : 1)
                    .offset(y: loading ? 20 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: loading)
            } header: {
                Label("Rating Solved", systemImage: "chart.bar.xaxis")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            
            // 标签分布：Skeleton + 淡入 + 数据变化动画
            Section { 
                tagPieBox
                    .opacity(loading ? 0 : 1)
                    .offset(y: loading ? 20 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: loading)
            } header: {
                Label("Tag Solved", systemImage: "chart.pie.fill")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)

            // 最近提交：最多展示 10 条
            Section {
                recentSubmissionsBox
                    .opacity(loading ? 0 : 1)
                    .offset(y: loading ? 20 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: loading)
            } header: {
                Label("Recent Submissions", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.teal, .green],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)

            // 设置
            Section {
                NavigationLink {
                    ProfileSettingsView()
                } label: {
                    HStack {
                        Spacer()
                        Label("Settings", systemImage: "gear")
                        Spacer()
                    }
                }
            }

            // 退出
            Section {
                Button("Log Out", role: .destructive) {
                    Task { await performLogoutAndReload() }
                }
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            // 底部占位空间，避免被 TabBar 遮挡
            Section {
                Color.clear
                    .frame(height: 60)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: handle.lowercased()) { await reloadIfNeeded() }
        // 尝试用当前 Web 会话中的登录账号校正 handle（解决 handle 与实际登录态不一致的问题）
        .task {
            if let h = await CFCookieBridge.shared.readCurrentCFHandleFromWK(), h.lowercased() != handle.lowercased() {
                // 仅当 Cookie 中的 X-User 合法时覆盖（readCurrentCFHandleFromWK 已校验）
                handle = h
            }
        }
        .refreshable { await reload(forceRefresh: true) }
        // 提交详情查看已禁用
        // .sheet(item: $presentedURL) { item in
        //     NavigationStack {
        //         SubmissionDetailWebView(url: item.url, targetURLString: item.url.absoluteString)
        //             .navigationTitle("提交详情")
        //             .navigationBarTitleDisplayMode(.inline)
        //             .toolbar {
        //                 ToolbarItem(placement: .cancellationAction) { Button("关闭") { presentedURL = nil } }
        //                 ToolbarItem(placement: .navigationBarTrailing) { Button("刷新") { NotificationCenter.default.post(name: .init("SubmissionWebView.ReloadRequested"), object: nil) } }
        //             }
        //     }
        // }
        .sheet(isPresented: $showAllSubmissionsSheet) {
            NavigationStack {
                AllSubmissionsSheet(handle: handle)
                .navigationTitle("All Submissions")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.fraction(0.6), .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAllContestsSheet) {
            NavigationStack {
                AllContestsSheet(contests: recentContests)
                .navigationTitle("All Contests")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.fraction(0.6), .large])
            .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - 练习柱状图视图

    private let practiceBarWidth: CGFloat = 10

    private var importantTickKeys: [String] {
        let maxRated = practiceBuckets.compactMap { $0.ratingFloor }.max() ?? 2600
        var ticks: [String] = []
        var x = 800
        while x <= maxRated {
            ticks.append("\(x)")
            x += 300
        }
        return ticks
    }

    private var practiceChartMinWidth: CGFloat {
        CGFloat(practiceBuckets.count) * 16.0 + 32.0
    }

    @ViewBuilder
    private var practiceHistogramBox: some View {
        if practiceBuckets.isEmpty {
            if loading {
                SkeletonChartBlock(height: 220)
            } else {
                Text("暂无可统计的练习数据")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 220)
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                Chart(practiceBuckets) { b in
                    BarMark(
                        x: .value("难度", b.key),
                        y: .value("数量", b.count),
                        width: .fixed(practiceBarWidth)
                    )
                    .foregroundStyle(
                        b.ratingFloor == nil ? Color.secondary : colorForRating((b.ratingFloor ?? 800) + 1)
                    )
                    .cornerRadius(2)
                }
                .chartXScale(domain: practiceBuckets.map(\.key))
                .chartXAxis {
                    AxisMarks(values: importantTickKeys) { v in
                        AxisGridLine()
                        AxisTick()
                        if let label = v.as(String.self) {
                            AxisValueLabel(centered: true) {
                                Text(label)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.4)
                            }
                        }
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(minWidth: practiceChartMinWidth, alignment: .leading)
                .frame(height: 230)
                .padding(12)
                .opacity(loading ? 0 : 1)
                .animation(.easeOut(duration: 0.35),
                           value: practiceBuckets.map(\.count).reduce(0, +))
                .animation(.easeOut(duration: 0.30), value: loading)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        }
    }
    
    // MARK: - 比赛记录卡片
    
    @ViewBuilder
    private var contestHistoryBox: some View {
        if loading {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.18))
                        .frame(height: 60)
                        .shimmer()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        } else if recentContests.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "trophy")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("暂无比赛记录")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        } else {
            VStack(spacing: 0) {
                // 比赛列表（最多显示 maxRecentContestsToShow 条）
                let displayContests = Array(recentContests.prefix(maxRecentContestsToShow))
                ForEach(Array(displayContests.enumerated()), id: \.element.id) { index, contest in
                    contestRecordRow(contest)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    
                    // 分隔线（不是最后一项）
                    if index < displayContests.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
                
                // 查看全部按钮
                Button {
                    showAllContestsSheet = true
                } label: {
                    HStack {
                        Spacer()
                        Label("查看全部", systemImage: "list.bullet")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6).opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        }
    }
    
    // MARK: - 最近提交卡片
    
    @ViewBuilder
    private var recentSubmissionsBox: some View {
        if loading {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.18))
                        .frame(height: 44)
                        .shimmer()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        } else if recentSubmissions.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("暂无提交记录")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        } else {
            VStack(spacing: 0) {
                // 提交列表（最多显示 maxRecentSubmissionsToShow 条）
                let displaySubmissions = Array(recentSubmissions.prefix(maxRecentSubmissionsToShow))
                ForEach(Array(displaySubmissions.enumerated()), id: \.element.id) { index, s in
                    recentSubmissionRow(s)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    
                    // 分隔线（不是最后一项）
                    if index < displaySubmissions.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
                
                // 查看全部按钮
                Button {
                    showAllSubmissionsSheet = true
                } label: {
                    HStack {
                        Spacer()
                        Label("查看全部", systemImage: "list.bullet")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6).opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        }
    }
    
    // MARK: - 用户信息卡片

    @ViewBuilder
    private func ratingBox(for user: CFUserInfo) -> some View {
        let cur = user.rating ?? ratings.last?.newRating ?? 0
        let mx  = user.maxRating ?? ratings.map{ $0.newRating }.max() ?? cur
        let isUnrated = (user.rating == nil)
        
        VStack(spacing: 16) {
            // 第一行：头像 + 基本信息
            HStack(spacing: 16) {
                // 头像（更大）
                AvatarView(urlString: correctedAvatarURL(for: user), size: 72)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    // 姓名 + 称号
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
                    
                    // Rating 信息
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
            
            // 分隔线
            Divider()
            
            // 第二行：详细信息网格
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                // 国家
                if let country = user.country, !country.isEmpty {
                    InfoItem(icon: "flag.fill", label: "Country", value: country)
                }
                
                // 城市
                if let city = user.city, !city.isEmpty {
                    InfoItem(icon: "building.2.fill", label: "City", value: city)
                }
                
                // 组织
                if let org = user.organization, !org.isEmpty {
                    InfoItem(icon: "building.columns.fill", label: "Organization", value: org)
                }
                
                // 贡献
                if let contribution = user.contribution {
                    InfoItem(icon: "heart.fill", label: "Contribution", value: "\(contribution)", 
                            valueColor: contribution >= 0 ? .green : .red)
                }
                
                // 好友数
                if let friendCount = user.friendOfCount {
                    InfoItem(icon: "person.2.fill", label: "Friends", value: "\(friendCount)")
                }
                
                // 注册时间
                if let regTime = user.registrationTimeSeconds {
                    InfoItem(icon: "calendar.badge.plus", label: "Registered", value: formatDate(regTime))
                }
                
                // 博客条目数量
                if let blogCount = user.blogEntryCount {
                    InfoItem(icon: "doc.text.fill", label: "Blog entries", value: "\(blogCount)")
                }
                
                // 最后在线
                if let lastOnline = user.lastOnlineTimeSeconds {
                    let lastSeenDate = Date(timeIntervalSince1970: TimeInterval(lastOnline))
                    let timeAgo = timeAgoString(from: lastSeenDate)
                    InfoItem(icon: "clock.fill", label: "Last seen", value: timeAgo)
                        .help("Note: Codeforces only updates this when you submit code or participate in contests, not when simply browsing the site.")
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
    
    // 信息项组件
    @ViewBuilder
    private func InfoItem(icon: String, label: String, value: String, valueColor: Color? = nil) -> some View {
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
    
    // 时间前字符串
    private func timeAgoString(from date: Date) -> String {
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
    
    private func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    
    // MARK: - 活动统计

    @ViewBuilder
    private var activityStatsBox: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statItem(value: activityStats?.totalSolved,
                         label: "solved in total",
                         icon: "checkmark.circle.fill",
                         gradient: [.green, .teal])

                statItem(value: activityStats?.solvedLast30Days,
                         label: "solved in 30d",
                         icon: "calendar.badge.clock",
                         gradient: [.blue, .cyan])

                statItem(value: activityStats?.currentStreak,
                         label: "days in a row",
                         icon: "flame.fill",
                         gradient: [.orange, .red])
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

    @ViewBuilder
    private func statItem(value: Int?, label: String, icon: String, gradient: [Color]) -> some View {
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
    
    // MARK: - 标签饼图（简洁稳定版）

    /// 为标签生成丰富且稳定的配色（Others 固定灰色）
    private func tagColorMapping(for tags: [String]) -> [String: Color] {
        var map: [String: Color] = ["Others": .secondary]
        // 一组分布均匀的色相
        let hues: [Double] = [0.00, 0.08, 0.16, 0.22, 0.30, 0.36, 0.44, 0.52, 0.60, 0.68, 0.76, 0.82, 0.90, 0.96, 0.12, 0.48]
        var i = 0
        for t in tags where t != "Others" {
            let h = hues[i % hues.count]
            map[t] = Color(hue: h, saturation: 0.78, brightness: 0.92)
            i += 1
        }
        return map
    }
    
    // === 标签饼图：计算用的辅助属性（避免在 ViewBuilder 里声明变量/函数） ===
    private var tagSlicesNZ: [TagSlice] {
        tagSlices.filter { $0.count > 0 }
    }

    private var tagLegendWidth: CGFloat { 140 }
    private var tagChartHeight: CGFloat { 260 }

    private var tagColorMapComputed: [String: Color] {
        tagColorMapping(for: tagSlicesNZ.map(\.tag))
    }

    private var tagDomain: [String] {
        tagSlicesNZ.map(\.tag)
    }

    private var tagRange: [Color] {
        tagDomain.map { tagColorMapComputed[$0] ?? .accentColor }
    }

    private var tagCountsByTag: [String: Int] {
        Dictionary(uniqueKeysWithValues: tagSlicesNZ.map { ($0.tag, $0.count) })
    }

    private var tagTotalCount: Int {
        max(1, tagSlicesNZ.reduce(0) { $0 + $1.count })
    }

    private func tagPercentString(for count: Int) -> String {
        String(format: "%.1f%%", Double(count) * 100.0 / Double(tagTotalCount))
    }
    
    // 扇形图标注视图
    @ViewBuilder
    private func tagAnnotation(tag: String, count: Int) -> some View {
        VStack(spacing: 2) {
            Text(tag)
                .font(.caption)
                .fontWeight(.bold)
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.semibold)
            Text(tagPercentString(for: count))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(tagColorMapComputed[tag] ?? .accentColor, lineWidth: 2)
        )
    }
    
    // iOS 17+ 扇形图
    @available(iOS 17.0, *)
    @ViewBuilder
    private var tagPieChart: some View {
        ZStack {
            Chart(tagSlicesNZ) { s in
                tagSectorMark(for: s)
            }
            .chartForegroundStyleScale(domain: tagDomain, range: tagRange)
            .chartLegend(.hidden)
            
            // 中心显示选中标签信息
            if let selected = selectedTag,
               let slice = tagSlicesNZ.first(where: { $0.tag == selected }) {
                VStack(spacing: 4) {
                    Text(selected)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("\(slice.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(tagColorMapComputed[selected] ?? .accentColor)
                    Text(tagPercentString(for: slice.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // iOS 17+ 扇形分区
    @available(iOS 17.0, *)
    @ChartContentBuilder
    private func tagSectorMark(for slice: TagSlice) -> some ChartContent {
        let isSelected = selectedTag == slice.tag
        let outerRadius: MarkDimension = isSelected ? .ratio(1.04) : .ratio(1.0)
        
        return SectorMark(
            angle: .value("Count", slice.count),
            innerRadius: .ratio(0.50),
            outerRadius: outerRadius,
            angularInset: 1.5
        )
        .foregroundStyle(by: .value("Tag", slice.tag))
        .opacity(selectedTag == nil || isSelected ? 1.0 : 0.3)
        .cornerRadius(3.0)
    }
    
    // iOS 17+ 标注分区
    @available(iOS 17.0, *)
    @ChartContentBuilder
    private func tagAnnotationMark(for slice: TagSlice) -> some ChartContent {
        SectorMark(
            angle: .value("Count", slice.count),
            innerRadius: .ratio(0.50),
            outerRadius: .ratio(0.85),
            angularInset: 1.5
        )
        .foregroundStyle(.clear)
        .annotation(position: .overlay) {
            tagAnnotation(tag: slice.tag, count: slice.count)
        }
    }
    
    // iOS 16 降级柱状图
    @ViewBuilder
    private var tagBarChart: some View {
        Chart(tagSlicesNZ) { s in
            BarMark(
                x: .value("数量", s.count),
                y: .value("标签", s.tag)
            )
            .foregroundStyle(by: .value("Tag", s.tag))
            .opacity(selectedTag == nil || selectedTag == s.tag ? 1.0 : 0.3)
            .cornerRadius(3)
        }
        .chartForegroundStyleScale(domain: tagDomain, range: tagRange)
        .chartLegend(.hidden)
    }
    
    // 扇形图视图
    @ViewBuilder
    private var tagPieChartView: some View {
        if #available(iOS 17.0, *) {
            tagPieChart
        } else {
            tagBarChart
        }
    }

    @ViewBuilder
    private var tagPieBox: some View {
        if tagSlices.isEmpty {
            if loading {
                SkeletonChartBlock(height: 240)
            } else {
                Text("暂无可统计的标签数据")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 240)
            }
        } else {
            VStack(spacing: 16) {
                // 顶部：扇形图 + 引导线标注
                tagPieChartView
                    .frame(height: 200)
                    .padding(.horizontal, 20)
                    .opacity(loading ? 0 : 1)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: tagTotalCount)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: tagSlicesNZ.count)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedTag)
                    .animation(.easeOut(duration: 0.30), value: loading)

                // 分隔线
                Divider().padding(.horizontal, 8)

                // 底部：图例区域
                VStack(spacing: 12) {
                    // 图例网格（可展开/收起）
                    let columns = [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ]
                    
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(tagLegendsToShow, id: \.self) { tag in
                            tagLegendItem(tag: tag)
                        }
                    }
                    .padding(.horizontal, 12)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: isTagLegendExpanded)
                    
                    // 展开/收起按钮
                    if tagDomain.count > 6 {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                isTagLegendExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(isTagLegendExpanded ? "收起" : "展开全部 (\(tagDomain.count))")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Image(systemName: isTagLegendExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray6))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        }
    }
    
    @State private var isTagLegendExpanded: Bool = false  // 图例是否展开
    @State private var selectedTag: String? = nil  // 选中的标签（用于高亮显示）
    
    // 计算要显示的图例
    private var tagLegendsToShow: [String] {
        if isTagLegendExpanded || tagDomain.count <= 6 {
            return tagDomain
        } else {
            return Array(tagDomain.prefix(6))
        }
    }
    
    
    // 图例项组件
    @ViewBuilder
    private func tagLegendItem(tag: String) -> some View {
        let isSelected = selectedTag == tag
        
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                // 颜色圆点
                Circle()
                    .fill(tagColorMapComputed[tag] ?? .accentColor)
                    .frame(width: 8, height: 8)
                
                // 标签名
                Text(tag)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            // 数量 + 百分比
            HStack(spacing: 3) {
                Text("\(tagCountsByTag[tag] ?? 0)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(tagPercentString(for: (tagCountsByTag[tag] ?? 0)))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((tagColorMapComputed[tag] ?? .accentColor).opacity(isSelected ? 0.2 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke((tagColorMapComputed[tag] ?? .accentColor).opacity(isSelected ? 0.6 : 0.2), lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                // 点击同一个标签时取消选中，点击不同标签时选中
                if selectedTag == tag {
                    selectedTag = nil
                } else {
                    selectedTag = tag
                }
            }
        }
    }
    
    // MARK: - 热力图 & Rating 图

    // 计算可用的年份列表
    private var availableYears: [Int] {
        guard !allSubmissions.isEmpty else {
            return [Calendar.current.component(.year, from: Date())]
        }
        
        let years = Set(allSubmissions.map { submission in
            let date = Date(timeIntervalSince1970: TimeInterval(submission.creationTimeSeconds))
            return Calendar.current.component(.year, from: date)
        })
        
        return Array(years).sorted(by: >)
    }
    
    @ViewBuilder
    private var heatmapBox: some View {
        if let heatmapData {
            HeatmapView(
                data: heatmapData,
                availableYears: availableYears,
                selectedOption: selectedHeatmapOption,
                onSelectionChange: { selection in
                    selectedHeatmapOption = selection
                    updateHeatmapData()
                }
            )
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
            .opacity(loading ? 0 : 1)
            .animation(.easeOut(duration: 0.30), value: loading)
        } else {
            SkeletonChartBlock(height: 150)
        }
    }
    
    // 更新热力图数据的辅助方法
    private func updateHeatmapData() {
        guard !allSubmissions.isEmpty else { return }
        
        let viewType: HeatmapViewType
        switch selectedHeatmapOption {
        case .year(let year):
            viewType = .year(year)
        case .all:
            viewType = .rolling365
        }
        
        self.heatmapData = .calculate(from: allSubmissions, viewType: viewType)
    }
    
    @ViewBuilder
    private var ratingChartBox: some View {
        if ratings.isEmpty {
            if loading {
                SkeletonChartBlock(height: 260)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("暂无 rating 数据")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
            }
        } else {
            Chart {
                backgroundMarks
                seriesMarks
            }
            .chartYScale(domain: yAxisDomain)
            .chartYAxis { AxisMarks(position: .leading, values: intelligentlyFilteredBoundaries) }
            .chartXAxis {
                AxisMarks(preset: .automatic, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(); AxisTick()
                    if value.as(Date.self) != nil {
                        let timeSpan = (ratings.last?.date.timeIntervalSince1970 ?? 0) - (ratings.first?.date.timeIntervalSince1970 ?? 0)
                        let twoYears: TimeInterval = 2 * 365 * 24 * 60 * 60
                        let format = timeSpan > twoYears ? Date.FormatStyle.dateTime.year() : Date.FormatStyle.dateTime.month(.abbreviated)
                        AxisValueLabel(format: format, centered: true)
                    }
                }
            }
            .frame(height: 260)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
            .opacity(loading ? 0 : 1)
            .animation(.easeOut(duration: 0.30), value: loading)
        }
    }

    // MARK: - 数据加载

    private func reload(forceRefresh: Bool = false) async {
        // 已有数据时不展示骨架，避免闪烁
        let shouldShowSkeleton = (user == nil && activityStats == nil && heatmapData == nil && practiceBuckets.isEmpty)
        if shouldShowSkeleton { loading = true }
        fetchError = nil
        
        // 渐进式加载：先加载基础信息，再加载详细数据
        // 这样即使部分数据加载失败，也能显示基本信息
        
        // 第一阶段：加载核心用户信息（快速展示）
        var userInfo: CFUserInfo?
        var ratingHistory: [CFRatingUpdate] = []
        
        do {
            async let userInfoTask = CFAPI.shared.userInfo(handle: handle)
            async let ratingHistoryTask = CFAPI.shared.userRating(handle: handle)
            
            let (userInfoResult, ratingHistoryResult) = try await (userInfoTask, ratingHistoryTask)
            userInfo = userInfoResult
            ratingHistory = ratingHistoryResult
            
            // 先构建初始比赛记录（暂时只用 rated 比赛数据）
            let initialContests = await self.buildContestRecords(from: [], ratingHistory: ratingHistoryResult)
            
            // 立即更新基础信息
            await MainActor.run {
                self.user = userInfoResult
                self.ratings = ratingHistoryResult
                self.recentContests = initialContests
            }
        } catch {
            await MainActor.run { 
                self.fetchError = "无法加载用户基本信息：\(error.localizedDescription)"
                self.loading = false
            }
            return
        }
        
        // 第二阶段：加载提交数据和博客数量（允许部分失败）
        var allSubmissions: [CFSubmission] = []
        var blogCount = 0
        var secondaryErrors: [String] = []
        
        // 并发加载，但分别处理错误
        async let submissionsTask = CFAPI.shared.userAllSubmissions(handle: handle, forceRefresh: forceRefresh)
        async let blogCountTask = CFAPI.shared.userBlogEntryCount(handle: handle)
        
        // 提交数据
        do {
            allSubmissions = try await submissionsTask
        } catch {
            secondaryErrors.append("提交记录加载失败")
            // 继续使用旧数据或空数据
            allSubmissions = self.allSubmissions
        }
        
        // 博客数量（非关键数据，失败不影响）
        do {
            blogCount = try await blogCountTask
        } catch {
            // 使用默认值 0，不报错
            blogCount = userInfo?.blogEntryCount ?? 0
        }
        
        // 构建完整的比赛记录（在 MainActor.run 之前）
        let updatedContests = await self.buildContestRecords(from: allSubmissions, ratingHistory: ratingHistory)
        
        // 更新所有数据
        await MainActor.run {
            // 创建带博客数量的用户信息
            if let userInfo = userInfo {
                let enrichedUserInfo = CFUserInfo(
                    handle: userInfo.handle,
                    rating: userInfo.rating,
                    maxRating: userInfo.maxRating,
                    rank: userInfo.rank,
                    maxRank: userInfo.maxRank,
                    avatar: userInfo.avatar,
                    titlePhoto: userInfo.titlePhoto,
                    firstName: userInfo.firstName,
                    lastName: userInfo.lastName,
                    country: userInfo.country,
                    city: userInfo.city,
                    organization: userInfo.organization,
                    contribution: userInfo.contribution,
                    friendOfCount: userInfo.friendOfCount,
                    blogEntryCount: blogCount,
                    lastOnlineTimeSeconds: userInfo.lastOnlineTimeSeconds,
                    registrationTimeSeconds: userInfo.registrationTimeSeconds
                )
                
                self.user = enrichedUserInfo
                self.ratings = ratingHistory
                
                // 只有成功加载提交数据时才更新相关统计
                if !allSubmissions.isEmpty || self.allSubmissions.isEmpty {
                    self.activityStats = .calculate(from: allSubmissions)
                    
                    // 存储所有提交数据
                    self.allSubmissions = allSubmissions
                    
                    // 如果选中的年份在可用年份中，使用选中的年份；否则使用最新年份
                    let newAvailableYears = Set(allSubmissions.map { submission in
                        let date = Date(timeIntervalSince1970: TimeInterval(submission.creationTimeSeconds))
                        return Calendar.current.component(.year, from: date)
                    })
                    
                    // 更新选中选项，如果当前是年份选项但年份不存在，则切换到最新年份
                    switch self.selectedHeatmapOption {
                    case .year(let year):
                        if !newAvailableYears.contains(year) {
                            let latestYear = newAvailableYears.max() ?? Calendar.current.component(.year, from: Date())
                            self.selectedHeatmapOption = .year(latestYear)
                        }
                    case .all:
                        // All选项不需要年份验证
                        break
                    }
                    
                    // 根据当前选项更新热力图数据
                    self.updateHeatmapData()
                    self.practiceBuckets = PracticeHistogram.build(from: allSubmissions)
                    self.tagSlices = TagPie.build(from: allSubmissions, topK: 14) // Top 14
                    // 获取最近 20 条提交作为数据源（卡片中只显示 maxRecentSubmissionsToShow 条）
                    self.recentSubmissions = Array(allSubmissions.sorted(by: { $0.creationTimeSeconds > $1.creationTimeSeconds }).prefix(20))
                    
                    // 更新比赛记录（包括 unrated 比赛）
                    self.recentContests = updatedContests
                }
                
                // 统一存储为 API 返回的权威大小写，修正历史上保存的非标准大小写
                if self.handle != userInfo.handle {
                    self.handle = userInfo.handle
                }
                self.lastLoadedAt = Date()
            }
            
            // 如果有次要错误，显示警告而非完全失败
            if !secondaryErrors.isEmpty {
                self.fetchError = "⚠️ " + secondaryErrors.joined(separator: "；")
            }
            
            self.loading = false
        }
    }

    private func reloadIfNeeded(force: Bool = false) async {
        if !force, let last = lastLoadedAt, Date().timeIntervalSince(last) < profileSoftTTL {
            return
        }
        await reload(forceRefresh: force)
    }
    
    private func isValid(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return t.rangeOfCharacter(from: allowed.inverted) == nil && t.count <= 24
    }

    private func save() async {
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValid(t) else {
            loginError = "Handle 格式不正确"
            return
        }
        focused = false
        isSaving = true
        loginError = nil
        defer { isSaving = false }
        do {
            let userInfo = try await CFAPI.shared.userInfo(handle: t)
            await MainActor.run {
                // 使用 API 返回的权威大小写（如输入 xm，存储 Xm）
                handle = userInfo.handle
                input = userInfo.handle
                #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
            }
            // 登录成功后软重启（清缓存并重建根视图）
            await performSoftReload()
        } catch {
            await MainActor.run { self.loginError = "用户 '\(t)' 未找到" }
        }
    }
    
    // （已移除 WebView 自动登录逻辑）
    
    // MARK: - 图表辅助

    private func correctedAvatarURL(for user: CFUserInfo) -> String? {
        guard var urlString = user.titlePhoto ?? user.avatar else { return nil }
        // 1) 协议相对 // → https://
        if urlString.hasPrefix("//") { urlString = "https:" + urlString }
        // 2) 纯相对路径 /xxx → https://codeforces.com/xxx
        else if urlString.hasPrefix("/") { urlString = "https://codeforces.com" + urlString }
        // 3) 明确 http → https
        else if urlString.hasPrefix("http://") { urlString = urlString.replacingOccurrences(of: "http://", with: "https://") }
        return urlString
    }

    // MARK: - 最近提交行
    @ViewBuilder
    private func recentSubmissionRow(_ s: CFSubmission) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                // 左：判题结果圆点
                Circle()
                    .fill(colorForVerdict(CFVerdict.from(s.verdict)))
                    .frame(width: 10, height: 10)
                // 中：题号 + 名称
                VStack(alignment: .leading, spacing: 2) {
                    Text(problemTitle(s))
                        .font(.subheadline).bold()
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: 6) {
                        Text(CFVerdict.from(s.verdict).textWithTestInfo(passedTests: s.passedTestCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let lang = s.programmingLanguage, !lang.isEmpty {
                            Text(lang)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        
                        // 时间和内存消耗
                        if let timeMs = s.timeConsumedMillis {
                            Text("\(timeMs) ms")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let memoryBytes = s.memoryConsumedBytes {
                            Text("\(memoryBytes / 1024) KB")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                // 右：提交时间
                Text(shortTime(from: s.creationTimeSeconds))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func problemTitle(_ s: CFSubmission) -> String {
        let idx = s.problem.index
        let name = s.problem.name
        if let cid = s.contestId ?? s.problem.contestId {
            return "#\(cid) \(idx) · \(name)"
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
    
    // MARK: - 比赛记录行
    @ViewBuilder
    private func contestRecordRow(_ contest: ContestRecord) -> some View {
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
                        HStack(spacing: 3) {
                            Text("#\(contest.contestNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
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
                    // 排名显示
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
                    
                    // Rating变化（只有 rated 比赛才显示）
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
    
    // 格式化比赛日期
    private func contestDate(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd HH:mm"
        return df.string(from: date)
    }
    
    // 构建完整的比赛记录列表（包括 rated 和 unrated 比赛）
    private func buildContestRecords(from submissions: [CFSubmission], ratingHistory: [CFRatingUpdate]) async -> [ContestRecord] {
        // 1. 从 rating 历史中获取 rated 比赛信息
        let ratedContestMap = Dictionary(uniqueKeysWithValues: ratingHistory.map { ($0.contestId, $0) })
        
        // 2. 从提交记录中提取真正参加过的比赛 ID（只统计 CONTESTANT 和 OUT_OF_COMPETITION）
        let contestIdsFromSubmissions = Set(submissions.compactMap { submission -> Int? in
            guard let contestId = submission.contestId,
                  let participantType = submission.author?.participantType,
                  participantType == "CONTESTANT" || participantType == "OUT_OF_COMPETITION" else {
                return nil
            }
            return contestId
        })
        
        // 3. 合并所有比赛 ID
        let allContestIds = Set(ratedContestMap.keys).union(contestIdsFromSubmissions)
        
        // 4. 获取所有比赛列表（用于获取 unrated 比赛的完整名称）
        var contestMap: [Int: CFContest] = [:]
        do {
            let allContests = try await CFAPI.shared.allFinishedContests()
            contestMap = Dictionary(uniqueKeysWithValues: allContests.map { ($0.id, $0) })
        } catch {
            // 如果获取比赛列表失败，继续使用备选方案
            print("Failed to fetch contest list: \(error)")
        }
        
        // 5. 为每个比赛创建记录
        var records: [ContestRecord] = []
        
        for contestId in allContestIds {
            let ratedInfo = ratedContestMap[contestId]
            
            // 从提交记录中获取该比赛的所有提交（只统计赛时提交）
            let contestSubmissions = submissions.filter { submission in
                guard submission.contestId == contestId,
                      let participantType = submission.author?.participantType,
                      participantType == "CONTESTANT" || participantType == "OUT_OF_COMPETITION" else {
                    return false
                }
                return true
            }
            let firstSubmissionTime = contestSubmissions.map { $0.creationTimeSeconds }.min()
            
            // 确定日期：优先使用官方比赛开始时间，否则使用 rating 更新时间，最后使用第一次提交时间
            let date: Date
            if let contest = contestMap[contestId], let startTime = contest.startTimeSeconds {
                // 使用官方比赛开始时间
                date = Date(timeIntervalSince1970: TimeInterval(startTime))
            } else if let ratedInfo = ratedInfo {
                date = Date(timeIntervalSince1970: TimeInterval(ratedInfo.ratingUpdateTimeSeconds))
            } else if let submissionTime = firstSubmissionTime {
                date = Date(timeIntervalSince1970: TimeInterval(submissionTime))
            } else {
                continue // 既没有比赛信息也没有 rating 信息也没有提交记录，跳过
            }
            
            // 获取比赛名称：优先从 rating 历史，其次从比赛列表，最后用默认名称
            let contestName: String
            if let ratedInfo = ratedInfo {
                contestName = ratedInfo.contestName
            } else if let contest = contestMap[contestId] {
                contestName = contest.name
            } else {
                contestName = "Contest #\(contestId)"
            }
            
            // 统计赛时通过的题目数量（每个题目只算一次，取最早的 AC 提交）
            let solvedProblems = Set(contestSubmissions.filter { $0.verdict == "OK" }.map { $0.problem.index })
            let solvedCount = solvedProblems.count
            
            // 创建记录
            let record = ContestRecord(
                id: contestId,
                contestName: contestName,
                date: date,
                rank: ratedInfo?.rank,
                oldRating: ratedInfo?.oldRating,
                newRating: ratedInfo?.newRating,
                ratingChange: ratedInfo.map { $0.newRating - $0.oldRating },
                contestNumber: 0, // 稍后设置
                solvedCount: solvedCount
            )
            
            records.append(record)
        }
        
        // 6. 按时间排序（从旧到新）
        records.sort { $0.date < $1.date }
        
        // 7. 设置比赛序号（从 1 开始）
        records = records.enumerated().map { index, record in
            ContestRecord(
                id: record.id,
                contestName: record.contestName,
                date: record.date,
                rank: record.rank,
                oldRating: record.oldRating,
                newRating: record.newRating,
                ratingChange: record.ratingChange,
                contestNumber: index + 1,
                solvedCount: record.solvedCount
            )
        }
        
        // 8. 反转为从新到旧的顺序（最新的在前）
        return records.reversed()
    }

    // 提交详情查看已禁用
    // private func openSubmission(_ s: CFSubmission) {
    //     // 优先使用 contestId，构造到具体比赛的提交页
    //     if let cid = s.contestId ?? s.problem.contestId {
    //         let urlStr = "https://codeforces.com/contest/\(cid)/submission/\(s.id)"
    //         if let url = URL(string: urlStr) { presentedURL = IdentifiedURL(url: url) }
    //         else if let url = URL(string: "https://codeforces.com/contest/\(cid)") { presentedURL = IdentifiedURL(url: url) }
    //     } else {
    //         // 兜底：跳用户状态页
    //         let urlStr = "https://codeforces.com/submissions/\(handle)"
    //         if let url = URL(string: urlStr) { presentedURL = IdentifiedURL(url: url) }
    //     }
    // }
    
    private var yAxisDomain: ClosedRange<Int> {
        guard !ratings.isEmpty else { return 1000...2000 }
        let allRatings = ratings.flatMap { [$0.oldRating, $0.newRating] }
        let minRating = allRatings.min() ?? 1200
        let maxRating = allRatings.max() ?? 1600
        
        // 计算数据范围
        let dataRange = maxRating - minRating
        
        // 动态padding：范围越小，padding越小（最小10，最大80）
        let bottomPadding = max(10, min(80, dataRange / 10))
        let topPadding = max(10, min(80, dataRange / 10))
        
        let lowerBound = max(0, minRating - bottomPadding)
        let upperBound = maxRating + topPadding
        return lowerBound...upperBound
    }
    
    private var intelligentlyFilteredBoundaries: [Int] {
        let visibleBoundaries = ratingTiers.map { $0.range.lowerBound }.filter { yAxisDomain.contains($0) && $0 > 0 }
        guard !visibleBoundaries.isEmpty else { return [] }
        var finalBoundaries: [Int] = []
        var lastAddedBoundary = -1000
        let minSeparation = 150
        for boundary in visibleBoundaries {
            if boundary - lastAddedBoundary >= minSeparation {
                finalBoundaries.append(boundary)
                lastAddedBoundary = boundary
            }
        }
        return finalBoundaries
    }
    
    private var lineGradient: LinearGradient {
        let stops: [Gradient.Stop] = ratings.map { Gradient.Stop(color: colorForRating($0.newRating), location: 0) }
        guard let firstDate = ratings.first?.date, let lastDate = ratings.last?.date else {
            return LinearGradient(gradient: Gradient(colors: [.gray]), startPoint: .leading, endPoint: .trailing)
        }
        let timeSpan = lastDate.timeIntervalSince1970 - firstDate.timeIntervalSince1970
        if timeSpan == 0 { return LinearGradient(gradient: Gradient(stops: stops), startPoint: .leading, endPoint: .trailing) }
        let calculatedStops = zip(stops, ratings).map { (stop, rating) -> Gradient.Stop in
            let location = (rating.date.timeIntervalSince1970 - firstDate.timeIntervalSince1970) / timeSpan
            return Gradient.Stop(color: stop.color, location: location)
        }
        return LinearGradient(gradient: Gradient(stops: calculatedStops), startPoint: .leading, endPoint: .trailing)
    }
    
    @ChartContentBuilder
    private var backgroundMarks: some ChartContent {
        ForEach(ratingTiers, id: \.name) { tier in
            if let firstDate = ratings.first?.date, let lastDate = ratings.last?.date {
                let viewDomain = yAxisDomain
                let tierDomain = tier.range
                let visibleStartY = max(viewDomain.lowerBound, tierDomain.lowerBound)
                let visibleEndY = min(viewDomain.upperBound, tierDomain.upperBound)
                if visibleEndY >= visibleStartY {
                    RectangleMark(
                        xStart: .value("Start Time", firstDate), xEnd: .value("End Time", lastDate),
                        yStart: .value("Bottom Rating", visibleStartY), yEnd: .value("Top Rating", visibleEndY + 1)
                    ).foregroundStyle(tier.color.opacity(0.7))
                }
            }
        }
    }

    @ChartContentBuilder
    private var seriesMarks: some ChartContent {
        ForEach(ratings) { rating in
            LineMark(x: .value("Date", rating.date), y: .value("Rating", rating.newRating))
        }
        .interpolationMethod(.catmullRom)
        .foregroundStyle(cfYellow) // 使用CF黄色
        .lineStyle(StrokeStyle(lineWidth: 1.5)) // 调细线条
        
        ForEach(ratings) { r in
            PointMark(x: .value("时间", r.date), y: .value("Rating", r.newRating))
                .symbolSize(10)
                .foregroundStyle(cfYellow) // 点也改为黄色
        }
    }

    private let darkRed = Color(red: 0.7, green: 0, blue: 0)
    private let deepRed = Color(red: 0.54, green: 0, blue: 0) // 更深的红色用于3000+背景
    private let cfYellow = Color(red: 1.0, green: 0.8, blue: 0.0) // CF黄色曲线
    private var ratingTiers: [(name: String, range: ClosedRange<Int>, color: Color)] {
        [
            ("Newbie", 0...1199, .gray), ("Pupil", 1200...1399, .green),
            ("Specialist", 1400...1599, .cyan), ("Expert", 1600...1899, .blue),
            ("Candidate Master", 1900...2099, .purple), ("Master", 2100...2299, .yellow),
            ("International Master", 2300...2399, .orange), ("Grandmaster", 2400...2599, .red),
            ("International Grandmaster", 2600...2999, darkRed), ("Legendary Grandmaster", 3000...4999, deepRed)
        ]
    }
}

// MARK: - 会话清理与软重启
private extension ProfileView {
    // 轻量切换账号：仅清理网络缓存与 Cookie，并将 handle 清空，保留其他用户偏好
    func performSwitchAccount() async {
        await CFAPI.shared.resetSession()
        await MainActor.run {
            URLCache.shared.removeAllCachedResponses()
            HTTPCookieStorage.shared.removeCookies(since: .distantPast)
            let dataStore = WKWebsiteDataStore.default()
            dataStore.httpCookieStore.getAllCookies { cookies in
                for c in cookies { dataStore.httpCookieStore.delete(c) }
            }
            dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {}
            self.handle = ""
            NotificationCenter.default.post(name: .appReloadRequested, object: nil)
        }
    }
    func performLogoutAndReload() async {
        await CFAPI.shared.resetSession()
        await MainActor.run {
            URLCache.shared.removeAllCachedResponses()
            HTTPCookieStorage.shared.removeCookies(since: .distantPast)
            // 清理 WKWebView 的 Cookie 与网站数据（统一登出）
            let dataStore = WKWebsiteDataStore.default()
            dataStore.httpCookieStore.getAllCookies { cookies in
                for c in cookies { dataStore.httpCookieStore.delete(c) }
            }
            dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {}
            if let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
                UserDefaults.standard.synchronize()
            }
            NotificationCenter.default.post(name: .appReloadRequested, object: nil)
        }
    }

    func performSoftReload() async {
        await CFAPI.shared.resetSession()
        await MainActor.run {
            URLCache.shared.removeAllCachedResponses()
            HTTPCookieStorage.shared.removeCookies(since: .distantPast)
            let dataStore = WKWebsiteDataStore.default()
            dataStore.httpCookieStore.getAllCookies { cookies in
                for c in cookies { dataStore.httpCookieStore.delete(c) }
            }
            dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {}
            NotificationCenter.default.post(name: .appReloadRequested, object: nil)
        }
    }
}

// MARK: - 辅助定义

extension CFRatingUpdate {
    var date: Date { Date(timeIntervalSince1970: TimeInterval(ratingUpdateTimeSeconds)) }
}

// 提交详情查看已禁用，不再需要此结构体
// 便于使用 .sheet(item:) 的可识别 URL 容器
// private struct IdentifiedURL: Identifiable, Equatable {
//     let id = UUID()
//     let url: URL
// }

// MARK: - 所有提交（分页加载）Sheet
private struct AllSubmissionsSheet: View {
    let handle: String
    // let onOpen: (URL) -> Void // 已禁用提交详情查看

    @State private var submissions: [CFSubmission] = []
    @State private var isLoading: Bool = false
    @State private var isRefreshing: Bool = false
    @State private var error: String?
    @State private var nextFrom: Int = 1
    private let pageSize: Int = 100

    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.orange) }
            ForEach(submissions) { s in
                // 提交详情查看已禁用 - 避免Cookie相关问题
                VStack(spacing: 4) {
                    HStack(spacing: 10) {
                        Circle().fill(sheetColorForVerdict(CFVerdict.from(s.verdict))).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sheetProblemTitle(s)).font(.subheadline).bold().lineLimit(1)
                            HStack(spacing: 6) {
                                Text(CFVerdict.from(s.verdict).textWithTestInfo(passedTests: s.passedTestCount)).font(.caption).foregroundStyle(.secondary)
                                if let lang = s.programmingLanguage, !lang.isEmpty {
                                    Text(lang).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                
                                // 时间和内存消耗
                                if let timeMs = s.timeConsumedMillis {
                                    Text("\(timeMs) ms")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let memoryBytes = s.memoryConsumedBytes {
                                    Text("\(memoryBytes / 1024) KB")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                        Text(sheetShortTime(from: s.creationTimeSeconds)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                // Button {
                //     if let cid = s.contestId ?? s.problem.contestId,
                //        let url = URL(string: "https://codeforces.com/contest/\(cid)/submission/\(s.id)") {
                //         onOpen(url)
                //     } else if let url = URL(string: "https://codeforces.com/submissions/\(handle)") {
                //         onOpen(url)
                //     }
                // } label: {
                // }
            }
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowSeparator(.hidden)
            } else if !submissions.isEmpty {
                // 触底加载更多
                Color.clear.frame(height: 1)
                    .onAppear { Task { await loadMore() } }
            }
        }
        .listStyle(.plain)
        .task { await initialLoad() }
        .refreshable { await refresh() }
    }

    private func initialLoad() async { await refresh() }

    private func refresh() async {
        await MainActor.run { isRefreshing = true; error = nil; submissions = []; nextFrom = 1 }
        do {
            let first = try await CFAPI.shared.userSubmissionsPage(handle: handle, from: nextFrom, count: pageSize, forceRefresh: true)
            await MainActor.run {
                submissions = first
                nextFrom = first.count + 1
                isRefreshing = false
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription; self.isRefreshing = false }
        }
    }

    private func loadMore() async {
        guard !isLoading else { return }
        await MainActor.run { isLoading = true; error = nil }
        do {
            let more = try await CFAPI.shared.userSubmissionsPage(handle: handle, from: nextFrom, count: pageSize)
            await MainActor.run {
                if more.isEmpty { /* 到底 */ } else {
                    submissions.append(contentsOf: more)
                    nextFrom += more.count
                }
                isLoading = false
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription; self.isLoading = false }
        }
    }

    // MARK: - Helpers (local copy)
    private func sheetColorForVerdict(_ v: CFVerdict) -> Color {
        switch v {
        case .ok: return .green
        case .wrongAnswer: return .red
        case .timeLimit, .memoryLimit, .runtimeError, .compilationError, .presentationError: return .orange
        case .testing, .idlen: return .gray
        default: return .gray
        }
    }

    private func sheetProblemTitle(_ s: CFSubmission) -> String {
        let idx = s.problem.index
        let name = s.problem.name
        if let cid = s.contestId ?? s.problem.contestId {
            return "#\(cid) \(idx) · \(name)"
        } else {
            return "\(idx) · \(name)"
        }
    }

    private func sheetShortTime(from epoch: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epoch))
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: date)
    }
}

// MARK: - 查看全部比赛的 Sheet

private struct AllContestsSheet: View {
    let contests: [ContestRecord]
    
    var body: some View {
        List {
            if contests.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("暂无比赛记录")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
            } else {
                ForEach(contests) { contest in
                    VStack(spacing: 8) {
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
                                    Text(sheetContestDate(from: contest.date))
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
                                // 排名显示
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
                                
                                // Rating变化（只有 rated 比赛才显示）
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
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Helpers
    private func sheetContestDate(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd HH:mm"
        return df.string(from: date)
    }
}

