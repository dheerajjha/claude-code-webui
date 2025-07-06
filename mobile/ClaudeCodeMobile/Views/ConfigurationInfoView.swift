import SwiftUI

/// Debug view to display current API configuration
struct ConfigurationInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var connectionTestResult: ConnectionTestResult?
    @State private var isTestingConnection = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Current Configuration
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Configuration")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ConfigurationRow(
                            title: "Base URL",
                            value: APIConfiguration.baseURL,
                            isHighlighted: true
                        )
                        
                        ConfigurationRow(
                            title: "Mode",
                            value: APIConfiguration.isUsingRelayServer ? "Relay Server" : "Direct Backend",
                            isHighlighted: false
                        )
                    }
                    
                    Divider()
                    
                    // Available Endpoints
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available Endpoints")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ConfigurationRow(title: "Projects", value: APIConfiguration.projectsURL)
                        ConfigurationRow(title: "Chat", value: APIConfiguration.chatURL)
                        ConfigurationRow(title: "Abort", value: APIConfiguration.abortURL(requestId: "{requestId}"))
                    }
                    
                    Divider()
                    
                    // Alternative Configurations
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Alternative Configurations")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ConfigurationRow(
                            title: "Relay Server",
                            value: APIConfiguration.relayServerURL,
                            isHighlighted: APIConfiguration.isUsingRelayServer
                        )
                        
                        ConfigurationRow(
                            title: "Direct Backend",
                            value: APIConfiguration.directBackendURL,
                            isHighlighted: APIConfiguration.isUsingDirectBackend
                        )
                    }
                    
                    Divider()
                    
                    // Network Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Network Information")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("To test connectivity, ensure the selected server is running and accessible from your device.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        if APIConfiguration.isUsingRelayServer {
                            Text("💡 Using relay server - backend can be on any network")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else {
                            Text("⚠️ Using direct backend - must be on same network")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        // Connection Test Section
                        VStack(spacing: 12) {
                            Button(action: {
                                testConnection()
                            }) {
                                HStack {
                                    if isTestingConnection {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "wifi.circle")
                                    }
                                    Text(isTestingConnection ? "Testing..." : "Test Connection")
                                }
                                .font(.callout)
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                            .disabled(isTestingConnection)
                            
                            if let result = connectionTestResult {
                                Text(result.message)
                                    .font(.caption)
                                    .foregroundColor(result.isSuccess ? .green : .red)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
            }
            .navigationTitle("API Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    /// Test the current API configuration
    private func testConnection() {
        isTestingConnection = true
        connectionTestResult = nil
        
        Task {
            let result = await APIConnectionTest.testConnection()
            
            await MainActor.run {
                connectionTestResult = result
                isTestingConnection = false
            }
        }
    }
}

/// Row component for displaying configuration information
struct ConfigurationRow: View {
    let title: String
    let value: String
    var isHighlighted: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isHighlighted ? .blue : .secondary)
            
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(isHighlighted ? .blue : .primary)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
        }
    }
}

#Preview {
    ConfigurationInfoView()
}