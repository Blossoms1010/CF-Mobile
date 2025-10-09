import SwiftUI

// MARK: - 热力图着色模式
enum HeatmapColorMode {
    case ratingBased  // 基于 rating 着色（彩色）
    case normal       // 普通模式（绿色渐变，基于提交数）
}

// MARK: - 活动统计的数据模型与计算逻辑
struct ActivityStats {
    let totalSolved: Int
    let solvedLast30Days: Int
    let currentStreak: Int
    
    static func calculate(from submissions: [CFSubmission]) -> ActivityStats {
        let accepted = submissions.filter { $0.verdict == "OK" }
        
        // 调试：检查是否有 contestId 为 nil 的题目
        let problemIds = accepted.map { $0.problem.id }
        let nilContestProblems = accepted.filter { $0.problem.contestId == nil }
        if !nilContestProblems.isEmpty {
            print("⚠️ 发现 \(nilContestProblems.count) 个 contestId 为 nil 的题目")
            for p in nilContestProblems.prefix(5) {
                print("  - Problem: \(p.problem.name), index: \(p.problem.index), id: \(p.problem.id)")
            }
        }
        
        let totalSolved = Set(problemIds).count
        
        // 调试：打印详细统计
        #if DEBUG
        print("📊 统计信息:")
        print("  - AC提交总数: \(accepted.count)")
        print("  - 去重后题数: \(totalSolved)")
        print("  - contestId为nil的题目: \(nilContestProblems.count)")
        
        // 检查是否有重复的 problem.id
        let idCounts = Dictionary(grouping: problemIds, by: { $0 }).mapValues { $0.count }
        let duplicates = idCounts.filter { $0.value > 1 }
        if !duplicates.isEmpty {
            print("  - 重复提交的题目: \(duplicates.count)")
            for (id, count) in duplicates.prefix(5) {
                print("    • \(id): \(count) 次")
            }
        }
        #endif
        
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
        
        // 只有"今天或昨天"有提交才算正在进行的 streak
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

// MARK: - 热力图显示类型
enum HeatmapViewType {
    case year(Int)    // 指定年份的完整年度视图
    case rolling365   // 从今天向前365天的滚动视图
}

// MARK: - 热力图数据（按周×天对齐，带月份标签）
struct HeatmapData {
    let weeks: [[Date]]           // 周 × 7 天
    let dailyColors: [Date: Color]
    let monthLabels: [Int: String]
    let viewType: HeatmapViewType // 视图类型
    let dailySubmissions: [Date: Int]  // 每天的提交数
    let dailyAccepted: [Date: Int]     // 每天的 AC 数
    let dailyMaxRating: [Date: Int?]   // 每天最高 rating（用于着色）
    
    var displayTitle: String {
        switch viewType {
        case .year(let year):
            return "\(year)"
        case .rolling365:
            return "All"
        }
    }

    static func calculate(from submissions: [CFSubmission]) -> HeatmapData {
        let currentYear = Calendar.current.component(.year, from: Date())
        return calculate(from: submissions, viewType: .year(currentYear))
    }
    
    static func calculate(from submissions: [CFSubmission], forYear year: Int) -> HeatmapData {
        return calculate(from: submissions, viewType: .year(year))
    }
    
    static func calculate(from submissions: [CFSubmission], viewType: HeatmapViewType) -> HeatmapData {
        switch viewType {
        case .year(let year):
            return calculateYearView(from: submissions, forYear: year)
        case .rolling365:
            return calculate365DaysView(from: submissions)
        }
    }
    
    // MARK: - 年度视图计算
    private static func calculateYearView(from submissions: [CFSubmission], forYear year: Int) -> HeatmapData {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // 周一为一周起始

        // 计算指定年份的日期范围
        let yearStart = cal.date(from: DateComponents(year: year, month: 1, day: 1))!
        let currentYear = cal.component(.year, from: Date())
        let today = cal.startOfDay(for: Date())
        
        // 找到年份开始那一周的周一
        let weekdayOfYearStart = cal.component(.weekday, from: yearStart)  // Sun=1...Sat=7
        let offsetToMonday = (weekdayOfYearStart + 5) % 7
        let firstMonday = cal.date(byAdding: .day, value: -offsetToMonday, to: yearStart)!
        
        // 找到结束日期那一周的周日
        let endDate: Date
        // 无论是哪一年，都显示到年底最后一天，这样用户可以看到完整的年度热力图
        endDate = cal.date(from: DateComponents(year: year, month: 12, day: 31))!
        
        let weekdayOfEnd = cal.component(.weekday, from: endDate)
        let offsetToSunday = weekdayOfEnd == 1 ? 0 : (7 - weekdayOfEnd + 1) % 7
        let lastSunday = cal.date(byAdding: .day, value: offsetToSunday, to: endDate)!
        
        // 计算周数，确保包含当前周
        let totalDays = DateInterval(start: firstMonday, end: lastSunday).duration
        let totalWeeks = max(52, Int(ceil(totalDays / (7 * 24 * 60 * 60))) + 1)

        // 统计每日的提交数、AC数和最高rating
        var dailySubmissions: [Date: Int] = [:]  // 每天的总提交数
        var dailyAccepted: [Date: Int] = [:]     // 每天的 AC 数
        var dailyMaxRating: [Date: Int?] = [:]   // 每天的最高 rating
        
        for s in submissions {
            let submissionDate = Date(timeIntervalSince1970: TimeInterval(s.creationTimeSeconds))
            let submissionYear = cal.component(.year, from: submissionDate)
            
            // 只处理指定年份的提交
            if submissionYear == year {
                let day = cal.startOfDay(for: submissionDate)
                
                // 统计总提交数
                dailySubmissions[day, default: 0] += 1
                
                // 统计 AC 数
                if s.verdict == "OK" {
                    dailyAccepted[day, default: 0] += 1
                    
                    let currentRating = s.problem.rating
                    
                    // 记录最高 rating
                    if dailyMaxRating[day] == nil {
                        dailyMaxRating[day] = currentRating
                    } else if let existingRating = dailyMaxRating[day], let existing = existingRating {
                        if let current = currentRating {
                            dailyMaxRating[day] = max(existing, current)
                        }
                    } else if dailyMaxRating[day] != nil && currentRating != nil {
                        dailyMaxRating[day] = currentRating
                    }
                }
            }
        }

        // 默认使用 rating 着色
        let dailyColors: [Date: Color] = dailyMaxRating.reduce(into: [:]) { dict, kv in
            if let rating = kv.value {
                dict[kv.key] = colorForRating(rating)
            } else {
                // gym 题目显示灰色
                dict[kv.key] = .gray
            }
        }

        var weeks: [[Date]] = []
        for w in 0..<totalWeeks {
            var days: [Date] = []
            let monday = cal.date(byAdding: .day, value: w*7, to: firstMonday)!
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

        return HeatmapData(
            weeks: weeks, 
            dailyColors: dailyColors, 
            monthLabels: monthLabels, 
            viewType: .year(year),
            dailySubmissions: dailySubmissions,
            dailyAccepted: dailyAccepted,
            dailyMaxRating: dailyMaxRating
        )
    }
    
    // MARK: - 365天滚动视图计算
    private static func calculate365DaysView(from submissions: [CFSubmission]) -> HeatmapData {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // 周一为一周起始
        
        let today = cal.startOfDay(for: Date())
        let startDate = cal.date(byAdding: .day, value: -364, to: today)! // 365天前
        
        // 找到开始日期那一周的周一
        let weekdayOfStart = cal.component(.weekday, from: startDate)
        let offsetToMonday = (weekdayOfStart + 5) % 7
        let firstMonday = cal.date(byAdding: .day, value: -offsetToMonday, to: startDate)!
        
        // 找到今天那一周的周日，确保包含今天这一周
        let weekdayOfToday = cal.component(.weekday, from: today)
        let offsetToSunday = weekdayOfToday == 1 ? 0 : (7 - weekdayOfToday + 1) % 7
        let lastSunday = cal.date(byAdding: .day, value: offsetToSunday, to: today)!
        
        // 计算周数，确保包含最后一周
        let totalDays = DateInterval(start: firstMonday, end: lastSunday).duration
        let totalWeeks = Int(ceil(totalDays / (7 * 24 * 60 * 60))) + 1
        
        // 统计每日的提交数、AC数和最高rating
        var dailySubmissions: [Date: Int] = [:]  // 每天的总提交数
        var dailyAccepted: [Date: Int] = [:]     // 每天的 AC 数
        var dailyMaxRating: [Date: Int?] = [:]   // 每天的最高 rating
        
        for s in submissions {
            let submissionDate = Date(timeIntervalSince1970: TimeInterval(s.creationTimeSeconds))
            let day = cal.startOfDay(for: submissionDate)
            
            // 只处理365天范围内的提交
            if day >= startDate && day <= today {
                // 统计总提交数
                dailySubmissions[day, default: 0] += 1
                
                // 统计 AC 数
                if s.verdict == "OK" {
                    dailyAccepted[day, default: 0] += 1
                    
                    let currentRating = s.problem.rating
                    
                    // 记录最高 rating
                    if dailyMaxRating[day] == nil {
                        dailyMaxRating[day] = currentRating
                    } else if let existingRating = dailyMaxRating[day], let existing = existingRating {
                        if let current = currentRating {
                            dailyMaxRating[day] = max(existing, current)
                        }
                    } else if dailyMaxRating[day] != nil && currentRating != nil {
                        dailyMaxRating[day] = currentRating
                    }
                }
            }
        }
        
        // 默认使用 rating 着色
        let dailyColors: [Date: Color] = dailyMaxRating.reduce(into: [:]) { dict, kv in
            if let rating = kv.value {
                dict[kv.key] = colorForRating(rating)
            } else {
                // gym 题目显示灰色
                dict[kv.key] = .gray
            }
        }
        
        var weeks: [[Date]] = []
        for w in 0..<totalWeeks {
            var days: [Date] = []
            let monday = cal.date(byAdding: .day, value: w*7, to: firstMonday)!
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
        
        return HeatmapData(
            weeks: weeks, 
            dailyColors: dailyColors, 
            monthLabels: monthLabels, 
            viewType: .rolling365,
            dailySubmissions: dailySubmissions,
            dailyAccepted: dailyAccepted,
            dailyMaxRating: dailyMaxRating
        )
    }
}

// MARK: - 年份/All选项类型
enum YearSelection: Hashable {
    case year(Int)
    case all
    
    var displayText: String {
        switch self {
        case .year(let year):
            return "\(year)"
        case .all:
            return "All"
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
                // 如果这道题有 rating，从 unratedProblems 中移除（可能之前作为 gym 题加入过）
                unratedProblems.remove(pid)
            } else {
                // 只有在该题目没有被记录为有 rating 的题目时，才加入 unratedProblems
                if solvedRatingByProblem[pid] == nil {
                    unratedProblems.insert(pid)
                }
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

