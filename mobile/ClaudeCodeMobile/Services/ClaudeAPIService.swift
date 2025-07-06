import Foundation
import Combine

@MainActor
class ClaudeAPIService: ObservableObject {
    static let shared = ClaudeAPIService()
    
    private let decoder = JSONDecoder()
    
    private init() {
        // Print configuration info for debugging
        print(APIConfiguration.configInfo)
    }
    
    // MARK: - Projects API
    
    func getProjects() async throws -> [ProjectInfo] {
        guard let url = URL(string: APIConfiguration.projectsURL) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError("Failed to fetch projects")
        }
        
        let projectsResponse = try decoder.decode(ProjectsResponse.self, from: data)
        return projectsResponse.projects
    }
    
    // MARK: - Chat API
    
    func sendMessage(
        message: String,
        sessionId: String? = nil,
        workingDirectory: String? = nil,
        allowedTools: [String]? = nil
    ) -> AsyncThrowingStream<StreamResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let requestId = UUID().uuidString
                    let chatRequest = ChatRequest(
                        message: message,
                        requestId: requestId,
                        sessionId: sessionId,
                        allowedTools: allowedTools,
                        workingDirectory: workingDirectory
                    )
                    
                    guard let url = URL(string: APIConfiguration.chatURL) else {
                        continuation.finish(throwing: APIError.invalidURL)
                        return
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode(chatRequest)
                    
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: APIError.serverError("Failed to send message"))
                        return
                    }
                    
                    for try await line in asyncBytes.lines {
                        if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            do {
                                let streamResponse = try self.decoder.decode(StreamResponse.self, from: line.data(using: .utf8)!)
                                continuation.yield(streamResponse)
                                
                                if streamResponse.type == .done || streamResponse.type == .aborted {
                                    continuation.finish()
                                    return
                                }
                            } catch {
                                print("Failed to decode line: \(line), error: \(error)")
                                // Continue processing other lines
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Abort API
    
    func abortRequest(requestId: String) async throws {
        guard let url = URL(string: APIConfiguration.abortURL(requestId: requestId)) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError("Failed to abort request")
        }
    }
    
    // MARK: - History API
    
    func getConversationHistories(for project: ProjectInfo) async throws -> [ConversationSummary] {
        guard let url = URL(string: APIConfiguration.historiesURL(projectName: project.encodedName)) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError("Failed to fetch conversation histories")
        }
        
        let historyResponse = try decoder.decode(HistoryListResponse.self, from: data)
        return historyResponse.conversations
    }
    
    func getConversationDetail(for project: ProjectInfo, sessionId: String) async throws -> ConversationHistory {
        guard let url = URL(string: APIConfiguration.conversationURL(projectName: project.encodedName, sessionId: sessionId)) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError("Failed to fetch conversation detail")
        }
        
        return try decoder.decode(ConversationHistory.self, from: data)
    }
}

// MARK: - API Error

enum APIError: LocalizedError {
    case invalidURL
    case serverError(String)
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .serverError(let message):
            return "Server error: \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        }
    }
}