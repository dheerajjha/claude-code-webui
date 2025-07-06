# Claude Code Mobile 📱

A beautiful iOS client for Claude Code Web UI built with SwiftUI. Features a clean, minimal design inspired by modern iOS app aesthetics.

## Features

- 🎨 **Clean Design**: Minimal interface inspired by nikitabier's design philosophy
- 💬 **Real-time Chat**: Streaming responses from Claude AI
- 📁 **Project Selection**: Choose from available Claude projects
- 🔄 **Session Continuity**: Maintains conversation context
- 📱 **Native iOS**: Built with SwiftUI for iOS 17+
- ⚡ **Fast & Responsive**: Optimized for mobile performance

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Claude Code backend running on localhost:8080

## Architecture

The app follows MVVM architecture with clean separation of concerns:

```
ClaudeCodeMobile/
├── Views/              # SwiftUI views
│   ├── ProjectSelectorView.swift
│   └── ChatView.swift
├── Models/             # Data models
│   ├── ProjectInfo.swift
│   └── ChatModels.swift
├── Services/           # API and business logic
│   └── ClaudeAPIService.swift
├── Utils/              # Utilities and helpers
│   └── MessageProcessor.swift
└── Extensions/         # SwiftUI extensions
    ├── Color+Theme.swift
    └── Font+Theme.swift
```

## Design System

### Colors
- **Primary**: Near-black (#171717) for main text
- **Secondary**: Medium gray (#737373) for secondary text  
- **Accent**: System blue (#007AFF) for interactive elements
- **Background**: Off-white (#FAFAFA) for app background
- **Cards**: Pure white (#FFFFFF) with subtle shadows

### Typography
- **Display**: San Francisco with bold weights for headers
- **Body**: San Francisco Regular for readable content
- **Code**: SF Mono for technical content

### Layout
- **Spacing**: 8pt grid system for consistent spacing
- **Borders**: Rounded corners (12-20pt radius)
- **Shadows**: Subtle drop shadows (black 5% opacity)

## Setup Instructions

1. **Start the Backend**:
   ```bash
   cd ../backend
   deno task dev
   ```

2. **Open in Xcode**:
   ```bash
   open ClaudeCodeMobile.xcodeproj
   ```

3. **Build and Run**:
   - Select your target device/simulator
   - Press Cmd+R to build and run

## API Integration

The app communicates with the Claude Code backend via REST APIs:

- `GET /api/projects` - Fetch available projects
- `POST /api/chat` - Send messages with streaming responses
- `POST /api/abort/:requestId` - Cancel ongoing requests

### Streaming Support

Messages are processed in real-time using AsyncSequence:

```swift
let stream = apiService.sendMessage(message: "Hello Claude")
for try await response in stream {
    // Handle streaming response
}
```

## State Management

Uses `@StateObject` and `@ObservableObject` for reactive state management:

- **ClaudeAPIService**: Singleton service for API communication
- **Chat State**: Local state in views for UI updates
- **Message Processing**: Utility functions for Claude message parsing

## Error Handling

Comprehensive error handling with user-friendly messages:

- Network connectivity issues
- API response errors
- JSON parsing failures
- Stream interruption handling

## Performance Optimizations

- **Lazy Loading**: Messages loaded on-demand
- **Memory Management**: Proper cleanup of streams and subscriptions
- **UI Optimization**: Efficient SwiftUI view updates
- **Background Processing**: Heavy JSON parsing off main thread

## Contributing

1. Follow Swift API Design Guidelines
2. Use SwiftUI best practices
3. Maintain the minimal design aesthetic
4. Test on multiple device sizes
5. Ensure accessibility compliance

## License

This project follows the same license as the parent Claude Code Web UI project.