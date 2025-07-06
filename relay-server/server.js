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

// Configuration
const PORT = process.env.PORT || 3001;
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8080';

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
  const startTime = Date.now();
  const targetUrl = `${BACKEND_URL}/api/projects`;
  
  logger.relayRequest(req, targetUrl);
  
  try {
    const response = await axios.get(targetUrl);
    const duration = Date.now() - startTime;
    
    logger.relayResponse(req, response, duration);
    res.json(response.data);
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.relayResponse(req, null, duration, error);
    res.status(500).json({ error: 'Failed to fetch projects from backend' });
  }
});

// Proxy endpoint for chat API (streaming)
app.post('/api/chat', async (req, res) => {
  const startTime = Date.now();
  const targetUrl = `${BACKEND_URL}/api/chat`;
  let chunkCount = 0;
  let totalBytes = 0;
  
  logger.relayRequest(req, targetUrl);
  
  try {
    const response = await axios.post(targetUrl, req.body, {
      responseType: 'stream',
      headers: {
        'Content-Type': 'application/json'
      }
    });

    // Set headers for streaming response
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.setHeader('Transfer-Encoding', 'chunked');

    // Track streaming data
    response.data.on('data', (chunk) => {
      chunkCount++;
      totalBytes += chunk.length;
    });

    response.data.on('end', () => {
      const duration = Date.now() - startTime;
      logger.relayResponse(req, response, duration);
      logger.relayStream(req, chunkCount, totalBytes);
    });

    response.data.on('error', (error) => {
      const duration = Date.now() - startTime;
      logger.relayResponse(req, null, duration, error);
    });

    // Pipe the stream from backend to client
    response.data.pipe(res);
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.relayResponse(req, null, duration, error);
    res.status(500).json({ error: 'Failed to process chat request' });
  }
});

// Proxy endpoint for abort requests
app.post('/api/abort/:requestId', async (req, res) => {
  const startTime = Date.now();
  const { requestId } = req.params;
  const targetUrl = `${BACKEND_URL}/api/abort/${requestId}`;
  
  logger.relayRequest(req, targetUrl);
  
  try {
    const response = await axios.post(targetUrl);
    const duration = Date.now() - startTime;
    
    logger.relayResponse(req, response, duration);
    res.json(response.data);
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.relayResponse(req, null, duration, error);
    res.status(500).json({ error: 'Failed to abort request' });
  }
});

// Proxy endpoint for conversation histories
app.get('/api/projects/:encodedProjectName/histories', async (req, res) => {
  const startTime = Date.now();
  const { encodedProjectName } = req.params;
  const targetUrl = `${BACKEND_URL}/api/projects/${encodedProjectName}/histories`;
  
  logger.relayRequest(req, targetUrl);
  
  try {
    const response = await axios.get(targetUrl);
    const duration = Date.now() - startTime;
    
    logger.relayResponse(req, response, duration);
    res.json(response.data);
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.relayResponse(req, null, duration, error);
    res.status(500).json({ error: 'Failed to fetch conversation histories' });
  }
});

// Proxy endpoint for specific conversation history
app.get('/api/projects/:encodedProjectName/histories/:sessionId', async (req, res) => {
  const startTime = Date.now();
  const { encodedProjectName, sessionId } = req.params;
  const targetUrl = `${BACKEND_URL}/api/projects/${encodedProjectName}/histories/${sessionId}`;
  
  logger.relayRequest(req, targetUrl);
  
  try {
    const response = await axios.get(targetUrl);
    const duration = Date.now() - startTime;
    
    logger.relayResponse(req, response, duration);
    res.json(response.data);
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.relayResponse(req, null, duration, error);
    res.status(500).json({ error: 'Failed to fetch conversation history' });
  }
});

// WebSocket connection handling
wss.on('connection', (ws, req) => {
  const connectionId = Date.now().toString(36) + Math.random().toString(36).substr(2);
  
  logger.websocketConnection(connectionId, 'connected', {
    ip: req.socket.remoteAddress,
    userAgent: req.headers['user-agent']
  });

  ws.on('message', async (message) => {
    try {
      const data = JSON.parse(message);
      
      logger.websocketConnection(connectionId, 'message_received', {
        messageType: data.type,
        dataLength: message.length
      });
      
      if (data.type === 'chat') {
        // Forward chat requests to backend via HTTP streaming
        // This could be enhanced to use WebSocket to backend if available
        logger.websocketConnection(connectionId, 'chat_request', { message: 'HTTP fallback used' });
        ws.send(JSON.stringify({ 
          type: 'info', 
          message: 'Chat via WebSocket not yet implemented. Use HTTP API instead.' 
        }));
      }
    } catch (error) {
      logger.websocketConnection(connectionId, 'message_error', {
        error: error.message,
        rawMessage: message.toString()
      });
      ws.send(JSON.stringify({ type: 'error', message: 'Invalid message format' }));
    }
  });

  ws.on('close', () => {
    logger.websocketConnection(connectionId, 'disconnected');
  });

  ws.on('error', (error) => {
    logger.websocketConnection(connectionId, 'error', { error: error.message });
  });

  // Send welcome message
  ws.send(JSON.stringify({ 
    type: 'welcome', 
    message: 'Connected to Claude Code Relay Server',
    connectionId: connectionId
  }));
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
    healthCheck: `http://localhost:${PORT}/health`,
    logLevel: process.env.LOG_LEVEL || 'info',
    nodeEnv: process.env.NODE_ENV || 'development'
  });
  
  console.log(`Relay server running on port ${PORT}`);
  console.log(`Backend URL: ${BACKEND_URL}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
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