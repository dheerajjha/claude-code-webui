import Foundation

struct ProjectInfo: Codable, Identifiable, Hashable {
    let id = UUID()
    let path: String
    let encodedName: String
    
    var displayName: String {
        path.components(separatedBy: "/").last ?? "Unknown Project"
    }
    
    enum CodingKeys: String, CodingKey {
        case path, encodedName
    }
}

struct ProjectsResponse: Codable {
    let projects: [ProjectInfo]
}