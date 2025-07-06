import Foundation

/// Configuration for API endpoints and settings
struct APIConfiguration {
    // MARK: - Base URLs
    
    /// Relay server URL - routes requests through remote relay server
    static let relayServerURL = "http://98.70.88.219:3001"
    
    /// Direct backend URL - for local development only
    static let directBackendURL = "http://98.70.88.219:8080"
    
    // MARK: - Current Configuration
    
    /// Current base URL - using relay server by default
    /// Switch to directBackendURL for local development
    static let baseURL = relayServerURL
    
    // MARK: - Environment Info
    
    /// Returns configuration information for debugging
    static var configInfo: String {
        return """
        API Configuration:
        - Base URL: \(baseURL)
        - Mode: \(baseURL == relayServerURL ? "Relay Server" : "Direct Backend")
        - Relay Server: \(relayServerURL)
        - Direct Backend: \(directBackendURL)
        """
    }
    
    // MARK: - URL Builders
    
    /// Build URL for projects endpoint
    static var projectsURL: String {
        return "\(baseURL)/api/projects"
    }
    
    /// Build URL for chat endpoint
    static var chatURL: String {
        return "\(baseURL)/api/chat"
    }
    
    /// Build URL for abort endpoint
    static func abortURL(requestId: String) -> String {
        return "\(baseURL)/api/abort/\(requestId)"
    }
    
    /// Build URL for conversation histories
    static func historiesURL(projectName: String) -> String {
        return "\(baseURL)/api/projects/\(projectName)/histories"
    }
    
    /// Build URL for specific conversation
    static func conversationURL(projectName: String, sessionId: String) -> String {
        return "\(baseURL)/api/projects/\(projectName)/histories/\(sessionId)"
    }
}

// MARK: - Configuration Extensions

extension APIConfiguration {
    /// Check if currently using relay server
    static var isUsingRelayServer: Bool {
        return baseURL == relayServerURL
    }
    
    /// Check if currently using direct backend
    static var isUsingDirectBackend: Bool {
        return baseURL == directBackendURL
    }
}