import SwiftUI
import CryptoKit

struct ContestsView: View {
    @AppStorage("cfHandle") private var handle: String = ""
    @StateObject var store: ContestsStore
    @StateObject private var problemsetStore = ProblemsetStore()

    // 分段控制器状态
    @State private var selectedMode: PracticeMode = .contests
    
    // 仅在本视图内维护展开状态（如需跨页持久，可换成 SceneStorage 自行序列化）
    @State private var expandedContests: [Int: Bool] = [:]
    
    // 计算属性：兼容原代码中使用 Set<Int> 的地方
    private var expanded: Set<Int> {
        Set(expandedContests.filter { $0.value }.map { $0.key })
    }
    
    // 用于导航到题面页面，避免每个条目提前构建目的视图导致"全开"
    @State private var selectedProblem: CFProblem?
    
    // 题库相关状态
    @State private var showingFilterSheet: Bool = false
    
    // 比赛相关状态
    @State private var showingContestFilterSheet: Bool = false
    
    // 搜索状态
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    
    // 倒计时更新定时器
    @State private var countdownTimer: Timer?
    @State private var currentTime = Date()
    
    // 收藏相关状态
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var showingFavorites = false

    var body: some View {
        VStack(spacing: 0) {
            // 自定义分段控制器
            CustomSegmentedPicker(selection: $selectedMode)
                .padding(.horizontal)
                .padding(.vertical, 8)
            
            Divider()
            
            // 根据选择的模式显示不同内容
            Group {
                switch selectedMode {
                case .contests:
                    contestsListView
                case .problemset:
                    problemsetListView
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 左上角：收藏按钮
            ToolbarItem(placement: .navigationBarLeading) {
                favoritesButtonView
            }
            
            // 顶部中央：精美搜索栏
            ToolbarItem(placement: .principal) {
                searchBarView
            }
            
            // 右上角：精美过滤按钮
            ToolbarItem(placement: .navigationBarTrailing) {
                filterButtonView
            }
        }
        // 切换模式时同步搜索文本
        .onChange(of: selectedMode) { _, newMode in
            if newMode == .contests {
                searchText = store.filter.searchText
            } else {
                searchText = problemsetStore.filter.searchText
            }
        }
        // 初次进入时确保数据加载
        .task {
            await store.ensureLoaded(currentHandle: handle)
            await problemsetStore.ensureLoaded(currentHandle: handle)
        }
        // 切换账号/退出登录才触发重载
        .onChange(of: handle.lowercased()) { _, _ in
            Task {
                await store.handleChanged(to: handle)
                await problemsetStore.handleChanged(to: handle)
                
                // 主动刷新当前可见页的题目与进度
                if selectedMode == .contests {
                    let ids = store.vms.map { $0.id }
                    for cid in ids { await store.ensureProblemsLoaded(contestId: cid, force: true) }
                }
            }
        }
        // 手动下拉刷新
        .refreshable {
            switch selectedMode {
            case .contests:
                await store.forceRefresh(currentHandle: handle)
                let ids = store.vms.map { $0.id }
                for cid in ids { await store.ensureProblemsLoaded(contestId: cid, force: true) }
            case .problemset:
                await problemsetStore.forceRefresh(currentHandle: handle)
            }
        }
        // 仅在选择了某个题目时才构建并跳转目的视图
        .navigationDestination(item: $selectedProblem) { p in
            ProblemViewerWrapper(problem: p)
        }
        // 题库过滤器弹窗
        .sheet(isPresented: $showingFilterSheet) {
            ProblemsetFilterView(store: problemsetStore)
        }
        // 比赛过滤器弹窗
        .sheet(isPresented: $showingContestFilterSheet) {
            ContestFilterView(store: store)
        }
        // 收藏题目弹窗
        .sheet(isPresented: $showingFavorites) {
            FavoritesSheetView(
                favoritesManager: favoritesManager,
                problemsetStore: problemsetStore,
                selectedProblem: $selectedProblem
            )
        }
        // 倒计时定时器管理
        .onAppear {
            startCountdownTimer()
        }
        .onDisappear {
            stopCountdownTimer()
        }
    }
    
    // MARK: - 工具栏视图
    private var searchBarView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isSearchFocused ? .accentColor : .secondary)
                .scaleEffect(isSearchFocused ? 1.15 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSearchFocused)
            
            TextField(selectedMode == .contests ? "Search contests..." : "Search problems...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.primary)
                .focused($isSearchFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: searchText) { _, newValue in
                    // 实时搜索
                    if selectedMode == .contests {
                        store.filter.searchText = newValue
                        store.applyFilters()
                    } else {
                        problemsetStore.filter.searchText = newValue
                        problemsetStore.applyFilters()
                    }
                }
            
            if !searchText.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(width: 300, height: 36)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray6))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSearchFocused ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSearchFocused)
    }
    
    // MARK: - 收藏按钮
    private var favoritesButtonView: some View {
        Button {
            showingFavorites = true
        } label: {
            Image(systemName: favoritesManager.favorites.isEmpty ? "star" : "star.fill")
                .font(.system(size: 20))
                .foregroundColor(favoritesManager.favorites.isEmpty ? .secondary : .yellow)
                .symbolEffect(.bounce, value: favoritesManager.favorites.count)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var filterButtonView: some View {
        if selectedMode == .problemset {
            Button {
                showingFilterSheet = true
            } label: {
                ZStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 20))
                        .symbolRenderingMode(problemsetStore.filter.hasActiveFilters ? .multicolor : .monochrome)
                    
                    if problemsetStore.filter.hasActiveFilters {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .buttonStyle(.plain)
        } else if selectedMode == .contests {
            Button {
                showingContestFilterSheet = true
            } label: {
                ZStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 20))
                        .symbolRenderingMode(store.filter.hasActiveFilters ? .multicolor : .monochrome)
                    
                    if store.filter.hasActiveFilters {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    private var contestsListView: some View {
        List {
            
            // 未登录提示 - 美化版
            if handle.trimmed.isEmpty {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 28))
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("未填写 Handle")
                                .font(.system(size: 15, weight: .medium))
                            Text("去\"我的\"页输入 Handle 后，可显示做题进度")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }

            // 页面级 loading / error - 使用骨架屏
            if store.loading && store.vms.isEmpty {
                ForEach(0..<5, id: \.self) { _ in
                    Section {
                        SkeletonListRow()
                    }
                }
            } else if let err = store.pageError {
                Section { 
                    Text(err)
                        .foregroundColor(.red)
                        .font(.callout)
                }
            }

            // 比赛列表 - 分块显示
            let (upcomingContests, ongoingContests, finishedContests) = partitionContests(store.vms)
            
            // 第一块：即将开始/正在进行的比赛（可展开）
            if !upcomingContests.isEmpty {
                Section {
                    // 区块标题
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14, weight: .semibold))
                        Text("即将开始/正在进行")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    
                    // 比赛列表 - 每个比赛独立成行
                    ForEach(Array(upcomingContests.enumerated()), id: \.element.id) { index, vm in
                        contestRow(for: vm, index: index)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
            }
            
            // 第二块：正在进行的比赛（已合并到第一块）
            if !ongoingContests.isEmpty {
                Section {
                    // 区块标题
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("正在进行")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    
                    // 比赛列表 - 每个比赛独立成行
                    ForEach(Array(ongoingContests.enumerated()), id: \.element.id) { index, vm in
                        contestRow(for: vm, index: index)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
            }
            
            // 第三块：已结束的比赛（可展开）
            if !finishedContests.isEmpty {
                Section {
                    // 区块标题
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("已结束")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    
                    // 比赛列表 - 每个比赛独立成行
                    ForEach(Array(finishedContests.enumerated()), id: \.element.id) { index, vm in
                        contestRow(for: vm, index: index)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
            }

            // 底部加载更多（类似"上拉加载"体验）
            if store.hasMore {
                Section {
                    HStack { Spacer(); ProgressView(); Text("Loading..."); Spacer() }
                        .onAppear {
                            if store.filter.hasActiveFilters {
                                store.loadMoreFilteredIfNeeded()
                            } else {
                                store.loadMoreIfNeeded()
                            }
                        }
                }
            }
            
            // 底部占位空间，避免被 TabBar 遮挡
            Section {
                Color.clear
                    .frame(height: 60)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: expanded)
        .animation(.default, value: store.vms)
    }

    private func problemStateForDisplay(vmId: Int, p: CFProblem) -> ProblemAttemptState {
        // 先按 contestId+index 精确命中
        let key = ProblemKey(contestId: p.contestId ?? vmId, index: p.index)
        if let s = store.problemAttemptMap[key] { return s }
        // 退化到“按题名归并”的跨场匹配（处理 Div1/Div2 同题）
        let norm = normalizeProblemName(p.name)
        return store.problemAttemptByName[norm] ?? .none
    }

    private func normalizeProblemName(_ name: String) -> String {
        let lowered = name.lowercased()
        let trimmed = lowered.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsedSpaces = trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return collapsedSpaces
    }

    // 计算倒计时文本
    private func countdownText(to targetDate: Date) -> String {
        let interval = targetDate.timeIntervalSince(currentTime)
        
        if interval <= 0 {
            return "已开始"
        }
        
        let totalSeconds = Int(interval)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        // 48小时内显示时分秒
        if totalSeconds < 48 * 3600 {
            return String(format: "%02d:%02d:%02d", hours + days * 24, minutes, seconds)
        } else {
            // 超过48小时显示天数
            return "\(days)天"
        }
    }
    
    @ViewBuilder private func rowHeader(_ vm: ContestVM) -> some View {
        let trimmed = handle.trimmed
        let solved: Int = {
            if let probs = store.problemCache[vm.id] {
                return probs.reduce(0) { acc, p in
                    acc + (problemStateForDisplay(vmId: vm.id, p: p) == .solved ? 1 : 0)
                }
            } else {
                return store.solvedMap[vm.id] ?? 0
            }
        }()
        let total  = store.problemCache[vm.id]?.count ?? 0
        let isLoadingRow = store.loadingContestIds.contains(vm.id)
        let _ = expanded.contains(vm.id)  // 保留用于触发重新计算
        let progress = total > 0 ? Double(solved) / Double(total) : 0.0
        
        // 判断是否应该显示 solved 信息
        // 即将开始(BEFORE)和正在进行的比赛(CODING/PENDING_SYSTEM_TEST/SYSTEM_TEST)不显示
        let shouldShowSolved = vm.phase != "BEFORE" && 
                               vm.phase != "CODING" && 
                               vm.phase != "PENDING_SYSTEM_TEST" && 
                               vm.phase != "SYSTEM_TEST"

        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(vm.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 10) {
                    if shouldShowSolved {
                        if trimmed.isEmpty {
                            Text("登录后显示做题进度")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if total > 0 {
                            // 进度条
                            HStack(spacing: 6) {
                                Text("Solved \(solved) / \(total)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                // 小进度条
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 4)
                                        
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.green, .blue],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geo.size.width * progress, height: 4)
                                            .animation(.easeOut(duration: 0.5), value: progress)
                                    }
                                }
                                .frame(width: 50, height: 4)
                                
                                Text("\(Int(progress * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        } else {
                            Text("Solved \(solved)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // 根据比赛状态显示不同的时间信息
                if vm.phase == "BEFORE" {
                    // 即将开始：显示倒计时（48小时内显示时分秒，超过48小时显示天数）
                    if let startTime = vm.startTime {
                        HStack(spacing: 0) {
                            Text("距离比赛开始还有：")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(timeUntil(startTime, showSeconds: true))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                    
                    // 显示持续时长
                    if let duration = vm.durationSeconds {
                        Text("持续时长 " + formatDuration(duration))
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                } else if vm.phase == "CODING" || vm.phase == "PENDING_SYSTEM_TEST" || vm.phase == "SYSTEM_TEST" {
                    // 正在进行：显示剩余时间（显示时分秒）
                    if let startTime = vm.startTime, let duration = vm.durationSeconds {
                        let endTime = startTime.addingTimeInterval(TimeInterval(duration))
                        HStack(spacing: 4) {
                            Image(systemName: "hourglass")
                                .font(.system(size: 10))
                            Text(timeUntil(endTime, showSeconds: true))
                        }
                        .font(.caption)
                        .foregroundColor(.green)
                        .monospacedDigit()
                    }
                    
                    // 显示持续时长
                    if let duration = vm.durationSeconds {
                        Text("持续时长 " + formatDuration(duration))
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                } else {
                    // 已结束：显示绝对时间
                    if let startTime = vm.startTime {
                        Text(Self.friendlyDate(startTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 显示持续时长
                    if let duration = vm.durationSeconds {
                        Text("持续时长 " + formatDuration(duration))
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - 题库视图
    private var problemsetListView: some View {
        List {
            
            // 未登录提示 - 美化版
            if handle.trimmed.isEmpty {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 28))
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("未填写 Handle")
                                .font(.system(size: 15, weight: .medium))
                            Text("去\"我的\"页输入 Handle 后，可显示做题进度")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // 页面级 loading / error - 使用骨架屏
            if problemsetStore.loading && problemsetStore.problems.isEmpty {
                ForEach(0..<8, id: \.self) { _ in
                    Section {
                        SkeletonListRow()
                    }
                }
            } else if let err = problemsetStore.error {
                Section { 
                    Text(err)
                        .foregroundColor(.red)
                        .font(.callout)
                }
            }
            
            // 题目列表 - 带滑入动画和精美卡片
            ForEach(Array(problemsetStore.displayedProblems.enumerated()), id: \.element.id) { index, problem in
                Section {
                    Button {
                        performLightHaptic()
                        selectedProblem = problem
                    } label: {
                        VStack(spacing: 0) {
                            HStack(spacing: 10) {
                                // 状态图标区域 - 固定在最左侧
                                let problemStatus = problemsetStore.getProblemStatus(for: problem)
                                circledStatusIcon(for: problemStatus)
                                    .frame(width: 24)
                                
                                // 题目信息区域
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text("\(problem.contestId ?? 0)\(problem.index)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.secondary)
                                        
                                        Text(problem.name)
                                            .font(.system(size: 16, weight: .medium))
                                            .lineLimit(2)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    // 标签行
                                    if shouldShowTags(for: problem, store: problemsetStore) {
                                        ProblemTagsView(tags: problem.tags ?? [])
                                            .padding(.top, 4)
                                    }
                                }
                                
                                Spacer(minLength: 8)
                                
                                // 右侧评分和收藏区域
                                VStack(alignment: .trailing, spacing: 4) {
                                    // 收藏图标
                                    Image(systemName: favoritesManager.isFavorite(id: problem.id) ? "star.fill" : "star")
                                        .font(.system(size: 16))
                                        .foregroundColor(favoritesManager.isFavorite(id: problem.id) ? .yellow : .gray.opacity(0.3))
                                    
                                    // 评分（如果有定义）
                                    if let rating = problem.rating {
                                        HStack(spacing: 4) {
                                            Text("●")
                                                .font(.system(size: 10))
                                                .foregroundColor(colorForProblemRating(rating))
                                            
                                            Text("\(rating)")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(colorForProblemRating(rating))
                                        }
                                    }
                                    
                                    // 通过人数（总是显示，如果有数据）
                                    if let solvedCount = problemsetStore.problemStatistics[problem.id] {
                                        HStack(spacing: 3) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 9))
                                                .foregroundColor(.green.opacity(0.7))
                                            
                                            Text(formatSolvedCount(solvedCount))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(colorForProblemRating(problem.rating).opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            withAnimation {
                                favoritesManager.toggleFavorite(problem)
                            }
                            performLightHaptic()
                        } label: {
                            Label(
                                favoritesManager.isFavorite(id: problem.id) ? "取消收藏" : "收藏",
                                systemImage: favoritesManager.isFavorite(id: problem.id) ? "star.slash" : "star.fill"
                            )
                        }
                        .tint(favoritesManager.isFavorite(id: problem.id) ? .gray : .yellow)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index % 10) * 0.03), value: problemsetStore.displayedProblems.count)
            }
            
            // 底部加载更多
            if problemsetStore.canLoadMore {
                Section {
                    HStack { Spacer(); ProgressView(); Text("Loading"); Spacer() }
                        .onAppear { problemsetStore.loadMoreIfNeeded() }
                }
            }
            
            // 底部占位空间，避免被 TabBar 遮挡
            Section {
                Color.clear
                    .frame(height: 60)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
        .animation(.default, value: problemsetStore.displayedProblems)
    }

    private static func friendlyDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
    
    // 格式化比赛持续时长（纯时长，不带前缀）
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else if hours > 0 {
            return "\(hours)小时"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    // 计算倒计时或剩余时间（使用 currentTime 以支持实时更新）
    // 参数 showSeconds: 是否显示秒级倒计时（距离开始48小时内）
    private func timeUntil(_ date: Date, showSeconds: Bool = false) -> String {
        let interval = date.timeIntervalSince(currentTime)
        
        if interval <= 0 {
            return "已开始"
        }
        
        let totalSeconds = Int(interval)
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        // 使用日历计算天数差异
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: currentTime)
        let startOfTargetDay = calendar.startOfDay(for: date)
        let dayComponents = calendar.dateComponents([.day], from: startOfToday, to: startOfTargetDay)
        let dayDifference = dayComponents.day ?? 0
        
        // 超过48小时（2天）：只显示天数（直接使用日期差）
        if totalSeconds > 48 * 3600 {
            return "\(dayDifference)天"
        }
        
        // 48小时内且需要显示秒：显示时分秒
        if showSeconds {
            if totalSeconds >= 3600 {
                let displayHours = totalSeconds / 3600
                return String(format: "%02d:%02d:%02d", displayHours, minutes, seconds)
            } else if minutes > 0 {
                return String(format: "%02d:%02d", minutes, seconds)
            } else {
                return "\(seconds)秒"
            }
        } else {
            // 不显示秒：显示时分
            if totalSeconds >= 3600 {
                let displayHours = totalSeconds / 3600
                return "\(displayHours)小时\(minutes)分钟"
            } else if minutes > 0 {
                return "\(minutes)分钟"
            } else {
                return "\(totalSeconds)秒"
            }
        }
    }
    
    // MARK: - 辅助函数：分区比赛列表
    
    // 将比赛按状态分成三组：即将开始、正在进行、已结束
    private func partitionContests(_ contests: [ContestVM]) -> (upcoming: [ContestVM], ongoing: [ContestVM], finished: [ContestVM]) {
        var upcoming: [ContestVM] = []
        var ongoing: [ContestVM] = []
        var finished: [ContestVM] = []
        
        for contest in contests {
            if contest.phase == "BEFORE" {
                // 即将开始
                upcoming.append(contest)
            } else if contest.phase == "CODING" || 
                      contest.phase == "PENDING_SYSTEM_TEST" || 
                      contest.phase == "SYSTEM_TEST" {
                // 正在进行
                ongoing.append(contest)
            } else {
                // 已结束
                finished.append(contest)
            }
        }
        
        // 合并即将开始和正在进行的比赛，按开始时间从近到远排序（最近的在上面）
        let upcomingAndOngoing = (upcoming + ongoing).sorted { contest1, contest2 in
            guard let time1 = contest1.startTime, let time2 = contest2.startTime else {
                return false
            }
            return time1 < time2  // 时间越早越靠前
        }
        
        return (upcomingAndOngoing, [], finished)
    }
    
    // 不可展开的比赛行视图（用于即将开始的比赛）
    @ViewBuilder
    private func contestRowNonExpandable(for vm: ContestVM, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            rowHeader(vm)
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .opacity
        ))
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: store.vms.count)
    }
    
    // 统一的比赛行视图（可展开）
    @ViewBuilder
    private func contestRow(for vm: ContestVM, index: Int) -> some View {
        DisclosureGroup(isExpanded: Binding(
            get: { expandedContests[vm.id] ?? false },
            set: { isExpanding in
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedContests[vm.id] = isExpanding
                }
                if isExpanding {
                    Task { 
                        await store.ensureProblemsLoaded(contestId: vm.id)
                    }
                }
            }
        )) {
            // 展开内容：题目 / 行内错误 / 占位
            if vm.phase == "BEFORE" {
                // 即将开始的比赛：显示暂无题目提示
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text("比赛还没开始，暂无题目")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 12)
            } else if let err = store.problemErrorMap[vm.id] {
                Text(err).foregroundColor(.red)
            } else if let problems = store.problemCache[vm.id], !problems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(problems.enumerated()), id: \.element.index) { pIndex, p in
                        let problemState = problemStateForDisplay(vmId: vm.id, p: p)
                        
                        Button {
                            performLightHaptic()
                            selectedProblem = p
                        } label: {
                            HStack(spacing: 12) {
                                // 状态图标
                                circledStatusIcon(for: problemState)
                                    .scaleEffect(1.1)
                                
                                // 题目信息
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Text(p.index)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(colorForProblemRating(p.rating))
                                        
                                        Text(p.name)
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                    }
                                    
                                    HStack(spacing: 8) {
                                        if let rating = p.rating {
                                            HStack(spacing: 4) {
                                                Text("●")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(colorForProblemRating(rating))
                                                Text("\(rating)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        if let solvedCount = store.problemStatistics[p.id] {
                                            HStack(spacing: 3) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.green.opacity(0.7))
                                                
                                                Text(formatSolvedCount(solvedCount))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(colorForProblemRating(p.rating).opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(Double(pIndex) * 0.05), value: expanded.contains(vm.id))
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 6)
            } else if store.loadingContestIds.contains(vm.id) {
                HStack { ProgressView(); Text("Loading...") }
            } else {
                Text("展开加载题目").foregroundColor(.secondary)
            }
        } label: {
            rowHeader(vm)
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .opacity
        ))
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: store.vms.count)
    }
    
    // MARK: - 倒计时定时器管理
    
    private func startCountdownTimer() {
        // 停止旧的定时器（如果有）
        stopCountdownTimer()
        
        // 每秒更新一次当前时间
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
}

// MARK: - 题面 Web 页面
private struct ProblemWebPage: View {
    let problem: CFProblem
    @StateObject private var web = WebViewModel()
    @Environment(\.dismiss) private var dismiss
    @AppStorage("cfHandle") private var handle: String = ""
    @AppStorage("aiTransModelName") private var aiTransModelName: String = ""
    @AppStorage("aiTransModel") private var aiTransModel: String = ""
    @AppStorage("aiTransProxyApi") private var aiTransProxyApi: String = ""
    @AppStorage("aiTransApiKey") private var aiTransApiKey: String = ""
    @State private var cookieHandle: String? = nil
    @State private var isTranslating: Bool = false
    @State private var isSubmissionsPresented: Bool = false
    @State private var isReadingSettingsPresented: Bool = false
    @State private var isTranslationPresented: Bool = false
    @State private var sectionTranslations: [SectionTranslation] = []
    @AppStorage("problemReaderFontSize") private var readerFontSize: Int = 17
    @AppStorage("problemReaderLineHeight") private var readerLineHeight: Double = 1.75

    private var urlString: String {
        let cid = problem.contestId ?? 0
        let idx = problem.index
        return "https://codeforces.com/contest/\(cid)/problem/\(idx)"
    }

    var body: some View {
        VStack(spacing: 0) {
            WebView(model: web)
                .onAppear {
                    // 只在首次进入时加载，避免从编辑器返回时页面被刷新
                    if !web.hasLoadedOnce {
                        web.load(urlString: urlString)
                    }
                    // 页面加载完成后，基于 Cookie 刷新当前登录 handle（实时反映登录/登出）
                    web.onDidFinishLoad = { _ in
                        Task { @MainActor in
                            self.cookieHandle = await CFCookieBridge.shared.readCurrentCFHandleFromWK()
                        }
                    }
                    // 加载保存的翻译结果
                    loadTranslationResult()
                }
                .task {
                    // 仅依据实际 Cookie 判断是否已登录
                    cookieHandle = await CFCookieBridge.shared.readCurrentCFHandleFromWK()
                }
            toolbar
        }
        .navigationTitle("\(problem.index) · \(problem.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                let t = (cookieHandle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty {
                    Text(t)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .sheet(isPresented: $isSubmissionsPresented) {
            NavigationStack {
                let effectiveHandle = {
                    if let ch = cookieHandle, !ch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return ch
                    }
                    return UserDefaults.standard.string(forKey: "cfHandle")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                }()
                ProblemSubmissionsView(problem: CFProblemIdentifier(contestId: problem.contestId ?? 0, index: problem.index, name: problem.name), handle: effectiveHandle)
                    .navigationTitle("Submissions")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("close") { isSubmissionsPresented = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isReadingSettingsPresented) {
            readingSettingsSheet
        }
        .sheet(isPresented: $isTranslationPresented) {
            translationSheet
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button(action: { web.goBack() }) {
                Image(systemName: "chevron.backward")
            }.disabled(!web.canGoBack)

            Button(action: { web.goForward() }) {
                Image(systemName: "chevron.forward")
            }.disabled(!web.canGoForward)

            Spacer()

            if web.isLoading {
                ProgressView(value: web.progress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 160)
            } else {
                Button(action: { web.reload() }) { Image(systemName: "arrow.clockwise") }
            }

            // 阅读设置
            Button(action: { isReadingSettingsPresented = true }) {
                Image(systemName: "textformat.size")
            }
            .accessibilityLabel("阅读设置")

            // 生成到编辑器：自动新建文件并导入样例
            Button(action: generateToEditor) {
                Image(systemName: "square.and.arrow.down.on.square")
            }


            // 查看提交记录按钮 - 需要登录状态
            let cookieHandleExists = !(cookieHandle ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let userDefaultsHandle = UserDefaults.standard.string(forKey: "cfHandle")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let userDefaultsHandleExists = !userDefaultsHandle.isEmpty
            let hasValidHandle = cookieHandleExists || userDefaultsHandleExists
            
            Button(action: { isSubmissionsPresented = true }) {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundColor(hasValidHandle ? .blue : .gray)
            }
            .disabled(!hasValidHandle)
            
            // 翻译按钮：一键将题面翻译为中文 / 查看已有翻译
            Button(action: {
                startStreamingTranslation()
            }) {
                if isTranslating {
                    HStack(spacing: 4) { 
                        ProgressView().controlSize(.small)
                        Text("翻译中…") 
                    }
                } else if sectionTranslations.isEmpty {
                    Label("翻译", systemImage: "character.book.closed")
                } else {
                    Label("查看翻译", systemImage: "character.book.closed.fill")
                        .foregroundColor(.blue)
                }
            }
            .disabled(isTranslating || (!sectionTranslations.isEmpty ? false : !isAITranslatorConfigured))
            
            // 如果有翻译内容，添加长按菜单
            if !sectionTranslations.isEmpty {
                Menu {
                    Button(action: { isTranslationPresented = true }) {
                        Label("查看翻译", systemImage: "eye")
                    }
                    Button {
                        startStreamingTranslation()
                    } label: {
                        Label("重新翻译", systemImage: "arrow.clockwise")
                    }
                    .disabled(isTranslating || !isAITranslatorConfigured)
                    Button(role: .destructive) {
                        clearTranslations()
                    } label: {
                        Label("清除翻译", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                } primaryAction: {
                    isTranslationPresented = true
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .border(Color(UIColor.separator), width: 0.5)
    }

    private var isAITranslatorConfigured: Bool {
        !aiTransModel.trimmed.isEmpty && !aiTransProxyApi.trimmed.isEmpty
    }
    
    @ViewBuilder
    private var translationSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if isTranslating {
                        // 翻译进度显示
                        VStack(spacing: 20) {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .controlSize(.large)
                                Text("正在翻译题面...")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("请稍候，AI正在为您生成中文翻译")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(24)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                        .padding(.top, 40)
                    } else if sectionTranslations.isEmpty {
                        ContentUnavailableView(
                            "暂无翻译内容",
                            systemImage: "doc.text",
                            description: Text("点击翻译按钮获取题面的中文翻译")
                        )
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        // 按部分显示翻译内容
                        ForEach(sectionTranslations) { sectionTranslation in
                            VStack(alignment: .leading, spacing: 8) {
                                // 部分标题
                                HStack {
                                    Image(systemName: sectionTranslation.section.icon)
                                        .foregroundColor(.blue)
                                    Text(sectionTranslation.section.displayName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                
                                // 翻译内容
                                ForEach(sectionTranslation.segments) { segment in
                                    LatexRenderedTextView(segment.translated, fontSize: 16)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 1)
                                        .id(segment.id) // 确保每个段落有稳定的ID
                                        .onAppear {
                                            // 添加小延迟，避免同时初始化太多WebView
                                            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.1...0.3)) {
                                                // 触发渲染
                                            }
                                        }
                                }
                            }
                            .background(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 6)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("题面翻译")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") {
                        isTranslationPresented = false
                    }
                }
                
                if !sectionTranslations.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button(action: copyAllTranslations) {
                                Label("copy translated text", systemImage: "doc.on.doc")
                            }
                            Button(action: clearTranslations) {
                                Label("reset", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    @ViewBuilder
    private var readingSettingsSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Adjust theses for better experience")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 20) {
                    // 字体大小设置
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Front Size")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(readerFontSize)px")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack(spacing: 12) {
                            Text("A")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Slider(value: Binding(
                                get: { Double(readerFontSize) },
                                set: { newValue in
                                    readerFontSize = Int(newValue)
                                    applyReadingSettings()
                                }
                            ), in: 14...22, step: 1)
                            
                            Text("A")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // 行间距设置
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Line Spacing")
                                .fontWeight(.medium)
                            Spacer()
                            Text(String(format: "%.2f", readerLineHeight))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack(spacing: 12) {
                            Text("Dense")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Slider(value: $readerLineHeight, in: 1.4...2.2, step: 0.05)
                                .onChange(of: readerLineHeight) { _, _ in
                                    applyReadingSettings()
                                }
                            
                            Text("Loose")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // 预设方案
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Settings")
                            .fontWeight(.medium)
                        
                        HStack(spacing: 12) {
                            presetButton(title: "Comfortable", fontSize: 17, lineHeight: 1.75)
                            presetButton(title: "Eye Care", fontSize: 18, lineHeight: 1.8)
                            presetButton(title: "Compact", fontSize: 15, lineHeight: 1.6)
                        }
                    }
                }
                .padding(20)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .navigationTitle("Reading Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("done") {
                        isReadingSettingsPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private func presetButton(title: String, fontSize: Int, lineHeight: Double) -> some View {
        Button(action: {
            readerFontSize = fontSize
            readerLineHeight = lineHeight
            applyReadingSettings()
        }) {
            Text(title)
                .font(.footnote)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.accentColor.opacity(0.1))
                )
                .foregroundStyle(.primary)
        }
    }
    
    private func applyReadingSettings() {
        // 将设置应用到WebView中的阅读模式
        let script = """
        (function() {
            if (document.getElementById('cf-reader-container')) {
                document.documentElement.style.setProperty('--cf-font-size', '\(readerFontSize)px');
                document.documentElement.style.setProperty('--cf-line-height', '\(readerLineHeight)');
            }
        })();
        """
        web.webView?.evaluateJavaScript(script) { _, _ in }
    }

    private func startStreamingTranslation() {
        // 立即打开翻译sheet
        isTranslationPresented = true
        
        // 如果已有翻译内容，直接显示，否则开始翻译
        if sectionTranslations.isEmpty {
            translateProblemToChinese()
        }
    }
    
    private func translateProblemToChinese() {
        guard !isTranslating else { return }
        isTranslating = true
        web.collectSectionBasedSegments { sectionData in
            Task {
                guard isAITranslatorConfigured else { 
                    await MainActor.run { self.isTranslating = false }
                    return 
                }
                
                var resultSections: [SectionTranslation] = []
                
                // 按照预定义顺序处理各部分，确保显示顺序正确
                let sectionOrder: [ProblemSection] = [.legend, .input, .output, .note, .interaction, .hack, .tutorial]
                
                for section in sectionOrder {
                    guard let segments = sectionData[section.rawValue], !segments.isEmpty else { continue }
                    let translated = await AITranslator.translateENtoZH(segments, model: aiTransModel.trimmed, proxyAPI: aiTransProxyApi.trimmed, apiKey: aiTransApiKey.trimmed.isEmpty ? nil : aiTransApiKey.trimmed)
                    
                    let translatedSegments = zip(segments, translated).map { original, translated in
                        TranslationSegment(original: original, translated: translated)
                    }
                    
                    resultSections.append(SectionTranslation(section: section, segments: translatedSegments))
                }
                
                await MainActor.run {
                    self.sectionTranslations = resultSections
                    self.saveTranslationResult()
                    self.isTranslating = false
                }
            }
        }
    }

    // MARK: - 翻译结果持久化
    private func translationCacheKey() -> String {
        let cid = problem.contestId ?? 0
        let idx = problem.index
        return "translation_\(cid)_\(idx)"
    }
    
    private func saveTranslationResult() {
        let key = translationCacheKey()
        do {
            let data = try JSONEncoder().encode(sectionTranslations)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            // 忽略保存错误
        }
    }
    
    private func loadTranslationResult() {
        let key = translationCacheKey()
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        do {
            sectionTranslations = try JSONDecoder().decode([SectionTranslation].self, from: data)
        } catch {
            // 忽略加载错误
        }
    }
    
    private func clearTranslations() {
        sectionTranslations = []
        let key = translationCacheKey()
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    private func copyAllTranslations() {
        let allTranslations = sectionTranslations.flatMap { sectionTranslation in
            [sectionTranslation.section.displayName + ":"] + sectionTranslation.segments.map { $0.translated }
        }.joined(separator: "\n\n")
        #if canImport(UIKit)
        UIPasteboard.general.string = allTranslations
        #elseif canImport(AppKit)
        NSPasteboard.general.setString(allTranslations, forType: .string)
        #endif
    }

    private func generateToEditor() {
        let contestId = problem.contestId ?? 0
        let index = problem.index
        let fileName = "\(contestId)\(index).cpp"
        // 1) 抓样例
        web.extractCodeforcesSamples { pairs in
            // 2) 写文件到 Documents
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let target = dir.appendingPathComponent(fileName)
            let template = """
#include <bits/stdc++.h>
#define cy {cout << "YES" << endl; return;}
#define cn {cout << "NO" << endl; return;}
#define inf 0x3f3f3f3f
#define llinf 0x3f3f3f3f3f3f3f3f
// #define int long long
#define db(a) cout << #a << " = " << (a) << '\\n'

using namespace std;

typedef pair<int, int> PII;
typedef tuple<int, int, int, int> St;
typedef long long ll;

int T = 1;
const int N = 2e5 + 10, MOD = 998244353;
int dx[] = {1, -1, 0, 0}, dy[] = {0, 0, 1, -1};

void solve() {
    
}

signed main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    cin >> T;
    while (T -- ) {
        solve();
    }
    return 0;
}
"""
            if !FileManager.default.fileExists(atPath: target.path) {
                try? template.data(using: .utf8)?.write(to: target)
            }

            // 3) 写入样例到编辑器的持久化（哈希路径规则与编辑器一致）
            let path = target.standardizedFileURL.path
            let hashed = Insecure.MD5.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            var appFolder = support.appendingPathComponent("CfEditor", isDirectory: true)
            if !FileManager.default.fileExists(atPath: appFolder.path) {
                try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
                var values = URLResourceValues(); values.isExcludedFromBackup = true; try? appFolder.setResourceValues(values)
            }
            var tcDir = appFolder.appendingPathComponent("TestCases", isDirectory: true)
            if !FileManager.default.fileExists(atPath: tcDir.path) {
                try? FileManager.default.createDirectory(at: tcDir, withIntermediateDirectories: true)
                var values = URLResourceValues(); values.isExcludedFromBackup = true; try? tcDir.setResourceValues(values)
            }
            let tcFile = tcDir.appendingPathComponent("\(hashed).json")
            let testCases: [[String: Any]] = pairs.isEmpty
                ? [["input": "", "expected": "", "received": "", "lastRunMs": NSNull(), "timedOut": false, "verdict": "none"]]
                : pairs.map { [
                    "input": $0.input,
                    "expected": $0.output,
                    "received": "",
                    "lastRunMs": NSNull(),
                    "timedOut": false,
                    "verdict": "none"
                ] }
            if let data = try? JSONSerialization.data(withJSONObject: testCases) {
                try? data.write(to: tcFile, options: .atomic)
            }

            // 4) 通过通知切换到编辑器并打开该文件
            NotificationCenter.default.post(name: .openEditorFileRequested, object: target)
            // 保留题面页，不主动关闭，便于返回继续查看题面
        }
    }
}

// MARK: - 交互：按钮按压缩放动画（触摸即刻生效）
private struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressScaleView(configuration: configuration)
    }

    private struct PressScaleView: View {
        let configuration: Configuration
        @GestureState private var isTouching: Bool = false

        var body: some View {
            // 零距离拖拽可在触摸按下的第一时间进入 pressed 状态
            let touchDown = DragGesture(minimumDistance: 0)
                .updating($isTouching) { _, state, _ in
                    if state == false { state = true }
                }

            let pressed = configuration.isPressed || isTouching

            return configuration.label
                .contentShape(Rectangle())
                .scaleEffect(pressed ? 0.96 : 1.0)
                .opacity(pressed ? 0.92 : 1.0)
                .shadow(color: Color.black.opacity(pressed ? 0.2 : 0), radius: 8, x: 0, y: 4)
                .animation(.interactiveSpring(response: 0.08, dampingFraction: 0.9), value: pressed)
                .simultaneousGesture(touchDown)
        }
    }
}

// MARK: - 增强的题目卡片
private struct EnhancedProblemCard: View {
    let problem: CFProblem
    let contestId: Int
    let status: ProblemAttemptState
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 状态图标
                circledStatusIcon(for: status)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                
                // 题目信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(problem.index)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(colorForProblemRating(problem.rating))
                        
                        Text(problem.name)
                            .font(.system(size: 15))
                            .foregroundColor(colorForProblemRating(problem.rating))
                            .lineLimit(2)
                    }
                    
                    if let rating = problem.rating {
                        Text("\(rating)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 右侧难度指示
                if let rating = problem.rating {
                    Circle()
                        .fill(colorForProblemRating(rating).opacity(0.2))
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(colorForProblemRating(rating), lineWidth: 2)
                        )
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(isPressed ? 0.15 : 0.08), radius: isPressed ? 12 : 8, y: isPressed ? 6 : 4)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
