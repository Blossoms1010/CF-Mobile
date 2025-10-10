import Foundation
import SwiftUI

// MARK: - Judge0 API Configuration
enum Judge0APIType: String, Codable, CaseIterable, Identifiable {
    case community = "community"
    case rapidapi = "rapidapi"
    case custom = "custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .community:
            return "社区 API (免费)"
        case .rapidapi:
            return "RapidAPI (推荐)"
        case .custom:
            return "自定义 API"
        }
    }
    
    var icon: String {
        switch self {
        case .community:
            return "globe"
        case .rapidapi:
            return "bolt.fill"
        case .custom:
            return "server.rack"
        }
    }
    
    var description: String {
        switch self {
        case .community:
            return "使用 Judge0 官方社区版 API，免费但有严格的速率限制"
        case .rapidapi:
            return "通过 RapidAPI 使用 Judge0，稳定可靠，需要 API Key"
        case .custom:
            return "使用您自己部署的 Judge0 实例"
        }
    }
    
    var defaultURL: String {
        switch self {
        case .community:
            return "https://ce.judge0.com"
        case .rapidapi:
            return "https://judge0-ce.p.rapidapi.com"
        case .custom:
            return ""
        }
    }
}

// MARK: - Judge0 Configuration Model
struct Judge0Configuration: Codable {
    var apiType: Judge0APIType
    var customURL: String
    var rapidAPIKey: String  // RapidAPI 专用的 Key
    var customAPIKey: String // 自定义 API 专用的 Key
    
    init(apiType: Judge0APIType = .community, customURL: String = "", rapidAPIKey: String = "", customAPIKey: String = "") {
        self.apiType = apiType
        self.customURL = customURL
        self.rapidAPIKey = rapidAPIKey
        self.customAPIKey = customAPIKey
    }
    
    var effectiveURL: String {
        switch apiType {
        case .community, .rapidapi:
            return apiType.defaultURL
        case .custom:
            return customURL.isEmpty ? apiType.defaultURL : customURL
        }
    }
    
    // 根据当前 API 类型返回对应的 Key
    var effectiveAPIKey: String {
        switch apiType {
        case .community:
            return ""
        case .rapidapi:
            return rapidAPIKey
        case .custom:
            return customAPIKey
        }
    }
}

// MARK: - Judge0 Configuration Manager
class Judge0ConfigManager: ObservableObject {
    static let shared = Judge0ConfigManager()
    
    @AppStorage("judge0Config") private var configData: Data = Data()
    
    @Published var configuration: Judge0Configuration {
        didSet {
            saveConfiguration()
        }
    }
    
    private init() {
        // 先初始化 configuration 为默认值
        self.configuration = Judge0Configuration()
        
        // 然后尝试从存储中读取并更新
        if let decoded = try? JSONDecoder().decode(Judge0Configuration.self, from: configData) {
            self.configuration = decoded
        }
    }
    
    private func saveConfiguration() {
        if let encoded = try? JSONEncoder().encode(configuration) {
            configData = encoded
        }
    }
    
    func getJudge0Config() -> Judge0Client.Config {
        let urlString = configuration.effectiveURL
        let url = URL(string: urlString) ?? URL(string: "https://ce.judge0.com")!
        
        var config = Judge0Client.Config(baseURL: url)
        
        // 使用 effectiveAPIKey 获取当前 API 类型对应的 Key
        if !configuration.effectiveAPIKey.isEmpty {
            config.apiKey = configuration.effectiveAPIKey
        }
        
        return config
    }
}

