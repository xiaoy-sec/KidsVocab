import Foundation

struct AIChatConversation: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var messages: [AIChatMessage]
    var createdAt: Date
    var updatedAt: Date
}

final class AIChatHistoryStore {
    static let shared = AIChatHistoryStore()

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ai_chat_history.json")
    }

    private init() {}

    func loadConversations() -> [AIChatConversation] {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([AIChatConversation].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    func saveConversations(_ conversations: [AIChatConversation]) {
        guard let encoded = try? JSONEncoder().encode(conversations.sorted(by: { $0.updatedAt > $1.updatedAt })) else { return }
        try? encoded.write(to: fileURL, options: [.atomic])
    }
}
