//
//  ProblemParser.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import Foundation

// MARK: - Problem Parser

/// 解析 Codeforces 题目 HTML 的工具类
class ProblemParser {
    
    // MARK: - Public Methods
    
    /// 从 URL 下载并解析题目
    static func fetchAndParse(contestId: Int, problemIndex: String, tags: [String]? = nil) async throws -> ProblemStatement {
        let urlString = "https://codeforces.com/contest/\(contestId)/problem/\(problemIndex)"
        
        guard let url = URL(string: urlString) else {
            throw ParserError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ParserError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ParserError.networkError
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw ParserError.encodingError
        }
        
        // 检查是否被 Cloudflare 拦截
        let isCloudflareBlocked = (
            html.contains("Checking your browser") ||
            html.contains("Just a moment") ||
            html.contains("Enable JavaScript and cookies to continue") ||
            (html.contains("cf-browser-verification") && html.contains("ray ID"))
        )
        
        if isCloudflareBlocked {
            throw ParserError.cloudflareBlocked
        }
        
        let result = try parse(html: html, contestId: contestId, problemIndex: problemIndex, sourceURL: urlString, tags: tags)
        
        return result
    }
    
    /// 解析 HTML 字符串
    static func parse(html: String, contestId: Int, problemIndex: String, sourceURL: String, tags: [String]? = nil) throws -> ProblemStatement {
        
        // 标准化 LaTeX 标记
        var cleanedHTML = html
        cleanedHTML = cleanedHTML.replacingOccurrences(of: "$$$$$$", with: "$$")
        cleanedHTML = cleanedHTML.replacingOccurrences(of: "$$$", with: "$")
        
        // 提取基本信息
        let name = extractTitle(from: cleanedHTML)
        let timeLimit = extractTimeLimit(from: cleanedHTML)
        let memoryLimit = extractMemoryLimit(from: cleanedHTML)
        let (inputFile, outputFile) = extractIOFiles(from: cleanedHTML)
        
        // 检测是否为交互题
        let isInteractive = tags?.contains("interactive") ?? false
        
        // 提取内容部分
        let statement = extractStatement(from: cleanedHTML)
        let inputSpec = extractInputSpecification(from: cleanedHTML)
        let outputSpec = extractOutputSpecification(from: cleanedHTML)
        let samples = extractSamples(from: cleanedHTML, isInteractive: isInteractive)
        let note = extractNote(from: cleanedHTML)
        
        // 检测多测题目
        let hasMultipleTestCases = detectMultipleTestCases(from: inputSpec)
        let adjustedSamples = hasMultipleTestCases ? adjustSamplesForMultipleTestCases(samples) : samples
        
        return ProblemStatement(
            contestId: contestId,
            problemIndex: problemIndex,
            name: name,
            timeLimit: timeLimit,
            memoryLimit: memoryLimit,
            inputFile: inputFile,
            outputFile: outputFile,
            statement: statement,
            inputSpecification: inputSpec,
            outputSpecification: outputSpec,
            samples: adjustedSamples,
            note: note,
            sourceURL: sourceURL,
            rawHTML: html,
            hasMultipleTestCases: hasMultipleTestCases,
            tags: tags
        )
    }
}
