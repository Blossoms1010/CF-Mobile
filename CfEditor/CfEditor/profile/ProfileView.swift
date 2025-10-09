//
//  ProfileView.swift
//  CfEditor
//
//  Refactored: AI on 2025-10-09.
//

import SwiftUI
import Charts
import WebKit
import Kingfisher

// MARK: - 主视图 (ProfileView)

struct ProfileView: View {
    @AppStorage("cfHandle") var handle: String = ""

    // 登录表单
    @State var input: String = ""
    @State var loginError: String?
    @FocusState var focused: Bool
    @State var isSaving = false

    // 登录后数据
    @State var loading = true
    @State var fetchError: String?
    @State var user: CFUserInfo?
    @State var ratings: [CFRatingUpdate] = []
    @State var activityStats: ActivityStats?
    @State var heatmapData: HeatmapData?
    @State var practiceBuckets: [PracticeBucket] = []
    @State var tagSlices: [TagSlice] = []
    @State var lastLoadedAt: Date?
    let profileSoftTTL: TimeInterval = 600
    @State var recentSubmissions: [CFSubmission] = []
    @State var showAllSubmissionsSheet: Bool = false
    let maxRecentSubmissionsToShow: Int = 7
    
    // 比赛记录
    @State var recentContests: [ContestRecord] = []
    @State var showAllContestsSheet: Bool = false
    let maxRecentContestsToShow: Int = 5
    
    // 热力图选择
    @State var selectedHeatmapOption: YearSelection = .all
    @State var allSubmissions: [CFSubmission] = []
    
    // 标签选择
    @State var selectedTag: String? = nil
    @State var isTagLegendExpanded: Bool = false

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
            
            // 用户信息
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
            
            // 活动统计
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
                sectionHeader(title: "Info", icon: "chart.bar.doc.horizontal", colors: [.blue, .purple])
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)

            // Rating 曲线
            Section {
                ratingChartBox
                    .opacity(loading ? 0 : 1)
                    .offset(y: loading ? 20 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: loading)
            } header: {
                sectionHeader(title: "Rating graph", icon: "chart.xyaxis.line", colors: [.orange, .red])
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            
            // 比赛记录
            Section {
                contestHistoryBox
                    .opacity(loading ? 0 : 1)
                    .offset(y: loading ? 20 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: loading)
            } header: {
                sectionHeader(title: "Contest History", icon: "trophy.fill", colors: [.yellow, .orange])
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            
            // 热力图
            Section {
                heatmapBox
                    .opacity(loading ? 0 : 1)
                    .offset(y: loading ? 20 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: loading)
            } header: {
                sectionHeader(title: "Heatmap", icon: "calendar.day.timeline.left", colors: [.green, .cyan])
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            
            // 练习柱状图
            Section {
                practiceHistogramBox
                    .opacity(loading ? 0 : 1)
                    .offset(y: loading ? 20 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: loading)
            } header: {
                sectionHeader(title: "Rating Solved", icon: "chart.bar.xaxis", colors: [.purple, .pink])
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            
            // 标签分布
            Section {
                tagPieBox
                    .opacity(loading ? 0 : 1)
                    .offset(y: loading ? 20 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: loading)
            } header: {
                sectionHeader(title: "Tag Solved", icon: "chart.pie.fill", colors: [.indigo, .blue])
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)

            // 最近提交
            Section {
                recentSubmissionsBox
                    .opacity(loading ? 0 : 1)
                    .offset(y: loading ? 20 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: loading)
            } header: {
                sectionHeader(title: "Recent Submissions", icon: "clock.arrow.circlepath", colors: [.teal, .green])
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
            
            // 底部占位空间
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
        .task {
            if let h = await CFCookieBridge.shared.readCurrentCFHandleFromWK(), 
               h.lowercased() != handle.lowercased() {
                handle = h
            }
        }
        .refreshable { await reload(forceRefresh: true) }
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
    
    // MARK: - Section Header
    
    @ViewBuilder
    private func sectionHeader(title: String, icon: String, colors: [Color]) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .symbolRenderingMode(.hierarchical)
    }
    
    // MARK: - 登录和验证
    
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
                handle = userInfo.handle
                input = userInfo.handle
                #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
            }
            await performSoftReload()
        } catch {
            await MainActor.run { self.loginError = "用户 '\(t)' 未找到" }
        }
    }
}

