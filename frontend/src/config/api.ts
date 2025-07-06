// API configuration - supports both direct backend and relay server modes
export const API_CONFIG = {
  ENDPOINTS: {
    CHAT: "/api/chat",
    ABORT: "/api/abort",
    PROJECTS: "/api/projects",
    HISTORIES: "/api/projects",
    CONVERSATIONS: "/api/projects",
  },
  // Relay server configuration
  RELAY_SERVER: {
    // Set VITE_USE_RELAY_SERVER=true to use relay server mode
    ENABLED: import.meta.env.VITE_USE_RELAY_SERVER === 'true',
    // Set VITE_RELAY_SERVER_URL to override default relay server URL
    URL: import.meta.env.VITE_RELAY_SERVER_URL || 'http://98.70.88.219:3001',
  },
} as const;

// Helper function to get full API URL
export const getApiUrl = (endpoint: string) => {
  // If relay server is enabled, use the relay server URL
  if (API_CONFIG.RELAY_SERVER.ENABLED) {
    return `${API_CONFIG.RELAY_SERVER.URL}${endpoint}`;
  }
  // Otherwise use relative paths (Vite proxy in development, or same origin in production)
  return endpoint;
};

// Helper function to get abort URL
export const getAbortUrl = (requestId: string) => {
  return getApiUrl(`${API_CONFIG.ENDPOINTS.ABORT}/${requestId}`);
};

// Helper function to get chat URL
export const getChatUrl = () => {
  return getApiUrl(API_CONFIG.ENDPOINTS.CHAT);
};

// Helper function to get projects URL
export const getProjectsUrl = () => {
  return getApiUrl(API_CONFIG.ENDPOINTS.PROJECTS);
};

// Helper function to get histories URL
export const getHistoriesUrl = (projectPath: string) => {
  const encodedPath = encodeURIComponent(projectPath);
  return getApiUrl(`${API_CONFIG.ENDPOINTS.HISTORIES}/${encodedPath}/histories`);
};

// Helper function to get conversation URL
export const getConversationUrl = (
  encodedProjectName: string,
  sessionId: string,
) => {
  return getApiUrl(`${API_CONFIG.ENDPOINTS.CONVERSATIONS}/${encodedProjectName}/histories/${sessionId}`);
};
