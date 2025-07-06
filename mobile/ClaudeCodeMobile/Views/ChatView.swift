import SwiftUI

struct ChatView: View {
    let project: ProjectInfo
    let onBack: () -> Void
    
    @StateObject private var apiService = ClaudeAPIService.shared
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var currentSessionId: String?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showHistory = false
    
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            messagesView
            
            inputView
        }
        .background(Color.theme.background)
        .onTapGesture {
            hideKeyboard()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Unknown error occurred")
        }
        .sheet(isPresented: $showHistory) {
            ConversationHistoryView(
                project: project,
                onDismiss: { showHistory = false },
                onSelectConversation: { conversation in
                    showHistory = false
                    // TODO: Load selected conversation
                }
            )
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.theme.accent)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(project.displayName)
                    .font(Font.theme.headline)
                    .foregroundColor(Color.theme.primaryText)
                    .lineLimit(1)
                
                Text("Claude Code Assistant")
                    .font(Font.theme.caption1)
                    .foregroundColor(Color.theme.secondaryText)
            }
            
            Spacer()
            
            Button(action: { showHistory = true }) {
                Image(systemName: "clock")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.theme.accent)
            }
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(Color.theme.accent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.theme.cardBackground)
        .overlay(
            Rectangle()
                .fill(Color.theme.separator)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .onChange(of: messages.count) { _ in
                if let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.theme.tertiaryText)
            
            VStack(spacing: 8) {
                Text("Start a conversation")
                    .font(Font.theme.title3)
                    .foregroundColor(Color.theme.primaryText)
                
                Text("Ask Claude to help you with your project")
                    .font(Font.theme.callout)
                    .foregroundColor(Color.theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
    
    private var inputView: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.theme.separator)
                .frame(height: 0.5)
            
            HStack(spacing: 12) {
                TextField("Type your message...", text: $inputText, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(Font.theme.body)
                    .lineLimit(1...6)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.theme.inputBackground)
                    )
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.theme.tertiaryText : Color.theme.accent)
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.theme.cardBackground)
        }
    }
    
    private func sendMessage() {
        let message = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !isLoading else { return }
        
        let userMessage = ChatMessage.userMessage(message)
        messages.append(userMessage)
        inputText = ""
        isLoading = true
        hideKeyboard()
        
        Task {
            do {
                let stream = apiService.sendMessage(
                    message: message,
                    sessionId: currentSessionId,
                    workingDirectory: project.path
                )
                
                for try await streamResponse in stream {
                    handleStreamResponse(streamResponse)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
    
    @MainActor
    private func handleStreamResponse(_ response: StreamResponse) {
        switch response.type {
        case .claude_json:
            if let claudeMessage = response.data {
                if let sessionId = MessageProcessor.extractSessionId(from: claudeMessage) {
                    currentSessionId = sessionId
                }
                
                if let chatMessage = MessageProcessor.createChatMessage(from: response) {
                    messages.append(chatMessage)
                }
            }
            
        case .error:
            errorMessage = response.error ?? "Unknown error"
            showError = true
            isLoading = false
            
        case .done:
            isLoading = false
            
        case .aborted:
            isLoading = false
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.isUser {
                Spacer(minLength: 60)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .font(Font.theme.messageText)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.theme.userMessage)
                        )
                    
                    Text(formatTime(message.timestamp))
                        .font(Font.theme.caption2)
                        .foregroundColor(Color.theme.tertiaryText)
                        .padding(.trailing, 8)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .font(Font.theme.messageText)
                        .foregroundColor(Color.theme.primaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.theme.assistantMessage)
                        )
                    
                    Text(formatTime(message.timestamp))
                        .font(Font.theme.caption2)
                        .foregroundColor(Color.theme.tertiaryText)
                        .padding(.leading, 8)
                }
                
                Spacer(minLength: 60)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ChatView(
        project: ProjectInfo(path: "/Users/test/project", encodedName: "test-project"),
        onBack: {}
    )
}
