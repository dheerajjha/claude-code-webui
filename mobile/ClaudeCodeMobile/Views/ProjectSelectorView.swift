import SwiftUI

struct ProjectSelectorView: View {
    @Binding var selectedProject: ProjectInfo?
    @Binding var showProjectSelector: Bool
    
    @StateObject private var apiService = ClaudeAPIService.shared
    @State private var projects: [ProjectInfo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                if isLoading {
                    loadingView
                } else if projects.isEmpty {
                    emptyStateView
                } else {
                    projectsList
                }
                
                Spacer()
            }
        }
        .task {
            await loadProjects()
        }
        .alert("Error", isPresented: $showError) {
            Button("Retry") {
                Task { await loadProjects() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error occurred")
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Claude Code")
                        .font(Font.theme.largeTitle)
                        .foregroundColor(Color.theme.primaryText)
                    
                    Text("Select a project to get started")
                        .font(Font.theme.callout)
                        .foregroundColor(Color.theme.secondaryText)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.theme.accent)
            
            Text("Loading projects...")
                .font(Font.theme.callout)
                .foregroundColor(Color.theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.theme.tertiaryText)
            
            VStack(spacing: 8) {
                Text("No projects found")
                    .font(Font.theme.title3)
                    .foregroundColor(Color.theme.primaryText)
                
                Text("Make sure your Claude backend is running with configured projects")
                    .font(Font.theme.callout)
                    .foregroundColor(Color.theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: {
                Task { await loadProjects() }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(Font.theme.callout)
                .foregroundColor(Color.theme.accent)
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.theme.accent, lineWidth: 1)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var projectsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(projects) { project in
                    ProjectCard(project: project) {
                        selectProject(project)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
        }
    }
    
    private func selectProject(_ project: ProjectInfo) {
        selectedProject = project
        showProjectSelector = false
    }
    
    private func loadProjects() async {
        isLoading = true
        errorMessage = nil
        
        do {
            projects = try await apiService.getProjects()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
}

struct ProjectCard: View {
    let project: ProjectInfo
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Circle()
                    .fill(Color.theme.accent.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "folder.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.theme.accent)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.displayName)
                        .font(Font.theme.headline)
                        .foregroundColor(Color.theme.primaryText)
                        .lineLimit(1)
                    
                    Text(project.path)
                        .font(Font.theme.footnote)
                        .foregroundColor(Color.theme.secondaryText)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.theme.tertiaryText)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.theme.cardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ProjectSelectorView(
        selectedProject: .constant(nil),
        showProjectSelector: .constant(true)
    )
}