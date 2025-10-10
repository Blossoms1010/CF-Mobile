//
//  ProblemParserModels.swift
//  CfEditor
//
//  Created by AI on 2025-10-09.
//

import Foundation

// MARK: - Parser Error

enum ParserError: Error, LocalizedError {
    case invalidURL
    case networkError
    case encodingError
    case cloudflareBlocked
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network request failed"
        case .encodingError:
            return "Unable to decode HTML"
        case .cloudflareBlocked:
            return "Blocked by Cloudflare. Please try again later."
        case .parseError(let message):
            return "Parse error: \(message)"
        }
    }
}

