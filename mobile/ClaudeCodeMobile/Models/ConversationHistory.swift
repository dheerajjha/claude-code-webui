import Foundation

// MARK: - Conversation History Models

struct ConversationSummary: Codable, Identifiable {
    let id = UUID()
    let sessionId: String
    let startTime: String
    let lastTime: String
    let messageCount: Int
    let lastMessagePreview: String
    
    var startDate: Date {
        ISO8601DateFormatter().date(from: startTime) ?? Date()
    }
    
    var lastDate: Date {
        ISO8601DateFormatter().date(from: lastTime) ?? Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case sessionId, startTime, lastTime, messageCount, lastMessagePreview
    }
}

struct ConversationHistory: Codable {
    let sessionId: String
    let messages: [ConversationMessage]
    let metadata: ConversationMetadata
}

struct ConversationMessage: Codable, Identifiable {
    let id = UUID()
    let timestamp: String
    let content: ClaudeMessage
    
    var date: Date {
        ISO8601DateFormatter().date(from: timestamp) ?? Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case timestamp, content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        
        // The content is the Claude message without the timestamp wrapper
        let messageDecoder = try container.superDecoder(forKey: .content)
        content = try ClaudeMessage(from: messageDecoder)
    }
}

struct ConversationMetadata: Codable {
    let startTime: String
    let endTime: String
    let messageCount: Int
}

struct HistoryListResponse: Codable {
    let conversations: [ConversationSummary]
}