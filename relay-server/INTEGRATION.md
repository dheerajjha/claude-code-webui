# Frontend-Relay Server Integration Guide

This guide explains how to configure the frontend to work with the relay server for remote backend access.

## Architecture Overview

```
Frontend (Web) → Relay Server (VM/Cloud) → Backend (Local Device)
```

The relay server acts as a transparent proxy, allowing the frontend to access the backend remotely without modifying the API contract.

## Quick Setup

### 1. Start the Relay Server

```bash
cd relay-server
npm install
BACKEND_URL=http://your-backend-server:8080 npm start
```

### 2. Configure Frontend for Relay Mode

**Option A: Environment File**
```bash
cd frontend
cp .env.relay .env.local
# Edit .env.local to set your relay server URL
```

**Option B: Development Script**
```bash
cd frontend
npm run dev:relay
```

**Option C: Manual Environment Variables**
```bash
cd frontend
VITE_USE_RELAY_SERVER=true VITE_RELAY_SERVER_URL=http://your-relay-server:3001 npm run dev
```

## Configuration Options

### Frontend Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VITE_USE_RELAY_SERVER` | `false` | Enable relay server mode |
| `VITE_RELAY_SERVER_URL` | `http://localhost:3001` | Relay server URL |

### Example Configurations

**Local Development**
```env
VITE_USE_RELAY_SERVER=true
VITE_RELAY_SERVER_URL=http://localhost:3001
```

**Remote Relay Server**
```env
VITE_USE_RELAY_SERVER=true
VITE_RELAY_SERVER_URL=https://your-relay-server.example.com
```

**Production with HTTPS**
```env
VITE_USE_RELAY_SERVER=true
VITE_RELAY_SERVER_URL=https://relay.yourdomain.com
```

## How It Works

### Direct Mode (Default)
```
Frontend ←→ Vite Proxy ←→ Backend (localhost:8080)
```

### Relay Mode
```
Frontend ←→ Relay Server ←→ Backend (remote)
```

### API URL Resolution

The frontend automatically routes API calls based on configuration:

```typescript
// Direct mode: /api/chat → http://localhost:8080/api/chat (via proxy)
// Relay mode: /api/chat → http://relay-server:3001/api/chat
```

## Testing the Setup

### 1. Verify Relay Server Health

```bash
curl http://localhost:3001/health
# Expected: {"status":"ok","timestamp":"..."}
```

### 2. Test API Proxying

```bash
# Test projects endpoint through relay
curl http://localhost:3001/api/projects

# Test chat endpoint through relay (replace with actual backend URL)
curl -X POST http://localhost:3001/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"test","requestId":"test-123"}'
```

### 3. Frontend Development

```bash
# Terminal 1: Start backend
cd backend && deno task dev

# Terminal 2: Start relay server
cd relay-server && BACKEND_URL=http://localhost:8080 npm start

# Terminal 3: Start frontend in relay mode
cd frontend && npm run dev:relay
```

## Deployment Scenarios

### Scenario 1: Local Development
- Backend: `localhost:8080`
- Relay: `localhost:3001`
- Frontend: `localhost:3000` (relay mode)

### Scenario 2: Remote Backend Access
- Backend: `192.168.1.100:8080` (local network)
- Relay: `your-vm.example.com:3001` (cloud VM)
- Frontend: `localhost:3000` (relay mode)

### Scenario 3: Full Production
- Backend: `backend.internal:8080` (private network)
- Relay: `relay.yourdomain.com` (public with HTTPS)
- Frontend: `app.yourdomain.com` (production build)

## Troubleshooting

### Common Issues

1. **CORS Errors**
   - Ensure relay server has CORS enabled
   - Check browser console for specific CORS messages

2. **Connection Refused**
   - Verify backend server is running and accessible from relay server
   - Check `BACKEND_URL` configuration in relay server

3. **API Endpoints Not Found**
   - Verify relay server is properly proxying all endpoints
   - Check relay server logs for error messages

4. **Environment Variables Not Loading**
   - Ensure `.env.local` exists and contains correct variables
   - Restart Vite dev server after changing environment variables

### Debug Commands

```bash
# Check frontend configuration
cd frontend && npm run dev # Check console logs for API base URL

# Check relay server status
curl http://relay-server:3001/health

# Test direct backend connection
curl http://backend-server:8080/api/projects

# Test relay server proxy
curl http://relay-server:3001/api/projects
```

## Security Considerations

1. **Network Security**: Use HTTPS in production
2. **Firewall Rules**: Restrict relay server access to necessary IPs
3. **Authentication**: Consider adding authentication to relay server
4. **Rate Limiting**: Implement rate limiting for production use

## Performance Notes

1. **Latency**: Additional network hop adds latency
2. **Bandwidth**: All traffic routes through relay server
3. **Caching**: Consider adding caching layer for static responses
4. **Load Balancing**: Use multiple relay servers for high availability