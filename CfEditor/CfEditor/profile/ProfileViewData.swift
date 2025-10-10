//
//  ProfileViewData.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import Foundation
import SwiftUI
import WebKit

// MARK: - ProfileView Data Extensions

extension ProfileView {
    
    // MARK: - 数据加载
    
    func reload(forceRefresh: Bool = false) async {
        let shouldShowSkeleton = (user == nil && activityStats == nil && heatmapData == nil && practiceBuckets.isEmpty)
        if shouldShowSkeleton { loading = true }
        fetchError = nil
        
        // 第一阶段：加载核心用户信息
        var userInfo: CFUserInfo?
        var ratingHistory: [CFRatingUpdate] = []
        
        do {
            async let userInfoTask = CFAPI.shared.userInfo(handle: handle)
            async let ratingHistoryTask = CFAPI.shared.userRating(handle: handle)
            
            let (userInfoResult, ratingHistoryResult) = try await (userInfoTask, ratingHistoryTask)
            userInfo = userInfoResult
            ratingHistory = ratingHistoryResult
            
            let initialContests = await self.buildContestRecords(from: [], ratingHistory: ratingHistoryResult)
            
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
        
        // 第二阶段：加载提交数据
        var allSubmissions: [CFSubmission] = []
        var blogCount = 0
        var secondaryErrors: [String] = []
        
        async let submissionsTask = CFAPI.shared.userAllSubmissions(handle: handle, forceRefresh: forceRefresh)
        async let blogCountTask = CFAPI.shared.userBlogEntryCount(handle: handle)
        
        do {
            allSubmissions = try await submissionsTask
        } catch {
            secondaryErrors.append("提交记录加载失败")
            allSubmissions = self.allSubmissions
        }
        
        do {
            blogCount = try await blogCountTask
        } catch {
            blogCount = userInfo?.blogEntryCount ?? 0
        }
        
        let updatedContests = await self.buildContestRecords(from: allSubmissions, ratingHistory: ratingHistory)
        
        await MainActor.run {
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
                
                if !allSubmissions.isEmpty || self.allSubmissions.isEmpty {
                    self.activityStats = .calculate(from: allSubmissions)
                    self.allSubmissions = allSubmissions
                    
                    let newAvailableYears = Set(allSubmissions.map { submission in
                        let date = Date(timeIntervalSince1970: TimeInterval(submission.creationTimeSeconds))
                        return Calendar.current.component(.year, from: date)
                    })
                    
                    switch self.selectedHeatmapOption {
                    case .year(let year):
                        if !newAvailableYears.contains(year) {
                            let latestYear = newAvailableYears.max() ?? Calendar.current.component(.year, from: Date())
                            self.selectedHeatmapOption = .year(latestYear)
                        }
                    case .all:
                        break
                    }
                    
                    self.updateHeatmapData()
                    self.practiceBuckets = PracticeHistogram.build(from: allSubmissions)
                    self.tagSlices = TagPie.build(from: allSubmissions, topK: 14)
                    self.recentSubmissions = Array(allSubmissions.sorted(by: { $0.creationTimeSeconds > $1.creationTimeSeconds }).prefix(20))
                    self.recentContests = updatedContests
                }
                
                if self.handle != userInfo.handle {
                    self.handle = userInfo.handle
                }
                self.lastLoadedAt = Date()
            }
            
            if !secondaryErrors.isEmpty {
                self.fetchError = "⚠️ " + secondaryErrors.joined(separator: "；")
            }
            
            self.loading = false
        }
    }

    func reloadIfNeeded(force: Bool = false) async {
        if !force, let last = lastLoadedAt, Date().timeIntervalSince(last) < profileSoftTTL {
            return
        }
        await reload(forceRefresh: force)
    }
    
    // MARK: - 热力图数据更新
    
    func updateHeatmapData() {
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
    
    // MARK: - 比赛记录构建
    
    func buildContestRecords(from submissions: [CFSubmission], ratingHistory: [CFRatingUpdate]) async -> [ContestRecord] {
        let ratedContestMap = Dictionary(uniqueKeysWithValues: ratingHistory.map { ($0.contestId, $0) })
        
        let contestIdsFromSubmissions = Set(submissions.compactMap { submission -> Int? in
            guard let contestId = submission.contestId,
                  let participantType = submission.author?.participantType,
                  participantType == "CONTESTANT" || participantType == "OUT_OF_COMPETITION" else {
                return nil
            }
            return contestId
        })
        
        let allContestIds = Set(ratedContestMap.keys).union(contestIdsFromSubmissions)
        
        var contestMap: [Int: CFContest] = [:]
        do {
            let allContests = try await CFAPI.shared.allFinishedContests()
            contestMap = Dictionary(uniqueKeysWithValues: allContests.map { ($0.id, $0) })
        } catch {
            print("Failed to fetch contest list: \(error)")
        }
        
        var records: [ContestRecord] = []
        
        for contestId in allContestIds {
            let ratedInfo = ratedContestMap[contestId]
            
            let contestSubmissions = submissions.filter { submission in
                guard submission.contestId == contestId,
                      let participantType = submission.author?.participantType,
                      participantType == "CONTESTANT" || participantType == "OUT_OF_COMPETITION" else {
                    return false
                }
                return true
            }
            let firstSubmissionTime = contestSubmissions.map { $0.creationTimeSeconds }.min()
            
            let date: Date
            if let contest = contestMap[contestId], let startTime = contest.startTimeSeconds {
                date = Date(timeIntervalSince1970: TimeInterval(startTime))
            } else if let ratedInfo = ratedInfo {
                date = Date(timeIntervalSince1970: TimeInterval(ratedInfo.ratingUpdateTimeSeconds))
            } else if let submissionTime = firstSubmissionTime {
                date = Date(timeIntervalSince1970: TimeInterval(submissionTime))
            } else {
                continue
            }
            
            let contestName: String
            if let ratedInfo = ratedInfo {
                contestName = ratedInfo.contestName
            } else if let contest = contestMap[contestId] {
                contestName = contest.name
            } else {
                contestName = "Contest #\(contestId)"
            }
            
            let solvedProblems = Set(contestSubmissions.filter { $0.verdict == "OK" }.map { $0.problem.index })
            let solvedCount = solvedProblems.count
            
            let record = ContestRecord(
                id: contestId,
                contestName: contestName,
                date: date,
                rank: ratedInfo?.rank,
                oldRating: ratedInfo?.oldRating,
                newRating: ratedInfo?.newRating,
                ratingChange: ratedInfo.map { $0.newRating - $0.oldRating },
                contestNumber: 0,
                solvedCount: solvedCount
            )
            
            records.append(record)
        }
        
        records.sort { $0.date < $1.date }
        
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
        
        return records.reversed()
    }
}

// MARK: - 会话清理与软重启

extension ProfileView {
    
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

