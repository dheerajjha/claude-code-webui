import SwiftUI

extension Font {
    static let theme = FontTheme()
}

struct FontTheme {
    // Typography inspired by nikitabier's clean aesthetic
    
    // Display fonts
    let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
    let title1 = Font.system(size: 28, weight: .bold, design: .default)
    let title2 = Font.system(size: 22, weight: .bold, design: .default)
    let title3 = Font.system(size: 20, weight: .semibold, design: .default)
    
    // Body fonts
    let headline = Font.system(size: 17, weight: .semibold, design: .default)
    let body = Font.system(size: 17, weight: .regular, design: .default)
    let callout = Font.system(size: 16, weight: .regular, design: .default)
    let subheadline = Font.system(size: 15, weight: .regular, design: .default)
    let footnote = Font.system(size: 13, weight: .regular, design: .default)
    let caption1 = Font.system(size: 12, weight: .regular, design: .default)
    let caption2 = Font.system(size: 11, weight: .regular, design: .default)
    
    // Custom message fonts
    let messageText = Font.system(size: 16, weight: .regular, design: .default)
    let messageTimestamp = Font.system(size: 12, weight: .medium, design: .default)
    
    // Monospace for code
    let code = Font.system(size: 14, weight: .regular, design: .monospaced)
}

extension Text {
    func themeFont(_ font: Font) -> Text {
        self.font(font)
    }
    
    func primaryText() -> Text {
        self.foregroundColor(.theme.primaryText)
    }
    
    func secondaryText() -> Text {
        self.foregroundColor(.theme.secondaryText)
    }
    
    func tertiaryText() -> Text {
        self.foregroundColor(.theme.tertiaryText)
    }
}