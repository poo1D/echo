import SwiftUI

struct TagFilterSheet: View {
    var allTopics: [String]
    @Binding var selectedTags: Set<String>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                FlowLayout(spacing: 10) {
                    ForEach(allTopics, id: \.self) { topic in
                        Button {
                            if selectedTags.contains(topic) {
                                selectedTags.remove(topic)
                            } else {
                                selectedTags.insert(topic)
                            }
                        } label: {
                            Text(topic)
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selectedTags.contains(topic)
                                        ? Color.claudeAccent
                                        : Color.claudeSurfaceTint
                                )
                                .foregroundStyle(
                                    selectedTags.contains(topic)
                                        ? .white
                                        : .primary
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Filter by Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        selectedTags.removeAll()
                    }
                    .foregroundStyle(Color.claudeAccent)
                    .disabled(selectedTags.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.claudeAccent)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
