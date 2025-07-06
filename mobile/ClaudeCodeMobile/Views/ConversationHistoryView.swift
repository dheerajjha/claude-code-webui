import SwiftUI

struct ConversationHistoryView: View {
    let project: ProjectInfo
    let onDismiss: () -> Void
    let onSelectConversation: (ConversationSummary) -> Void
    
    @StateObject private var apiService = ClaudeAPIService.shared
    @State private var conversations: [ConversationSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if isLoading {
                        loadingView
                    } else if conversations.isEmpty {
                        emptyStateView
                    } else {
                        conversationsList
                    }
                }
            }
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundColor(Color.theme.accent)
                }
            }
        }
        .task {
            await loadConversations()
        }
        .alert("Error", isPresented: $showError) {
            Button("Retry") {
                Task { await loadConversations() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error occurred")
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.theme.accent)
            
            Text("Loading conversations...")
                .font(Font.theme.callout)
                .foregroundColor(Color.theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.theme.tertiaryText)
            
            VStack(spacing: 8) {
                Text("No conversations yet")
                    .font(Font.theme.title3)
                    .foregroundColor(Color.theme.primaryText)
                
                Text("Start a new conversation to see it appear here")
                    .font(Font.theme.callout)
                    .foregroundColor(Color.theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var conversationsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(conversations) { conversation in
                    ConversationCard(conversation: conversation) {
                        onSelectConversation(conversation)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }
    
    private func loadConversations() async {
        isLoading = true
        errorMessage = nil
        
        do {
            conversations = try await apiService.getConversationHistories(for: project)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
}

struct ConversationCard: View {
    let conversation: ConversationSummary
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Session \(String(conversation.sessionId.prefix(8)))")
                            .font(Font.theme.headline)
                            .foregroundColor(Color.theme.primaryText)
                        
                        Text("\(conversation.messageCount) messages")
                            .font(Font.theme.footnote)
                            .foregroundColor(Color.theme.secondaryText)
                    }
                    
                    Spacer()
                    
                    Text(formatRelativeDate(conversation.lastDate))
                        .font(Font.theme.caption1)
                        .foregroundColor(Color.theme.tertiaryText)
                }
                
                Text(conversation.lastMessagePreview)
                    .font(Font.theme.callout)
                    .foregroundColor(Color.theme.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.theme.cardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    ConversationHistoryView(
        project: ProjectInfo(path: "/Users/test/project", encodedName: "test-project"),
        onDismiss: {},
        onSelectConversation: { _ in }
    )
}