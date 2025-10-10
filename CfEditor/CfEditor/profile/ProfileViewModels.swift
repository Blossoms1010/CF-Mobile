//
//  ProfileViewModels.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import Foundation

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

// MARK: - Rating 扩展

extension CFRatingUpdate {
    var date: Date { 
        Date(timeIntervalSince1970: TimeInterval(ratingUpdateTimeSeconds)) 
    }
}

