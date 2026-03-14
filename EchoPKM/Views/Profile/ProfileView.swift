import SwiftUI

struct ProfileView: View {
    @AppStorage("autoSaveEnabled") private var autoSaveEnabled = true

    var body: some View {
        NavigationStack {
            List {
                // User section
                Section {
                    HStack(spacing: 16) {
                        PetView(petState: PetState())
                            .scaleEffect(0.3)
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            .background(
                                Circle()
                                    .fill(Color.claudeSurfaceTint)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Echo PKM")
                                .font(.yuantiHeadline)
                            Text("你的个人知识伙伴")
                                .font(.yuantiCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Settings section
                Section("设置") {
                    Toggle(isOn: $autoSaveEnabled) {
                        Label("自动保存日记", systemImage: "arrow.clockwise")
                    }
                    .tint(Color.claudeAccent)

                    HStack {
                        Label("API密钥", systemImage: "key.fill")
                        Spacer()
                        Text(apiKeyStatus)
                            .font(.yuantiCaption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Data section
                Section("数据") {
                    Label("导出数据", systemImage: "square.and.arrow.up")
                        .foregroundStyle(Color.claudeWarmGray)
                }

                // About section
                Section("关于") {
                    HStack {
                        Label("版本", systemImage: "info.circle")
                        Spacer()
                        Text(appVersion)
                            .font(.yuantiCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("我的")
                        .font(.yuanti(20, weight: .bold))
                }
            }
        }
    }

    private var apiKeyStatus: String {
        let key = APIConfig.modelScopeAPIKey
        if key.isEmpty {
            return "未配置"
        }
        let prefix = String(key.prefix(6))
        return "\(prefix)..."
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    ProfileView()
}
