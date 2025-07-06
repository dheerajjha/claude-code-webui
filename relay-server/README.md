# Claude Code Relay Server

A lightweight relay server that acts as a middleware between the Claude Code Web UI backend and mobile/web clients. This allows you to host the backend on one device and access it remotely via the relay server.

## Architecture

```
Mobile/Web Clients → Relay Server (VM/Cloud) → Backend Server (Local Device)
```

The relay server proxies all API requests to the backend server, enabling remote access to Claude Code functionality.

## Features

- **HTTP API Proxy**: Forwards all REST API calls to the backend
- **Streaming Support**: Maintains streaming responses for chat functionality
- **WebSocket Ready**: Basic WebSocket support for future enhancements
- **Health Monitoring**: Built-in health check endpoint
- **Comprehensive Logging**: Detailed request/response logging to files
- **Docker Support**: Easy deployment with Docker and Docker Compose
- **CORS Enabled**: Cross-origin requests supported
- **Graceful Shutdown**: Proper cleanup on termination

## Quick Start

### Local Development

1. **Install dependencies**:
   ```bash
   cd relay-server
   npm install
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env with your backend server URL
   ```

3. **Start the server**:
   ```bash
   npm run dev
   ```

### Docker Deployment

1. **Build and run with Docker Compose**:
   ```bash
   cd relay-server
   docker-compose up -d
   ```

2. **Or build manually**:
   ```bash
   docker build -t claude-relay-server .
   docker run -p 3001:3001 -e BACKEND_URL=http://your-backend:8080 claude-relay-server
   ```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3001` | Port for the relay server |
| `BACKEND_URL` | `http://localhost:8080` | URL of the Claude Code backend server |
| `LOG_LEVEL` | `info` | Logging level (error, warn, info, debug) |
| `NODE_ENV` | `development` | Environment (affects console logging) |
| `CORS_ORIGINS` | `*` | Allowed CORS origins |

### Backend Configuration

Make sure your backend server is accessible from the relay server. Update the `BACKEND_URL` in your `.env` file:

```env
BACKEND_URL=http://192.168.1.100:8080  # Local network
# or
BACKEND_URL=https://your-backend.example.com  # Public URL
```

## API Endpoints

The relay server proxies all backend endpoints:

- `GET /health` - Health check (relay server specific)
- `GET /api/projects` - List available projects
- `POST /api/chat` - Send chat messages (streaming)
- `POST /api/abort/:requestId` - Abort chat requests
- `GET /api/projects/:projectName/histories` - Get conversation histories
- `GET /api/projects/:projectName/histories/:sessionId` - Get specific conversation

## Client Configuration

Update your frontend/mobile client to point to the relay server instead of the backend:

```javascript
// Instead of: http://localhost:8080
const API_BASE_URL = 'http://your-relay-server:3001';
```

## Deployment Examples

### VM Deployment

1. **Copy files to VM**:
   ```bash
   scp -r relay-server user@your-vm:/path/to/deployment/
   ```

2. **Install and run**:
   ```bash
   ssh user@your-vm
   cd /path/to/deployment/relay-server
   npm install --production
   BACKEND_URL=http://your-backend:8080 npm start
   ```

### Cloud Deployment

Use the provided `Dockerfile` with any cloud container service:
- Google Cloud Run
- AWS ECS/Fargate
- Azure Container Instances
- DigitalOcean App Platform

## Logging

The relay server includes comprehensive logging to track all API interactions and system events.

### Log Files

Logs are automatically written to the `logs/` directory:

- **`relay-YYYY-MM-DD.log`**: All relay operations and system events
- **`error-YYYY-MM-DD.log`**: Error-level logs only
- **Log Rotation**: Files are rotated daily and compressed after 14 days

### Log Types

The logging system tracks different types of events:

```json
// Server startup
{"timestamp":"2025-07-06 21:43:37","level":"info","message":"Relay server started","type":"server_start","port":3001,"backendUrl":"http://localhost:8080"}

// HTTP access logs
{"timestamp":"2025-07-06 21:45:56","level":"info","message":"::1 - - [06/Jul/2025:16:15:56 +0000] \"GET /health HTTP/1.1\" 200 54","type":"http_access"}

// API request proxy
{"timestamp":"2025-07-06 21:46:14","level":"info","message":"Relay Request","type":"relay_request","method":"GET","originalUrl":"/api/projects","targetUrl":"http://localhost:8080/api/projects","userAgent":"curl/8.7.1","ip":"::1"}

// API response
{"timestamp":"2025-07-06 21:46:14","level":"info","message":"Relay Response Success","type":"relay_response","method":"GET","originalUrl":"/api/projects","statusCode":200,"duration":"32ms","ip":"::1"}

// Streaming data
{"timestamp":"2025-07-06 21:46:14","level":"info","message":"Relay Stream Complete","type":"relay_stream","method":"POST","originalUrl":"/api/chat","chunkCount":15,"totalBytes":4562,"ip":"::1"}

// WebSocket events
{"timestamp":"2025-07-06 21:46:14","level":"info","message":"WebSocket Event","type":"websocket","connectionId":"abc123","event":"connected","ip":"::1"}
```

### Log Configuration

Control logging behavior with environment variables:

```bash
# Set log level (error, warn, info, debug)
LOG_LEVEL=debug

# Disable console logging in production
NODE_ENV=production
```

### Viewing Logs

```bash
# View today's relay logs
tail -f logs/relay-$(date +%Y-%m-%d).log

# View errors only
tail -f logs/error-$(date +%Y-%m-%d).log

# Filter by request type
grep "relay_request" logs/relay-$(date +%Y-%m-%d).log

# View streaming activity
grep "relay_stream" logs/relay-$(date +%Y-%m-%d).log
```

## Monitoring

### Health Check

```bash
curl http://localhost:3001/health
```

Response:
```json
{
  "status": "ok",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

### Docker Health Check

The Docker container includes automatic health monitoring:
```bash
docker ps  # Check health status
```

## Security Considerations

- **Network Security**: Use HTTPS in production
- **Firewall**: Restrict access to necessary ports only
- **Authentication**: Consider adding authentication middleware if needed
- **CORS**: Configure specific origins instead of `*` in production

## Troubleshooting

### Common Issues

1. **Connection refused**: Check if backend server is running and accessible
2. **CORS errors**: Verify CORS_ORIGINS configuration
3. **Streaming issues**: Ensure backend streaming is working correctly

### Debug Mode

Enable debug logging:
```bash
DEBUG=true npm start
```

### Logs

Check logs for connection issues:
```bash
# Docker logs
docker-compose logs relay-server

# Direct logs
npm start
```

## Development

### Adding New Endpoints

To proxy a new backend endpoint:

```javascript
app.get('/api/new-endpoint', async (req, res) => {
  try {
    const response = await axios.get(`${BACKEND_URL}/api/new-endpoint`);
    res.json(response.data);
  } catch (error) {
    console.error('Error proxying request:', error.message);
    res.status(500).json({ error: 'Proxy error' });
  }
});
```

### WebSocket Enhancement

The server includes basic WebSocket support for future real-time features. Currently, it only handles connection management.

## License

Same as the main Claude Code Web UI project.