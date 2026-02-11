import Foundation

/// API 配置管理
/// 从环境变量或 Config.xcconfig 中读取 API 密钥，避免硬编码敏感信息
enum APIConfig {
    
    /// ModelScope API Endpoint
    static let apiEndpoint = "https://api-inference.modelscope.cn/v1/chat/completions"
    
    /// API Key - 从 Info.plist 读取（通过 xcconfig 注入），如果没有则使用环境变量
    static var apiKey: String {
        // 优先从 Info.plist 读取（xcconfig 注入）
        if let key = Bundle.main.infoDictionary?["MODELSCOPE_API_KEY"] as? String,
           !key.isEmpty,
           !key.hasPrefix("$(") {
            return key
        }
        
        // 其次从环境变量读取（用于调试）
        if let key = ProcessInfo.processInfo.environment["MODELSCOPE_API_KEY"],
           !key.isEmpty {
            return key
        }
        
        // 未配置时返回空字符串，调用处会处理错误
        print("⚠️ [APIConfig] MODELSCOPE_API_KEY 未配置，请在 Config.xcconfig 中设置")
        return ""
    }
}
