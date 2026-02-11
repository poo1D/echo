import SwiftUI
import SwiftData

/// 日记详情Sheet (支持编辑)
struct JournalDetailSheet: View {
    let entry: JournalEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var editedTitle: String = ""
    @State private var editedContent: String = ""
    @State private var postscript: String = ""
    @State private var isEditing = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 日期时间
                    HStack {
                        Text(formattedDate)
                            .font(JournalFonts.caption)
                            .foregroundStyle(JournalColors.warmGray)
                        Spacer()
                        if let mood = entry.moodEmoji {
                            Text(mood)
                                .font(.title2)
                        }
                    }
                    
                    // 标题
                    if isEditing {
                        TextField("标题", text: $editedTitle)
                            .font(JournalFonts.title)
                    } else {
                        Text(entry.title.isEmpty ? "无标题" : entry.title)
                            .font(JournalFonts.title)
                            .foregroundStyle(JournalColors.inkBlack)
                    }
                    
                    Divider()
                    
                    // 内容
                    if isEditing {
                        TextEditor(text: $editedContent)
                            .font(JournalFonts.body)
                            .frame(minHeight: 200)
                    } else {
                        Text(entry.textContent)
                            .font(JournalFonts.body)
                            .foregroundStyle(JournalColors.inkBlack)
                    }
                    
                    // 后记区域
                    VStack(alignment: .leading, spacing: 8) {
                        Text("添加后记")
                            .font(JournalFonts.caption)
                            .foregroundStyle(JournalColors.warmGray)
                        
                        TextField("写下此刻的想法...", text: $postscript, axis: .vertical)
                            .font(JournalFonts.body)
                            .padding()
                            .background(JournalColors.lavender.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // 宠物回应
                    PetResponseCard()
                }
                .padding()
            }
            .background(PaperTexture())
            .navigationTitle("日记详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "保存" : "编辑") {
                        if isEditing {
                            saveChanges()
                        } else {
                            startEditing()
                        }
                    }
                }
            }
        }
        .onAppear {
            editedTitle = entry.title
            editedContent = entry.textContent
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: entry.createdAt)
    }
    
    private func startEditing() {
        isEditing = true
    }
    
    private func saveChanges() {
        entry.title = editedTitle
        var newContent = editedContent
        if !postscript.isEmpty {
            newContent += "\n\n📝 后记 (\(formattedDate)):\n\(postscript)"
            postscript = ""
        }
        entry.textContent = newContent
        isEditing = false
    }
}

/// AI智能搜索Sheet
struct AISearchSheet: View {
    let entries: [JournalEntry]
    let onSearch: ([JournalEntry]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var isSearching = false
    @State private var results: [JournalEntry] = []
    @State private var aiSummary = ""
    
    private let apiEndpoint = APIConfig.apiEndpoint
    private var apiKey: String { APIConfig.apiKey }
    private let modelId = "moonshotai/Kimi-K2.5"
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 搜索框
                HStack {
                    Image(systemName: "sparkle.magnifyingglass")
                        .foregroundStyle(JournalColors.lavender)
                    
                    TextField("用自然语言搜索，如'上周开心的事'", text: $query)
                        .font(JournalFonts.body)
                    
                    if isSearching {
                        ProgressView()
                    }
                }
                .padding()
                .background(JournalColors.warmWhite, in: RoundedRectangle(cornerRadius: 12))
                
                // 快捷搜索
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        quickSearchChip("最近的开心时刻")
                        quickSearchChip("工作相关")
                        quickSearchChip("有压力的日子")
                        quickSearchChip("成长与收获")
                    }
                }
                
                // AI总结
                if !aiSummary.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(JournalColors.lavender)
                            Text("AI总结")
                                .font(JournalFonts.caption)
                        }
                        Text(aiSummary)
                            .font(JournalFonts.body)
                            .foregroundStyle(JournalColors.warmGray)
                    }
                    .padding()
                    .background(JournalColors.lavender.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                
                // 搜索结果
                if !results.isEmpty {
                    Text("找到 \(results.count) 条相关日记")
                        .font(JournalFonts.caption)
                        .foregroundStyle(JournalColors.warmGray)
                    
                    ScrollView {
                        ForEach(results) { entry in
                            searchResultRow(entry)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("AI智能搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("搜索") {
                        performSearch()
                    }
                    .disabled(query.isEmpty || isSearching)
                }
            }
        }
    }
    
    private func quickSearchChip(_ text: String) -> some View {
        Button {
            query = text
            performSearch()
        } label: {
            Text(text)
                .font(JournalFonts.caption)
                .foregroundStyle(JournalColors.lavender)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(JournalColors.lavender.opacity(0.1), in: Capsule())
        }
    }
    
    private func searchResultRow(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.title.isEmpty ? "无标题" : entry.title)
                .font(JournalFonts.headline)
            Text(entry.textContent)
                .font(JournalFonts.caption)
                .foregroundStyle(JournalColors.warmGray)
                .lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(JournalColors.warmWhite, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func performSearch() {
        isSearching = true
        
        Task {
            // 构建日记摘要
            let journalSummaries = entries.prefix(20).map { entry in
                "[\(entry.id)]: \(entry.title) - \(entry.textContent.prefix(100))"
            }.joined(separator: "\n")
            
            let prompt = """
            用户搜索: "\(query)"
            
            以下是用户的日记列表:
            \(journalSummaries)
            
            请返回JSON格式：
            {"ids": ["匹配的日记ID列表"], "summary": "对搜索结果的简短总结"}
            """
            
            do {
                let response = try await callAPI(prompt: prompt)
                parseResults(from: response)
            } catch {
                print("搜索失败: \(error)")
                // 降级到关键词搜索
                results = entries.filter { entry in
                    entry.title.localizedCaseInsensitiveContains(query) ||
                    entry.textContent.localizedCaseInsensitiveContains(query)
                }
            }
            
            isSearching = false
            onSearch(results)
        }
    }
    
    private func callAPI(prompt: String) async throws -> String {
        guard let url = URL(string: apiEndpoint) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": modelId,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 200
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        
        throw URLError(.cannotParseResponse)
    }
    
    private func parseResults(from response: String) {
        var jsonString = response
        if let startIndex = response.firstIndex(of: "{"),
           let endIndex = response.lastIndex(of: "}") {
            jsonString = String(response[startIndex...endIndex])
        }
        
        if let data = jsonString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let summary = json["summary"] as? String {
                aiSummary = summary
            }
            // 降级到关键词匹配
            results = entries.filter { entry in
                entry.title.localizedCaseInsensitiveContains(query) ||
                entry.textContent.localizedCaseInsensitiveContains(query)
            }
        }
    }
}

#Preview("Detail Sheet") {
    JournalDetailSheet(entry: JournalEntry(title: "测试日记", textContent: "今天天气不错"))
}
