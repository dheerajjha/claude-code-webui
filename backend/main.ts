import { parseCliArgs } from "./args.ts";
import { handleProjectsRequest } from "./handlers/projects.ts";
import { handleHistoriesRequest } from "./handlers/histories.ts";
import { handleConversationRequest } from "./handlers/conversations.ts";
import { handleChatRequest } from "./handlers/chat.ts";
import { handleAbortRequest } from "./handlers/abort.ts";

const args = await parseCliArgs();

const RELAY_SERVER_URL = args.relayUrl;

// Debug mode enabled via CLI flag or environment variable
const DEBUG_MODE = args.debug;

// Store AbortControllers for each request (shared with chat handler)
const requestAbortControllers = new Map<string, AbortController>();

// WebSocket connection to relay server
let relayConnection: WebSocket | null = null;
let reconnectAttempts = 0;
const MAX_RECONNECT_ATTEMPTS = 10;
const RECONNECT_DELAY = 5000; // 5 seconds

// Connect to relay server via WebSocket
async function connectToRelay() {
  try {
    console.log(`🔗 Connecting to relay server: ${RELAY_SERVER_URL}`);
    
    relayConnection = new WebSocket(RELAY_SERVER_URL);
    
    relayConnection.onopen = () => {
      console.log("✅ Connected to relay server");
      reconnectAttempts = 0;
      
      // Send registration message
      relayConnection?.send(JSON.stringify({
        type: "backend_register",
        data: {
          backendId: `backend-${Date.now()}`,
          capabilities: ["chat", "projects", "histories", "abort"],
          version: "v0.1.25"
        }
      }));
    };
    
    relayConnection.onmessage = async (event) => {
      try {
        const message = JSON.parse(event.data);
        await handleRelayMessage(message);
      } catch (error) {
        console.error("Error handling relay message:", error);
      }
    };
    
    relayConnection.onclose = () => {
      console.log("❌ Relay connection closed");
      relayConnection = null;
      
      // Attempt to reconnect
      if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
        reconnectAttempts++;
        console.log(`🔄 Reconnecting in ${RECONNECT_DELAY}ms (attempt ${reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS})`);
        setTimeout(connectToRelay, RECONNECT_DELAY);
      } else {
        console.error("❌ Max reconnection attempts reached");
      }
    };
    
    relayConnection.onerror = (error) => {
      console.error("❌ Relay connection error:", error);
    };
    
  } catch (error) {
    console.error("❌ Failed to connect to relay server:", error);
  }
}

// Handle messages from relay server
async function handleRelayMessage(message: any) {
  if (DEBUG_MODE) {
    console.debug("[DEBUG] Received relay message:", JSON.stringify(message, null, 2));
  }
  
  const { type, requestId, data } = message;
  
  try {
    let response: any;
    
    switch (type) {
      case "api_request":
        response = await handleApiRequest(data);
        break;
      case "ping":
        response = { type: "pong", timestamp: Date.now() };
        break;
      case "heartbeat_ack":
        // Heartbeat acknowledgment from relay server - no response needed
        return;
      default:
        console.warn("Unknown message type:", type);
        return;
    }
    
    // Send response back to relay
    if (relayConnection && requestId) {
      // Handle streaming responses specially
      if (response && response.type === "streaming_response") {
        await handleStreamingResponse(response.response, requestId);
      } else {
        relayConnection.send(JSON.stringify({
          type: "api_response",
          requestId,
          data: response
        }));
      }
    }
    
  } catch (error) {
    console.error("Error processing relay message:", error);
    
    // Send error response
    if (relayConnection && requestId) {
      relayConnection.send(JSON.stringify({
        type: "api_response",
        requestId,
        data: {
          error: error instanceof Error ? error.message : String(error),
          status: 500
        }
      }));
    }
  }
}

// Handle streaming responses by forwarding chunks in real-time
async function handleStreamingResponse(response: Response, requestId: string) {
  try {
    const reader = response.body?.getReader();
    const decoder = new TextDecoder();
    
    if (reader && relayConnection) {
      console.log(`[DEBUG] Starting streaming for request ${requestId}`);
      
      // Send initial streaming start message
      relayConnection.send(JSON.stringify({
        type: "streaming_start",
        requestId
      }));
      
      let chunkCount = 0;
      while (true) {
        const { done, value } = await reader.read();
        if (done) {
          console.log(`[DEBUG] Streaming completed for request ${requestId}, total chunks: ${chunkCount}`);
          break;
        }
        
        const chunk = decoder.decode(value, { stream: true });
        chunkCount++;
        
        if (DEBUG_MODE) {
          console.log(`[DEBUG] Streaming chunk ${chunkCount} for request ${requestId}: ${chunk.substring(0, 100)}...`);
        }
        
        // Check if relay connection is still open
        if (relayConnection.readyState !== WebSocket.OPEN) {
          console.error(`[ERROR] Relay connection closed during streaming for request ${requestId}`);
          break;
        }
        
        // Send each chunk as it arrives
        relayConnection.send(JSON.stringify({
          type: "streaming_chunk",
          requestId,
          data: chunk
        }));
      }
      
      // Send streaming end message
      if (relayConnection.readyState === WebSocket.OPEN) {
        relayConnection.send(JSON.stringify({
          type: "streaming_end",
          requestId
        }));
        console.log(`[DEBUG] Sent streaming_end for request ${requestId}`);
      }
    }
  } catch (error) {
    console.error(`[ERROR] Streaming failed for request ${requestId}:`, error);
    
    // Send error if streaming fails
    if (relayConnection && relayConnection.readyState === WebSocket.OPEN) {
      relayConnection.send(JSON.stringify({
        type: "api_response",
        requestId,
        data: {
          error: error instanceof Error ? error.message : String(error),
          status: 500
        }
      }));
    }
  }
}

// WebSocket-specific chat handler that streams responses in real-time
async function handleChatRequestForWebSocket(mockContext: any, requestAbortControllers: Map<string, AbortController>) {
  try {
    // Get the original HTTP streaming response
    const response = await handleChatRequest(mockContext, requestAbortControllers);
    
    // Return a special streaming response indicator
    return {
      type: "streaming_response",
      response: response,
      status: 200
    };
  } catch (error) {
    return {
      error: error instanceof Error ? error.message : String(error),
      status: 500
    };
  }
}

// Handle API requests from relay server
async function handleApiRequest(requestData: any) {
  const { method, path, headers, body } = requestData;
  
  // Create a mock Hono context for handlers
  const mockContext = createMockContext(method, path, headers, body);
  
  if (path.startsWith("/api/projects") && method === "GET") {
    if (path.includes("/histories/") && path.split("/").length === 6) {
      // /api/projects/:encodedProjectName/histories/:sessionId
      return await handleConversationRequest(mockContext);
    } else if (path.includes("/histories")) {
      // /api/projects/:encodedProjectName/histories
      return await handleHistoriesRequest(mockContext);
    } else {
      // /api/projects
      return await handleProjectsRequest(mockContext);
    }
  } else if (path.startsWith("/api/chat") && method === "POST") {
    return await handleChatRequestForWebSocket(mockContext, requestAbortControllers);
  } else if (path.startsWith("/api/abort/") && method === "POST") {
    return await handleAbortRequest(mockContext, requestAbortControllers);
  } else {
    return {
      error: "Not found",
      status: 404
    };
  }
}

// Create mock Hono context for existing handlers
function createMockContext(method: string, path: string, headers: any, body: any) {
  const pathParts = path.split("/");
  
  return {
    req: {
      method,
      path,
      headers,
      json: async () => body,
      param: (name: string) => {
        // Extract parameters from path
        if (name === "encodedProjectName" && pathParts[3]) {
          return pathParts[3];
        }
        if (name === "sessionId" && pathParts[5]) {
          return pathParts[5];
        }
        if (name === "requestId" && pathParts[3]) {
          return pathParts[3];
        }
        return undefined;
      }
    },
    json: (data: any, status = 200) => ({ data, status }),
    text: (text: string, status = 200) => ({ text, status }),
    var: {
      config: {
        debugMode: DEBUG_MODE
      }
    }
  } as any;
}

// Validate Claude CLI availability
try {
  const claudeCheck = await new Deno.Command("claude", {
    args: ["--version"],
    stdout: "piped",
    stderr: "piped",
  }).output();

  if (claudeCheck.success) {
    const version = new TextDecoder().decode(claudeCheck.stdout).trim();
    console.log(`✅ Claude CLI found: ${version}`);
  } else {
    console.warn("⚠️  Claude CLI check failed - some features may not work");
  }
} catch (_error) {
  console.warn("⚠️  Claude CLI not found - please install claude-code");
  console.warn(
    "   Visit: https://claude.ai/code for installation instructions",
  );
}

if (DEBUG_MODE) {
  console.log("🐛 Debug mode enabled");
}

console.log(`🚀 Backend starting in relay mode`);
console.log(`🔗 Relay server: ${RELAY_SERVER_URL}`);

// Connect to relay server
await connectToRelay();

// Keep the process alive and send heartbeats
setInterval(() => {
  // Send heartbeat if connected
  if (relayConnection && relayConnection.readyState === WebSocket.OPEN) {
    relayConnection.send(JSON.stringify({
      type: "heartbeat",
      timestamp: Date.now()
    }));
  }
}, 30000); // Every 30 seconds

// Keep process alive
console.log("🔄 Backend running, waiting for relay connections...");
