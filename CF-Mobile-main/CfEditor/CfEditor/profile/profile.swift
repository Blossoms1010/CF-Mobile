import SwiftUI
import Charts
import WebKit
import Kingfisher

// MARK: - 活动统计的数据模型与计算逻辑
struct ActivityStats {
    let totalSolved: Int
    let solvedLast30Days: Int
    let currentStreak: Int
    
    static func calculate(from submissions: [CFSubmission]) -> ActivityStats {
        let accepted = submissions.filter { $0.verdict == "OK" }
        let totalSolved = Set(accepted.map { $0.problem.id }).count
        
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let recentAccepted = accepted.filter {
            Date(timeIntervalSince1970: TimeInterval($0.creationTimeSeconds)) >= thirtyDaysAgo
        }
        let solvedLast30Days = Set(recentAccepted.map { $0.problem.id }).count
        
        let currentStreak = calculateCurrentStreak(from: accepted)
        
        return ActivityStats(totalSolved: totalSolved, solvedLast30Days: solvedLast30Days, currentStreak: currentStreak)
    }
    
    private static func calculateCurrentStreak(from acceptedSubmissions: [CFSubmission]) -> Int {
        guard !acceptedSubmissions.isEmpty else { return 0 }
        
        let cal = Calendar.current
        let solveDays = Set(
            acceptedSubmissions.map {
                cal.startOfDay(for: Date(timeIntervalSince1970: TimeInterval($0.creationTimeSeconds)))
            }
        )
        
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        
        // 只有“今天或昨天”有提交才算正在进行的 streak
        guard solveDays.contains(today) || solveDays.contains(yesterday) else {
            return 0
        }
        
        // ✅ 关键修复：如果今天没做、昨天做了，就从昨天开始往回数
        var checkDate = solveDays.contains(today) ? today : yesterday
        var streak = 0
        while solveDays.contains(checkDate) {
            streak += 1
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
        }
        return streak
    }
}

// MARK: - 热力图数据（按周×天对齐，带月份标签）
struct HeatmapData {
    let weeks: [[Date]]           // 53 周 × 7 天
    let dailyColors: [Date: Color]
    let monthLabels: [Int: String]

    static func calculate(from submissions: [CFSubmission]) -> HeatmapData {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // 周一为一周起始

        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)  // Sun=1...Sat=7
        let offsetToMonday = (weekday + 5) % 7
        let thisMonday = cal.date(byAdding: .day, value: -offsetToMonday, to: today)!
        let startMonday = cal.date(byAdding: .day, value: -52*7, to: thisMonday)! // 53 周（含本周）

        let ratedOK = submissions.filter { $0.verdict == "OK" && $0.problem.rating != nil }
        var dailyMax: [Date: Int] = [:]
        for s in ratedOK {
            let day = cal.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(s.creationTimeSeconds)))
            dailyMax[day] = max(dailyMax[day] ?? 0, s.problem.rating ?? 0)
        }

        let dailyColors: [Date: Color] = dailyMax.reduce(into: [:]) { dict, kv in
            dict[kv.key] = colorForRating(kv.value)
        }

        var weeks: [[Date]] = []
        for w in 0..<53 {
            var days: [Date] = []
            let monday = cal.date(byAdding: .day, value: w*7, to: startMonday)!
            for d in 0..<7 {
                days.append(cal.date(byAdding: .day, value: d, to: monday)!)
            }
            weeks.append(days)
        }

        let monthFmt: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "MMM"
            return f
        }()

        var monthLabels: [Int: String] = [:]
        var lastMonth: Int?
        for (i, week) in weeks.enumerated() {
            guard let firstDay = week.first else { continue }
            let m = Calendar.current.component(.month, from: firstDay)
            if m != lastMonth {
                monthLabels[i] = monthFmt.string(from: firstDay)
                lastMonth = m
            }
        }

        return HeatmapData(weeks: weeks, dailyColors: dailyColors, monthLabels: monthLabels)
    }
}

// MARK: - 热力图视图
struct HeatmapView: View {
    let data: HeatmapData

    private let cell: CGFloat = 10
    private let gap: CGFloat  = 3
    private let leftAxisWidth: CGFloat = 28
    private let topGap: CGFloat = 4

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: topGap) {

                    // 顶部月份
                    HStack(spacing: gap) {
                        Spacer().frame(width: leftAxisWidth)
                        ForEach(data.weeks.indices, id: \.self) { w in
                            Text(data.monthLabels[w] ?? "")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.2)
                                .frame(width: cell, alignment: .leading)
                        }
                    }

                    // 主体
                    HStack(alignment: .top, spacing: 6) {
                        // 左侧星期
                        VStack(alignment: .trailing, spacing: gap) {
                            ForEach(0..<7, id: \.self) { r in
                                Text(weekdayLabel(forRow: r))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: leftAxisWidth, height: cell, alignment: .trailing)
                            }
                        }
                        // 网格
                        HStack(spacing: gap) {
                            ForEach(data.weeks.indices, id: \.self) { w in
                                VStack(spacing: gap) {
                                    ForEach(0..<7, id: \.self) { r in
                                        let day = Calendar.current.startOfDay(for: data.weeks[w][r])
                                        let color = data.dailyColors[day] ?? Color(.systemGray6)
                                        RoundedRectangle(cornerRadius: 2.0)
                                            .fill(color)
                                            .frame(width: cell, height: cell)
                                    }
                                }
                                .id(w)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear {
                let last = max(0, data.weeks.count - 1)
                DispatchQueue.main.async {
                    proxy.scrollTo(last, anchor: .trailing)
                }
            }
        }
    }

    private func weekdayLabel(forRow r: Int) -> String {
        switch r {
        case 0: return "Mon"
        case 2: return "Wed"
        case 4: return "Fri"
        default: return ""
        }
    }
}

// MARK: - 练习柱状图：数据与计算（按题目 rating 分桶）

struct PracticeBucket: Identifiable {
    let key: String            // "800","900",...,"Unrated"
    let ratingFloor: Int?      // nil 代表 Unrated
    let count: Int
    var id: String { key }
}

enum PracticeHistogram {
    static func build(from submissions: [CFSubmission]) -> [PracticeBucket] {
        var solvedRatingByProblem: [String: Int] = [:]
        var unratedProblems: Set<String> = []

        for s in submissions where s.verdict == "OK" {
            let pid = s.problem.id
            if let r = s.problem.rating {
                if let old = solvedRatingByProblem[pid] {
                    if r > old { solvedRatingByProblem[pid] = r }
                } else {
                    solvedRatingByProblem[pid] = r
                }
            } else {
                unratedProblems.insert(pid)
            }
        }

        let ratedValues = Array(solvedRatingByProblem.values)
        let maxR = ratedValues.isEmpty ? 2600 : max(2600, ((ratedValues.max()! + 99) / 100) * 100)
        var counter: [Int: Int] = [:]
        for r in ratedValues {
            let b = (max(800, r) / 100) * 100
            counter[b, default: 0] += 1
        }

        var buckets: [PracticeBucket] = []
        var b = 800
        while b <= maxR {
            buckets.append(.init(key: "\(b)", ratingFloor: b, count: counter[b] ?? 0))
            b += 100
        }

        // 未评级列：固定在最后
        let unknown = unratedProblems.count
        buckets.append(.init(key: "Unrated", ratingFloor: nil, count: unknown))
        return buckets
    }
}

// MARK: - 标签分布（已 AC 题目，饼图用）
struct TagSlice: Identifiable {
    let tag: String
    let count: Int
    var id: String { tag }
}

enum TagPie {
    static func build(from submissions: [CFSubmission], topK: Int = 14) -> [TagSlice] {
        var solved: [String: CFProblem] = [:]
        for s in submissions where s.verdict == "OK" {
            solved[s.problem.id] = s.problem
        }
        guard !solved.isEmpty else { return [] }

        var counter: [String: Int] = [:]
        for p in solved.values {
            for t in (p.tags ?? []) where !t.isEmpty {
                counter[t, default: 0] += 1
            }
        }
        guard !counter.isEmpty else { return [] }

        let sorted = counter.sorted { $0.value > $1.value }
        let top = sorted.prefix(topK).map { TagSlice(tag: $0.key, count: $0.value) }
        let restSum = sorted.dropFirst(topK).reduce(0) { $0 + $1.value }
        var slices = top
        slices.append(TagSlice(tag: "Others", count: restSum)) // Others 永远在
        return slices
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
    @State private var presentedURL: IdentifiedURL? = nil
    @State private var showAllSubmissionsSheet: Bool = false

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
            
            // 用户信息：Skeleton + 淡入
            Section {
                if loading {
                    SkeletonUserCard()
                } else if let user {
                    ratingBox(for: user)
                        .opacity(loading ? 0 : 1)
                        .animation(.easeOut(duration: 0.25), value: loading)
                }
            }
            
            // 活动统计：Skeleton + 淡入
            Section {
                if loading {
                    SkeletonStatsRow()
                } else {
                    activityStatsBox
                        .opacity(loading ? 0 : 1)
                        .animation(.easeOut(duration: 0.25), value: loading)
                }
            } header: {
                Label("活动统计", systemImage: "chart.bar.xaxis")
            }

            // Rating 曲线：Skeleton + 淡入
            Section { ratingChartBox } header: {
                Label("Rating 曲线", systemImage: "chart.line.uptrend.xyaxis")
            }
            
            // 热力图：Skeleton + 淡入
            Section { heatmapBox } header: {
                Label("年度活动热力图", systemImage: "grid")
            }
            
            // 练习柱状图：Skeleton + 淡入 + 数据变化动画
            Section { practiceHistogramBox } header: {
                Label("练习分布（按题目难度）", systemImage: "chart.bar")
            }
            
            // 标签分布：Skeleton + 淡入 + 数据变化动画
            Section { tagPieBox } header: {
                Label("标签分布（已 AC）", systemImage: "chart.pie")
            }

            // 最近提交：最多展示 10 条
            Section {
                if loading {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.18))
                                .frame(height: 44)
                                .shimmer()
                        }
                    }
                    .padding(.vertical, 4)
                } else if recentSubmissions.isEmpty {
                    Text("暂无提交记录").foregroundStyle(.secondary)
                } else {
                    ForEach(recentSubmissions) { s in
                        recentSubmissionRow(s)
                            .contentShape(Rectangle())
                            .onTapGesture { openSubmission(s) }
                    }
                }
            } header: {
                Label("最近提交", systemImage: "clock")
            } footer: {
                if !loading && !recentSubmissions.isEmpty {
                    HStack {
                        Spacer()
                        Button {
                            showAllSubmissionsSheet = true
                        } label: {
                            Label("More", systemImage: "list.bullet")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 6)
                }
            }

            // 设置
            Section {
                NavigationLink {
                    ProfileSettingsView()
                } label: {
                    HStack {
                        Spacer()
                        Label("设置", systemImage: "gear")
                        Spacer()
                    }
                }
            }

            // 退出
            Section {
                Button("退出登录", role: .destructive) {
                    Task { await performLogoutAndReload() }
                }
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle(handle)
        .task(id: handle.lowercased()) { await reloadIfNeeded() }
        // 尝试用当前 Web 会话中的登录账号校正 handle（解决 handle 与实际登录态不一致的问题）
        .task {
            if let h = await CFCookieBridge.shared.readCurrentCFHandleFromWK(), h.lowercased() != handle.lowercased() {
                // 仅当 Cookie 中的 X-User 合法时覆盖（readCurrentCFHandleFromWK 已校验）
                handle = h
            }
        }
        .refreshable { await reload(forceRefresh: true) }
        .sheet(item: $presentedURL) { item in
            NavigationStack {
                SubmissionDetailWebView(url: item.url, targetURLString: item.url.absoluteString)
                    .navigationTitle("提交详情")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("关闭") { presentedURL = nil } }
                        ToolbarItem(placement: .navigationBarTrailing) { Button("刷新") { NotificationCenter.default.post(name: .init("SubmissionWebView.ReloadRequested"), object: nil) } }
                    }
            }
        }
        .sheet(isPresented: $showAllSubmissionsSheet) {
            NavigationStack {
                AllSubmissionsSheet(handle: handle) { url in
                    presentedURL = IdentifiedURL(url: url)
                }
                .navigationTitle("所有提交")
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
                .padding(.top, 4)
                .opacity(loading ? 0 : 1)
                .animation(.easeOut(duration: 0.35),
                           value: practiceBuckets.map(\.count).reduce(0, +)) // 数据变化动画
                .animation(.easeOut(duration: 0.30), value: loading)        // 淡入
            }
        }
    }
    
    // MARK: - 用户信息卡片

    @ViewBuilder
    private func ratingBox(for user: CFUserInfo) -> some View {
        let cur = user.rating ?? ratings.last?.newRating ?? 0
        let mx  = user.maxRating ?? ratings.map{ $0.newRating }.max() ?? cur
        let isUnrated = (user.rating == nil)
        
        HStack(spacing: 12) {
            AvatarView(urlString: correctedAvatarURL(for: user))
            VStack(alignment: .leading, spacing: 6) {
                // 称号 + 昵称同一行
                HStack(spacing: 8) {
                    if !isUnrated {
                        RankBadge(rank: user.rank)
                    }
                    Text(user.handle)
                        .font(.headline).bold()
                        .foregroundStyle(isUnrated ? .black : colorForRating(cur))
                }
                // rating 行（数字等宽）
                HStack(spacing: 6) {
                    if isUnrated {
                        Text("Unrated").font(.title3).bold().foregroundStyle(.black)
                    } else {
                        Text("Rating:").font(.subheadline).foregroundStyle(.secondary)
                        Text("\(cur)").font(.title2).bold().foregroundStyle(colorForRating(cur)).monospacedDigit()
                        HStack(spacing: 0) {
                            Text("(max ").foregroundStyle(.secondary)
                            Text("\(mx)").bold().foregroundStyle(colorForRating(mx)).monospacedDigit()
                            Text(")").foregroundStyle(.secondary)
                        }.font(.subheadline)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - 活动统计

    @ViewBuilder
    private var activityStatsBox: some View {
        HStack(spacing: 0) {
            statItem(value: activityStats?.totalSolved,
                     label: "solved in total",
                     icon: "checkmark.circle")

            Divider().padding(.vertical, 6)

            statItem(value: activityStats?.solvedLast30Days,
                     label: "solved in 30d",
                     icon: "calendar")

            Divider().padding(.vertical, 6)

            statItem(value: activityStats?.currentStreak,
                     label: "days in a row",
                     icon: "flame")
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func statItem(value: Int?, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            if let value {
                Text(String(value))
                    .font(.title2).bold().monospacedDigit()
                    .transition(.opacity.combined(with: .scale))
            } else if loading {
                ProgressView().progressViewStyle(.circular)
            } else {
                Text("--").font(.title2).bold().monospacedDigit()
            }

            // 紧凑的“图标 + 文案”，并禁止换行
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .fixedSize(horizontal: false, vertical: true) // 防止因压缩导致换行高度变动
        }
        .frame(maxWidth: .infinity) // 三栏等宽分布
        .animation(.default, value: value)
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
            HStack(alignment: .center, spacing: 12) {
                // 左侧：图形
                Group {
                    if #available(iOS 17.0, *) {
                        Chart(tagSlicesNZ) { s in
                            SectorMark(
                                angle: .value("Count", s.count),
                                innerRadius: .ratio(0.55)
                            )
                            .foregroundStyle(by: .value("Tag", s.tag))
                        }
                        .chartForegroundStyleScale(domain: tagDomain, range: tagRange)
                        .chartLegend(.hidden)
                    } else {
                        Chart(tagSlicesNZ) { s in
                            BarMark(
                                x: .value("数量", s.count),
                                y: .value("标签", s.tag)
                            )
                            .foregroundStyle(by: .value("Tag", s.tag))
                            .cornerRadius(3)
                        }
                        .chartForegroundStyleScale(domain: tagDomain, range: tagRange)
                        .chartLegend(.hidden)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: tagChartHeight, maxHeight: tagChartHeight)
                .opacity(loading ? 0 : 1)
                .animation(.easeOut(duration: 0.35), value: tagTotalCount)     // 数据变化动画
                .animation(.easeOut(duration: 0.35), value: tagSlicesNZ.count) // 数据项增减动画
                .animation(.easeOut(duration: 0.30), value: loading)           // 淡入

                Divider()

                // 右侧：单列可滚动图例（标签名在上，数量+百分比在下）
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(tagDomain, id: \.self) { tag in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(tagColorMapComputed[tag] ?? .accentColor)
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    // 第一行：标签名
                                    Text(tag)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    // 第二行：数量 + 百分比（等宽数字）
                                    HStack(spacing: 6) {
                                        Text("\(tagCountsByTag[tag] ?? 0)")
                                            .font(.caption2)
                                            .monospacedDigit()
                                            .foregroundStyle(.secondary)
                                        Text(tagPercentString(for: (tagCountsByTag[tag] ?? 0)))
                                            .font(.caption2)
                                            .monospacedDigit()
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(width: tagLegendWidth, height: tagChartHeight)
            }
            .frame(height: tagChartHeight)
        }
    }
    
    // MARK: - 热力图 & Rating 图

    @ViewBuilder
    private var heatmapBox: some View {
        if let heatmapData {
            HeatmapView(data: heatmapData)
                .padding(.vertical, 8)
                .opacity(loading ? 0 : 1)
                .animation(.easeOut(duration: 0.30), value: loading)
        } else {
            SkeletonChartBlock(height: 120)
        }
    }
    
    @ViewBuilder
    private var ratingChartBox: some View {
        if ratings.isEmpty {
            if loading {
                SkeletonChartBlock(height: 260)
            } else {
                Text("暂无 rating 数据").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
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
                    if let date = value.as(Date.self) {
                        let timeSpan = (ratings.last?.date.timeIntervalSince1970 ?? 0) - (ratings.first?.date.timeIntervalSince1970 ?? 0)
                        let twoYears: TimeInterval = 2 * 365 * 24 * 60 * 60
                        let format = timeSpan > twoYears ? Date.FormatStyle.dateTime.year() : Date.FormatStyle.dateTime.month(.abbreviated)
                        AxisValueLabel(format: format, centered: true)
                    }
                }
            }
            .frame(height: 260)
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
        
        do {
            async let userInfoTask = CFAPI.shared.userInfo(handle: handle)
            async let ratingHistoryTask = CFAPI.shared.userRating(handle: handle)
            async let submissionsTask = CFAPI.shared.userAllSubmissions(handle: handle, forceRefresh: forceRefresh)
            
            let (userInfo, ratingHistory, allSubmissions) = try await (userInfoTask, ratingHistoryTask, submissionsTask)
            
            await MainActor.run {
                self.user = userInfo
                self.ratings = ratingHistory
                self.activityStats = .calculate(from: allSubmissions)
                self.heatmapData = .calculate(from: allSubmissions)
                self.practiceBuckets = PracticeHistogram.build(from: allSubmissions)
                self.tagSlices = TagPie.build(from: allSubmissions, topK: 14) // Top 14
                self.recentSubmissions = Array(allSubmissions.sorted(by: { $0.creationTimeSeconds > $1.creationTimeSeconds }).prefix(10))
                // 统一存储为 API 返回的权威大小写，修正历史上保存的非标准大小写
                if self.handle != userInfo.handle {
                    self.handle = userInfo.handle
                }
                self.lastLoadedAt = Date()
            }
        } catch {
            await MainActor.run { self.fetchError = error.localizedDescription }
        }
        
        await MainActor.run { loading = false }
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
                    Text(CFVerdict.from(s.verdict).displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let lang = s.programmingLanguage, !lang.isEmpty {
                        Text(lang)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            // 右：时间
            Text(shortTime(from: s.creationTimeSeconds))
                .font(.caption)
                .foregroundStyle(.secondary)
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
        let now = Date()
        let diff = now.timeIntervalSince(date)
        if diff < 60 { return "刚刚" }
        if diff < 3600 { return "\(Int(diff/60)) 分钟前" }
        if diff < 86_400 { return "\(Int(diff/3600)) 小时前" }
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

    private func openSubmission(_ s: CFSubmission) {
        // 优先使用 contestId，构造到具体比赛的提交页
        if let cid = s.contestId ?? s.problem.contestId {
            let urlStr = "https://codeforces.com/contest/\(cid)/submission/\(s.id)"
            if let url = URL(string: urlStr) { presentedURL = IdentifiedURL(url: url) }
            else if let url = URL(string: "https://codeforces.com/contest/\(cid)") { presentedURL = IdentifiedURL(url: url) }
        } else {
            // 兜底：跳用户状态页
            let urlStr = "https://codeforces.com/submissions/\(handle)"
            if let url = URL(string: urlStr) { presentedURL = IdentifiedURL(url: url) }
        }
    }
    
    private var yAxisDomain: ClosedRange<Int> {
        guard !ratings.isEmpty else { return 1000...2000 }
        let allRatings = ratings.flatMap { [$0.oldRating, $0.newRating] }
        let minRating = allRatings.min() ?? 1200
        let maxRating = allRatings.max() ?? 1600
        let lowerBound = max(0, minRating - 150)
        let upperBound = maxRating + 150
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
                let viewDomain = yAxisDomain; let tierDomain = tier.range
                let visibleStartY = max(viewDomain.lowerBound, tierDomain.lowerBound)
                let visibleEndY = min(viewDomain.upperBound, tierDomain.upperBound)
                if visibleEndY > visibleStartY {
                    RectangleMark(
                        xStart: .value("Start Time", firstDate), xEnd: .value("End Time", lastDate),
                        yStart: .value("Bottom Rating", visibleStartY), yEnd: .value("Top Rating", visibleEndY)
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
        .interpolationMethod(.cardinal)
        .foregroundStyle(lineGradient)
        
        ForEach(ratings) { r in
            PointMark(x: .value("时间", r.date), y: .value("Rating", r.newRating))
                .symbolSize(10)
                .foregroundStyle(colorForRating(r.newRating))
        }
    }

    private let darkRed = Color(red: 0.7, green: 0, blue: 0)
    private var ratingTiers: [(name: String, range: Range<Int>, color: Color)] {
        [
            ("Newbie", 0..<1200, .gray), ("Pupil", 1200..<1400, .green),
            ("Specialist", 1400..<1600, .cyan), ("Expert", 1600..<1900, .blue),
            ("Candidate Master", 1900..<2100, .purple), ("Master", 2100..<2300, .yellow),
            ("International Master", 2300..<2400, .orange), ("Grandmaster", 2400..<2600, .red),
            ("International Grandmaster", 2600..<3000, darkRed), ("Legendary Grandmaster", 3000..<5000, darkRed)
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

// 便于使用 .sheet(item:) 的可识别 URL 容器
private struct IdentifiedURL: Identifiable, Equatable {
    let id = UUID()
    let url: URL
}

// MARK: - 所有提交（分页加载）Sheet
private struct AllSubmissionsSheet: View {
    let handle: String
    let onOpen: (URL) -> Void

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
                Button {
                    if let cid = s.contestId ?? s.problem.contestId,
                       let url = URL(string: "https://codeforces.com/contest/\(cid)/submission/\(s.id)") {
                        onOpen(url)
                    } else if let url = URL(string: "https://codeforces.com/submissions/\(handle)") {
                        onOpen(url)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Circle().fill(sheetColorForVerdict(CFVerdict.from(s.verdict))).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sheetProblemTitle(s)).font(.subheadline).bold().lineLimit(1)
                            HStack(spacing: 6) {
                                Text(CFVerdict.from(s.verdict).displayText).font(.caption).foregroundStyle(.secondary)
                                if let lang = s.programmingLanguage, !lang.isEmpty {
                                    Text(lang).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                        }
                        Spacer()
                        Text(sheetShortTime(from: s.creationTimeSeconds)).font(.caption).foregroundStyle(.secondary)
                    }
                }
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
        let now = Date()
        let diff = now.timeIntervalSince(date)
        if diff < 60 { return "刚刚" }
        if diff < 3600 { return "\(Int(diff/60)) 分钟前" }
        if diff < 86_400 { return "\(Int(diff/3600)) 小时前" }
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: date)
    }
}

struct AvatarView: View {
    let urlString: String?
    
    private var placeholder: some View {
        Circle().fill(Color.secondary.opacity(0.2))
            .overlay(Image(systemName: "person").imageScale(.large))
            .frame(width: 48, height: 48)
    }

    var body: some View {
        Group {
            if let url = URL(string: urlString ?? ""), !url.absoluteString.isEmpty {
                KFImage(url)
                    .placeholder { placeholder }
                    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 96, height: 96)))
                    .cacheOriginalImage()
                    .fade(duration: 0.2)
                    .cancelOnDisappear(true)
                    .onFailure { _ in }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            } else {
                placeholder
            }
        }
    }
}

func colorForRating(_ rating: Int) -> Color {
    let darkRed = Color(red: 0.7, green: 0, blue: 0)
    switch rating {
    case ..<1200: return .gray
    case 1200..<1400: return .green
    case 1400..<1600: return .cyan
    case 1600..<1900: return .blue
    case 1900..<2100: return .purple
    case 2100..<2300: return .yellow
    case 2300..<2400: return .orange
    case 2400..<2600: return .red
    case 2600..<3000: return darkRed
    default: return darkRed
    }
}

// 称号（返回英文）
func chineseTitle(for rank: String?) -> String {
    switch (rank ?? "").lowercased() {
    case "newbie": return "Newbie"
    case "pupil": return "Pupil"
    case "specialist": return "Specialist"
    case "expert": return "Expert"
    case "candidate master": return "Candidate Master"
    case "master": return "Master"
    case "international master": return "International Master"
    case "grandmaster": return "Grandmaster"
    case "international grandmaster": return "International Grandmaster"
    case "legendary grandmaster": return "Legendary Grandmaster"
    default: return "Unrated"
    }
}

func colorForRank(_ rank: String?) -> Color {
    switch (rank ?? "").lowercased() {
    case "newbie": return colorForRating(1000)
    case "pupil": return colorForRating(1300)
    case "specialist": return colorForRating(1500)
    case "expert": return colorForRating(1700)
    case "candidate master": return colorForRating(1950)
    case "master": return colorForRating(2150)
    case "international master": return colorForRating(2350)
    case "grandmaster": return colorForRating(2450)
    case "international grandmaster": return colorForRating(2650)
    case "legendary grandmaster": return colorForRating(3000)
    default: return .gray
    }
}

struct RankBadge: View {
    let rank: String?
    var body: some View {
        let title = chineseTitle(for: rank)
        let color = colorForRank(rank)
        Text(title)
            .font(.caption2).bold()
            .padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// --- Skeleton 组件 ---

private struct SkeletonUserCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Color.secondary.opacity(0.20))
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.20))
                    .frame(width: 120, height: 14)
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.20))
                    .frame(width: 180, height: 12)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading) // ⬅️ 撑满行宽
        .redacted(reason: .placeholder)
        // ✅ 更强的闪动效果
        .shimmer(duration: 0.65, bounce: true, angle: 0, intensity: 0.60, bandScale: 1.70)
    }
}

private struct SkeletonChartBlock: View {
    let height: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.18))
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .redacted(reason: .placeholder)
            .shimmer() // 默认参数即可
    }
}

private struct SkeletonStatsRow: View {
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.20))
                    .frame(width: 36, height: 20)
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.18))
                    .frame(width: 48, height: 10)
            }
            Spacer()
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.20))
                    .frame(width: 36, height: 20)
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.18))
                    .frame(width: 48, height: 10)
            }
            Spacer()
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.20))
                    .frame(width: 36, height: 20)
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.18))
                    .frame(width: 48, height: 10)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 64) // ⬅️ 撑满行宽
        .padding(.vertical, 8)
        .redacted(reason: .placeholder)
        .shimmer() // 默认参数即可
    }
}

// MARK: - Shimmer 闪动效果（水平左→右，更明显）
private struct ShimmerModifier: ViewModifier {
    var duration: Double = 0.70       // 速度：越小越快（更快）
    var bounce: Bool = true           // 是否来回扫（开启更显眼）
    var angle: Double = 0             // ⬅️ 水平扫光（0 度）
    var intensity: Double = 0.60      // 亮度峰值更高
    var bandScale: CGFloat = 1.65     // 扫光带更宽
    var blendMode: BlendMode = .screen// 叠加更亮

    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let size = geo.size
                    let highlight = Color.white
                    let gradient = LinearGradient(
                        colors: [highlight.opacity(0.0),
                                 highlight.opacity(intensity),
                                 highlight.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    )
                    let bandW = max(size.width, size.height) * bandScale
                    let bandH = bandW * 3

                    Rectangle()
                        .fill(gradient)
                        .frame(width: bandW, height: bandH)
                        .rotationEffect(.degrees(angle))     // 0° = 纯水平
                        .offset(x: phase * (size.width + bandW))
                        .blendMode(blendMode)
                        .compositingGroup()                  // ✅ 防止混合异常
                        .allowsHitTesting(false)             // ✅ 不挡交互
                }
                .mask(content)
            )
            .onAppear {
                phase = -1
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: bounce)) {
                    phase = 1
                }
            }
    }
}

private extension View {
    func shimmer(
        duration: Double = 0.70,
        bounce: Bool = true,
        angle: Double = 0,
        intensity: Double = 0.60,
        bandScale: CGFloat = 1.65,
        blendMode: BlendMode = .screen
    ) -> some View {
        modifier(ShimmerModifier(
            duration: duration,
            bounce: bounce,
            angle: angle,
            intensity: intensity,
            bandScale: bandScale,
            blendMode: blendMode
        ))
    }
}
