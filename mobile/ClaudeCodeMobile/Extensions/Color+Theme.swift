import SwiftUI

extension Color {
    static let theme = ColorTheme()
}

struct ColorTheme {
    // Primary colors - inspired by nikitabier's minimal aesthetic
    let primary = Color(red: 0.09, green: 0.09, blue: 0.09) // Almost black
    let secondary = Color(red: 0.45, green: 0.45, blue: 0.45) // Medium gray
    let accent = Color(red: 0.0, green: 0.48, blue: 1.0) // System blue
    
    // Background colors
    let background = Color(red: 0.98, green: 0.98, blue: 0.98) // Off-white
    let cardBackground = Color.white
    let inputBackground = Color(red: 0.96, green: 0.96, blue: 0.96)
    
    // Text colors
    let primaryText = Color(red: 0.09, green: 0.09, blue: 0.09)
    let secondaryText = Color(red: 0.45, green: 0.45, blue: 0.45)
    let tertiaryText = Color(red: 0.7, green: 0.7, blue: 0.7)
    
    // Message colors
    let userMessage = Color(red: 0.0, green: 0.48, blue: 1.0)
    let assistantMessage = Color(red: 0.95, green: 0.95, blue: 0.95)
    
    // Border colors
    let border = Color(red: 0.9, green: 0.9, blue: 0.9)
    let separator = Color(red: 0.94, green: 0.94, blue: 0.94)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}