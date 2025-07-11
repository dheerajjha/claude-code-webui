const express = require('express');
const WebSocket = require('ws');
const cors = require('cors');
const axios = require('axios');
const http = require('http');
const morgan = require('morgan');
const logger = require('./logger');
require('dotenv').config();

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Configuration - hardcoded for 98.70.88.219
const PORT = process.env.PORT || 3001;
const BACKEND_URL = 'http://98.70.88.219:8080';

// Store connected backends
const connectedBackends = new Map();
let requestCounter = 0;

// Middleware
app.use(cors());
app.use(express.json());

// HTTP request logging with Morgan
app.use(morgan('combined', {
  stream: {
    write: (message) => logger.info(message.trim(), { type: 'http_access' })
  }
}));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Proxy endpoint for projects API
app.get('/api/projects', async (req, res) => {
  logger.relayRequest(req, '/api/projects');
  sendRequestToBackend('GET', '/api/projects', req.headers, null, res);
});

// Proxy endpoint for chat API (streaming)
app.post('/api/chat', async (req, res) => {
  logger.relayRequest(req, '/api/chat');
  sendRequestToBackend('POST', '/api/chat', req.headers, req.body, res);
});

// Proxy endpoint for abort requests
app.post('/api/abort/:requestId', async (req, res) => {
  const { requestId } = req.params;
  logger.relayRequest(req, `/api/abort/${requestId}`);
  sendRequestToBackend('POST', `/api/abort/${requestId}`, req.headers, req.body, res);
});

// Proxy endpoint for conversation histories
app.get('/api/projects/:encodedProjectName/histories', async (req, res) => {
  const { encodedProjectName } = req.params;
  logger.relayRequest(req, `/api/projects/${encodedProjectName}/histories`);
  sendRequestToBackend('GET', `/api/projects/${encodedProjectName}/histories`, req.headers, null, res);
});

// Proxy endpoint for specific conversation history
app.get('/api/projects/:encodedProjectName/histories/:sessionId', async (req, res) => {
  const { encodedProjectName, sessionId } = req.params;
  logger.relayRequest(req, `/api/projects/${encodedProjectName}/histories/${sessionId}`);
  sendRequestToBackend('GET', `/api/projects/${encodedProjectName}/histories/${sessionId}`, req.headers, null, res);
});

// Store pending requests waiting for backend responses
const pendingRequests = new Map();

// Store streaming responses in progress
const streamingResponses = new Map();

// Handle start of streaming response
function handleStreamingStart(data) {
  const { requestId } = data;
  
  if (pendingRequests.has(requestId)) {
    const { res, startTime, timeout } = pendingRequests.get(requestId);
    
    // Clear timeout
    if (timeout) {
      clearTimeout(timeout);
    }
    
    // Set headers for streaming response
    res.setHeader('Content-Type', 'application/x-ndjson');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    
    // Store streaming context
    streamingResponses.set(requestId, {
      res,
      startTime,
      chunks: []
    });
    
    logger.info('Streaming started', {
      type: 'streaming_start',
      requestId,
      timestamp: new Date().toISOString()
    });
  }
}

// Handle streaming chunk
function handleStreamingChunk(data) {
  const { requestId, data: chunk } = data;
  
  if (streamingResponses.has(requestId)) {
    const { res, chunks } = streamingResponses.get(requestId);
    
    try {
      // Check if response is still writable
      if (!res.writableEnded && !res.destroyed) {
        // Send chunk immediately to client
        res.write(chunk);
        chunks.push(chunk);
        
        console.log(`[DEBUG] Sent chunk ${chunks.length} for request ${requestId}`);
      } else {
        console.warn(`[WARN] Response no longer writable for request ${requestId}`);
      }
    } catch (error) {
      console.error(`[ERROR] Failed to write chunk for request ${requestId}:`, error);
      
      // Clean up on error
      streamingResponses.delete(requestId);
      pendingRequests.delete(requestId);
    }
  } else {
    console.warn(`[WARN] Received chunk for unknown streaming request: ${requestId}`);
  }
}

// Handle end of streaming response
function handleStreamingEnd(data) {
  const { requestId } = data;
  
  if (streamingResponses.has(requestId)) {
    const { res, startTime, chunks } = streamingResponses.get(requestId);
    const duration = Date.now() - startTime;
    
    // End the response
    if (!res.writableEnded) {
      res.end();
    }
    
    // Clean up
    if (pendingRequests.has(requestId)) {
      const { timeout } = pendingRequests.get(requestId);
      if (timeout) {
        clearTimeout(timeout);
      }
    }
    
    pendingRequests.delete(requestId);
    streamingResponses.delete(requestId);
    
    logger.info('Streaming completed', {
      type: 'streaming_complete',
      requestId,
      duration: `${duration}ms`,
      totalChunks: chunks.length,
      timestamp: new Date().toISOString()
    });
  }
}

// Handle responses from backends
function handleBackendResponse(data) {
  const { requestId, data: responseData } = data;
  
  if (pendingRequests.has(requestId)) {
    const { res, startTime, timeout } = pendingRequests.get(requestId);
    pendingRequests.delete(requestId);
    
    // Clear timeout
    if (timeout) {
      clearTimeout(timeout);
    }
    
    const duration = Date.now() - startTime;
    
    if (responseData.error) {
      logger.error('Backend Response Error', {
        type: 'backend_response_error',
        requestId,
        error: responseData.error,
        status: responseData.status || 500,
        duration: `${duration}ms`,
        timestamp: new Date().toISOString()
      });
      
      res.status(responseData.status || 500).json({ error: responseData.error });
    } else {
      logger.info('Backend Response Success', {
        type: 'backend_response_success',
        requestId,
        status: responseData.status || 200,
        duration: `${duration}ms`,
        timestamp: new Date().toISOString()
      });
      
      res.status(responseData.status || 200).json(responseData.data || responseData);
    }
  } else {
    console.warn('Received response for unknown request:', requestId);
  }
}

// Send request to connected backend via WebSocket
function sendRequestToBackend(method, path, headers, body, res) {
  const backends = Array.from(connectedBackends.values());
  
  if (backends.length === 0) {
    logger.error('No backends available', {
      type: 'no_backend_available',
      timestamp: new Date().toISOString()
    });
    return res.status(503).json({ error: 'No backend servers available' });
  }
  
  // Use first available backend (could implement load balancing here)
  const backend = backends[0];
  const requestId = `req_${++requestCounter}_${Date.now()}`;
  
  // Store the pending request with timeout
  const timeout = setTimeout(() => {
    if (pendingRequests.has(requestId)) {
      console.error(`[ERROR] Request timeout for ${requestId}`);
      
      pendingRequests.delete(requestId);
      if (streamingResponses.has(requestId)) {
        streamingResponses.delete(requestId);
      }
      
      if (!res.writableEnded) {
        res.status(504).json({ error: 'Request timeout' });
      }
    }
  }, 120000); // 2 minute timeout
  
  pendingRequests.set(requestId, {
    res,
    startTime: Date.now(),
    timeout
  });
  
  // Send request to backend
  const message = {
    type: 'api_request',
    requestId,
    data: {
      method,
      path,
      headers,
      body
    }
  };
  
  backend.ws.send(JSON.stringify(message));
  
  logger.info('Request sent to backend', {
    type: 'request_to_backend',
    requestId,
    method,
    path,
    timestamp: new Date().toISOString()
  });
}

// WebSocket connection handling for backend connections
wss.on('connection', (ws, req) => {
  console.log('WebSocket connection established');
  let backendId = null;
  
  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message.toString());
      
      switch (data.type) {
        case 'backend_register':
          backendId = data.data.backendId;
          connectedBackends.set(backendId, {
            ws: ws,
            capabilities: data.data.capabilities,
            version: data.data.version,
            connectedAt: new Date()
          });
          
          logger.info('Backend registered', {
            type: 'backend_register',
            backendId,
            capabilities: data.data.capabilities,
            version: data.data.version,
            timestamp: new Date().toISOString()
          });
          
          console.log(`✅ Backend registered: ${backendId}`);
          console.log(`📊 Connected backends: ${connectedBackends.size}`);
          break;
          
        case 'api_response':
          // Handle response from backend
          handleBackendResponse(data);
          break;
          
        case 'streaming_start':
          // Handle start of streaming response
          handleStreamingStart(data);
          break;
          
        case 'streaming_chunk':
          // Handle streaming chunk
          handleStreamingChunk(data);
          break;
          
        case 'streaming_end':
          // Handle end of streaming response
          handleStreamingEnd(data);
          break;
          
        case 'heartbeat':
          // Respond to heartbeat
          ws.send(JSON.stringify({ type: 'heartbeat_ack', timestamp: Date.now() }));
          break;
          
        default:
          console.warn('Unknown WebSocket message type:', data.type);
      }
    } catch (error) {
      console.error('Error parsing WebSocket message:', error);
    }
  });
  
  ws.on('close', () => {
    if (backendId) {
      connectedBackends.delete(backendId);
      console.log(`❌ Backend disconnected: ${backendId}`);
      console.log(`📊 Connected backends: ${connectedBackends.size}`);
      
      logger.info('Backend disconnected', {
        type: 'backend_disconnect',
        backendId,
        timestamp: new Date().toISOString()
      });
    }
  });
  
  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Server error', {
    type: 'server_error',
    error: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    ip: req.ip
  });
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
server.listen(PORT, () => {
  logger.info('Relay server started', {
    type: 'server_start',
    port: PORT,
    backendUrl: BACKEND_URL,
    healthCheck: `http://98.70.88.219:${PORT}/health`,
    logLevel: process.env.LOG_LEVEL || 'info',
    nodeEnv: process.env.NODE_ENV || 'development'
  });
  
  console.log(`Relay server running on port ${PORT}`);
  console.log(`Backend URL: ${BACKEND_URL}`);
  console.log(`Health check: http://98.70.88.219:${PORT}/health`);
  console.log(`Logs directory: ./logs/`);
});

// Graceful shutdown
const gracefulShutdown = (signal) => {
  logger.info('Graceful shutdown initiated', {
    type: 'server_shutdown',
    signal: signal,
    uptime: process.uptime()
  });
  
  console.log(`Received ${signal}, shutting down gracefully...`);
  server.close(() => {
    logger.info('Server shutdown complete', { type: 'server_shutdown_complete' });
    console.log('Server closed');
    process.exit(0);
  });
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));