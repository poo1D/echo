import Foundation
import SwiftData

@Model
class DiaryEntry {
    var id: UUID
    var createdAt: Date
    var summary: String
    var moodEmoji: String?
    var moodScore: Int?
    var transcript: Data?
    var audioFileNames: [String]
    var photoFileNames: [String]
    var topics: [String]
    var aiInsight: String?
    var locationName: String?
    var latitude: Double?
    var longitude: Double?

    init(
        summary: String,
        moodEmoji: String? = nil,
        moodScore: Int? = nil,
        transcript: Data? = nil,
        audioFileNames: [String] = [],
        photoFileNames: [String] = [],
        topics: [String] = [],
        aiInsight: String? = nil,
        locationName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.summary = summary
        self.moodEmoji = moodEmoji
        self.moodScore = moodScore
        self.transcript = transcript
        self.audioFileNames = audioFileNames
        self.photoFileNames = photoFileNames
        self.topics = topics
        self.aiInsight = aiInsight
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - Transcript Encoding Helpers

struct TranscriptMessage: Codable, Identifiable {
    let id: UUID
    let role: String
    let content: String
    let timestamp: Date
    var photoFileNames: [String]

    init(id: UUID, role: String, content: String, timestamp: Date, photoFileNames: [String] = []) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.photoFileNames = photoFileNames
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(String.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        photoFileNames = (try? container.decode([String].self, forKey: .photoFileNames)) ?? []
    }
}

extension DiaryEntry {
    var decodedTranscript: [TranscriptMessage] {
        guard let data = transcript else { return [] }
        return (try? JSONDecoder().decode([TranscriptMessage].self, from: data)) ?? []
    }

    static func encodeTranscript(_ messages: [ChatService.Message]) -> Data? {
        let items = messages.map {
            TranscriptMessage(
                id: $0.id,
                role: $0.role.rawValue,
                content: $0.content,
                timestamp: $0.timestamp,
                photoFileNames: $0.photoFileNames
            )
        }
        return try? JSONEncoder().encode(items)
    }
}
