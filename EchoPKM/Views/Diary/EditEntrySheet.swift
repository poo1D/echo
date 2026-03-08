import SwiftUI
import SwiftData

struct EditEntrySheet: View {
    @Bindable var entry: DiaryEntry
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var summary: String = ""
    @State private var moodEmoji: String?
    @State private var topics: [String] = []
    @State private var newTopic: String = ""

    private let moodEmojis = [
        "😊", "😢", "😡", "😴", "🤩", "😰",
        "🥰", "😌", "🤔", "😤", "💪", "🎉"
    ]

    var body: some View {
        NavigationStack {
            Form {
                summarySection
                moodSection
                topicsSection
                deleteSection
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear {
                summary = entry.summary
                moodEmoji = entry.moodEmoji
                topics = entry.topics
            }
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        Section("Summary") {
            TextEditor(text: $summary)
                .frame(minHeight: 100)
        }
    }

    private var moodSection: some View {
        Section("Mood") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(moodEmojis, id: \.self) { emoji in
                    Text(emoji)
                        .font(.title)
                        .padding(8)
                        .background(
                            moodEmoji == emoji
                                ? Color.blue.opacity(0.2)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture {
                            moodEmoji = moodEmoji == emoji ? nil : emoji
                        }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var topicsSection: some View {
        Section("Topics") {
            FlowLayout(spacing: 8) {
                ForEach(topics, id: \.self) { topic in
                    HStack(spacing: 4) {
                        Text(topic)
                            .font(.caption)
                        Button {
                            topics.removeAll { $0 == topic }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(Capsule())
                }
            }

            HStack {
                TextField("Add topic...", text: $newTopic)
                    .textInputAutocapitalization(.never)
                    .onSubmit { addTopic() }
                Button("Add") { addTopic() }
                    .disabled(newTopic.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                onDelete?()
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Label("Delete Entry", systemImage: "trash")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Actions

    private func save() {
        entry.summary = summary
        entry.moodEmoji = moodEmoji
        entry.topics = topics
        try? modelContext.save()
        dismiss()
    }

    private func addTopic() {
        let trimmed = newTopic.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !topics.contains(trimmed) else { return }
        topics.append(trimmed)
        newTopic = ""
    }
}
