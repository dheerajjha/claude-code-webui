import SwiftUI

struct ContentView: View {
    @State private var selectedProject: ProjectInfo?
    @State private var showProjectSelector = true
    
    var body: some View {
        NavigationStack {
            if showProjectSelector {
                ProjectSelectorView(
                    selectedProject: $selectedProject,
                    showProjectSelector: $showProjectSelector
                )
            } else {
                ChatView(
                    project: selectedProject!,
                    onBack: {
                        showProjectSelector = true
                        selectedProject = nil
                    }
                )
            }
        }
    }
}

#Preview {
    ContentView()
}