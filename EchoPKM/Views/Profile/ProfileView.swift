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
                                .font(.headline)
                            Text("Your personal knowledge companion")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Settings section
                Section("Settings") {
                    Toggle(isOn: $autoSaveEnabled) {
                        Label("Auto-Save Diary", systemImage: "arrow.clockwise")
                    }
                    .tint(Color.claudeAccent)

                    HStack {
                        Label("API Key", systemImage: "key.fill")
                        Spacer()
                        Text(apiKeyStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Data section
                Section("Data") {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                        .foregroundStyle(Color.claudeWarmGray)
                }

                // About section
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(appVersion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }

    private var apiKeyStatus: String {
        let key = APIConfig.modelScopeAPIKey
        if key.isEmpty {
            return "Not configured"
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
