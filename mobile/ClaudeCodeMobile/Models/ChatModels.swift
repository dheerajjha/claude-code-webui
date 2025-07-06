import Foundation

// MARK: - Chat Request/Response Models

struct ChatRequest: Codable {
    let message: String
    let requestId: String
    let sessionId: String?
    let allowedTools: [String]?
    let workingDirectory: String?
}

struct StreamResponse: Codable {
    let type: StreamResponseType
    let data: ClaudeMessage?
    let error: String?
    
    enum StreamResponseType: String, Codable {
        case claude_json = "claude_json"
        case error = "error"
        case done = "done"
        case aborted = "aborted"
    }
}

// MARK: - Claude Message Models

struct ClaudeMessage: Codable {
    let type: ClaudeMessageType
    let sessionId: String?
    let message: ClaudeMessageContent?
    let cwd: String?
    let tools: [String]?
    let subtype: String?
    let usage: ClaudeUsage?
    
    enum CodingKeys: String, CodingKey {
        case type
        case sessionId = "session_id"
        case message, cwd, tools, subtype, usage
    }
}

enum ClaudeMessageType: String, Codable {
    case system = "system"
    case assistant = "assistant"
    case tool = "tool"
    case result = "result"
}

struct ClaudeMessageContent: Codable {
    let content: [ClaudeContentItem]
}

struct ClaudeContentItem: Codable {
    let type: ClaudeContentType
    let text: String?
    let name: String?
    let input: [String: AnyCodable]?
    
    enum ClaudeContentType: String, Codable {
        case text = "text"
        case tool_use = "tool_use"
    }
}

struct ClaudeUsage: Codable {
    let inputTokens: Int?
    let outputTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - UI Message Models

struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    let sessionId: String?
    
    static func userMessage(_ content: String) -> ChatMessage {
        ChatMessage(
            content: content,
            isUser: true,
            timestamp: Date(),
            sessionId: nil
        )
    }
    
    static func assistantMessage(_ content: String, sessionId: String?) -> ChatMessage {
        ChatMessage(
            content: content,
            isUser: false,
            timestamp: Date(),
            sessionId: sessionId
        )
    }
}

// MARK: - Helper for Dynamic JSON

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            throw DecodingError.typeMismatch(
                AnyCodable.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to decode value")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unable to encode value")
            )
        }
    }
}