import Foundation

/// Central API configuration — update your key here
enum APIConfig {
    static let modelScopeAPIKey = "ms-43921800-d14a-4667-94ad-8cfec5b1eda6"

    /// Single model descriptor
    struct ModelConfig {
        let id: String
        let displayName: String
        /// Whether the model accepts image/video input
        let supportsVision: Bool
        /// Lightweight models are preferred for analysis agents (Emotion/Memory/Action)
        /// that only do simple JSON extraction — smaller = faster TTFT.
        let isLightweight: Bool
    }

    /// Rotation pool — ordered by preference.
    /// Vision-capable models are tried first when the request contains media.
    static let models: [ModelConfig] = [
        ModelConfig(id: "moonshotai/Kimi-K2.5",                    displayName: "Kimi K2.5",        supportsVision: true,  isLightweight: false),
        ModelConfig(id: "Qwen/Qwen3-VL-235B-A22B-Instruct",        displayName: "Qwen3 VL 235B",    supportsVision: true,  isLightweight: false),
        ModelConfig(id: "Qwen/Qwen3.5-397B-A17B",                  displayName: "Qwen3.5 397B",     supportsVision: false, isLightweight: false),
        ModelConfig(id: "Qwen/Qwen3.5-27B",                        displayName: "Qwen3.5 27B",      supportsVision: false, isLightweight: true),
    ]

    /// UserDefaults key for persisting current model index
    static let modelIndexKey = "APIConfig.currentModelIndex"
}
