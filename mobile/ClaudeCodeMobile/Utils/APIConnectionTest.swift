import Foundation

/// Utility for testing API connectivity to the relay server
class APIConnectionTest {
    
    /// Test basic connectivity to the configured API endpoint
    static func testConnection() async -> ConnectionTestResult {
        do {
            // Test the health endpoint of the relay server
            let healthURL = "\(APIConfiguration.baseURL)/health"
            guard let url = URL(string: healthURL) else {
                return .failure("Invalid URL: \(healthURL)")
            }
            
            let startTime = Date()
            let (data, response) = try await URLSession.shared.data(from: url)
            let duration = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure("Invalid response type")
            }
            
            if httpResponse.statusCode == 200 {
                // Try to parse health response
                if let healthData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = healthData["status"] as? String,
                   status == "ok" {
                    return .success(duration)
                } else {
                    return .success(duration) // Server responded but different format
                }
            } else {
                return .failure("HTTP \(httpResponse.statusCode)")
            }
            
        } catch {
            if error.localizedDescription.contains("offline") || 
               error.localizedDescription.contains("network") {
                return .failure("No internet connection")
            } else if error.localizedDescription.contains("timed out") {
                return .failure("Connection timed out")
            } else if error.localizedDescription.contains("refused") {
                return .failure("Connection refused - server may be down")
            } else {
                return .failure("Network error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Test projects API endpoint
    static func testProjectsAPI() async -> ConnectionTestResult {
        do {
            guard let url = URL(string: APIConfiguration.projectsURL) else {
                return .failure("Invalid projects URL")
            }
            
            let startTime = Date()
            let (_, response) = try await URLSession.shared.data(from: url)
            let duration = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure("Invalid response type")
            }
            
            if httpResponse.statusCode == 200 {
                return .success(duration)
            } else {
                return .failure("Projects API HTTP \(httpResponse.statusCode)")
            }
            
        } catch {
            return .failure("Projects API error: \(error.localizedDescription)")
        }
    }
}

/// Result of connection test
enum ConnectionTestResult {
    case success(TimeInterval) // Duration in seconds
    case failure(String)       // Error message
    
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    var message: String {
        switch self {
        case .success(let duration):
            return "✅ Connected successfully (\(String(format: "%.0f", duration * 1000))ms)"
        case .failure(let error):
            return "❌ \(error)"
        }
    }
    
    var duration: TimeInterval? {
        switch self {
        case .success(let duration):
            return duration
        case .failure:
            return nil
        }
    }
}