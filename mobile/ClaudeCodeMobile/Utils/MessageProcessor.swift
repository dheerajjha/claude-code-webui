import Foundation

class MessageProcessor {
    static func extractTextContent(from claudeMessage: ClaudeMessage) -> String {
        guard let messageContent = claudeMessage.message?.content else {
            return ""
        }
        
        return messageContent
            .compactMap { item in
                if item.type == .text {
                    return item.text
                }
                return nil
            }
            .joined(separator: "")
    }
    
    static func extractSessionId(from claudeMessage: ClaudeMessage) -> String? {
        return claudeMessage.sessionId
    }
    
    static func formatToolUsage(from claudeMessage: ClaudeMessage) -> String? {
        guard let messageContent = claudeMessage.message?.content else {
            return nil
        }
        
        let toolUses = messageContent.compactMap { item -> String? in
            if item.type == .tool_use, let name = item.name {
                return "🔧 Using tool: \(name)"
            }
            return nil
        }
        
        return toolUses.isEmpty ? nil : toolUses.joined(separator: "\n")
    }
    
    static func createChatMessage(from streamResponse: StreamResponse) -> ChatMessage? {
        guard streamResponse.type == .claude_json,
              let claudeMessage = streamResponse.data else {
            return nil
        }
        
        switch claudeMessage.type {
        case .assistant:
            let content = extractTextContent(from: claudeMessage)
            guard !content.isEmpty else { return nil }
            return ChatMessage.assistantMessage(content, sessionId: claudeMessage.sessionId)
            
        case .tool:
            if let toolInfo = formatToolUsage(from: claudeMessage) {
                return ChatMessage.assistantMessage(toolInfo, sessionId: claudeMessage.sessionId)
            }
            return nil
            
        case .system:
            if let cwd = claudeMessage.cwd {
                return ChatMessage.assistantMessage("💻 Working directory: \(cwd)", sessionId: claudeMessage.sessionId)
            }
            return nil
            
        case .result:
            if let usage = claudeMessage.usage {
                let tokens = "📊 Usage: \(usage.inputTokens ?? 0) input, \(usage.outputTokens ?? 0) output tokens"
                return ChatMessage.assistantMessage(tokens, sessionId: claudeMessage.sessionId)
            }
            return nil
        }
    }
}