# Go SSE Server

A simple HTTP server written in Go that provides Server-Sent Events (SSE) streaming with heartbeats, similar to the Rails server.

## 🚀 Features

- **SSE Stream Endpoint**: `/dashboard/stream` - Provides real-time dashboard data
- **Heartbeats**: Sends heartbeats every 30 seconds to keep connections alive
- **Connection Management**: Tracks and manages multiple SSE connections
- **Test Endpoints**: Debug and trigger endpoints for testing
- **Health Check**: `/health` endpoint for monitoring

## 📋 Requirements

- Go 1.21 or later

## 🔧 Building

```bash
# Build the server
./build.sh

# Or manually
go build -o sse-server main.go
```

## 🚀 Running

```bash
# Run the server
./sse-server
```

The server will start on port 3001 (different from the Rails server on 3000).

## 📡 Endpoints

### SSE Stream
- **URL**: `http://localhost:3001/dashboard/stream`
- **Method**: GET
- **Headers**: 
  - `Accept: text/event-stream`
  - `Cache-Control: no-cache`
- **Description**: Provides real-time dashboard data with heartbeats

### Debug
- **URL**: `http://localhost:3001/dashboard/debug`
- **Method**: GET
- **Description**: Returns server status information

### Test Trigger
- **URL**: `http://localhost:3001/dashboard/trigger-test`
- **Method**: GET
- **Description**: Triggers a test broadcast to all connected clients

### Health Check
- **URL**: `http://localhost:3001/health`
- **Method**: GET
- **Description**: Returns "OK" for health monitoring

## 🧪 Testing

### Automated Test
```bash
# Run the full test suite
./test.sh
```

### Manual Testing
```bash
# Test with curl
curl -N -H "Accept: text/event-stream" http://localhost:3001/dashboard/stream

# Test with Go client
cd ../goclient
./sse-client -url "http://localhost:3001/dashboard/stream" -clients 1 -debug
```

## 📊 Data Format

The server sends dashboard data in the following JSON format:

```json
{
  "system_status": {
    "status": "online",
    "uptime": "2 days, 14 hours",
    "last_check": "15:04:05",
    "message": "System running normally"
  },
  "metrics": {
    "cpu": "45%",
    "memory": "67%",
    "disk": "23%",
    "network": "125 Mbps",
    "response_time": "87ms"
  },
  "activities": [
    {
      "time": "15:04:05",
      "message": "Dashboard updated",
      "level": "info",
      "css_class": "activity-info"
    }
  ],
  "timestamp": "15:04:05"
}
```

## 💓 Heartbeats

The server sends heartbeats every 30 seconds in the format:
```
: heartbeat
```

## 🔍 Logging

The server provides detailed logging:
- Connection establishment/removal
- Heartbeat sending
- Broadcast events
- Error handling

## 🏗️ Architecture

- **SSEServer**: Main server struct managing connections
- **SSEConnection**: Individual connection handler
- **Connection Pool**: Thread-safe connection management
- **Heartbeat Loop**: Background goroutine for heartbeats

## 🔄 Comparison with Rails Server

| Feature | Go Server | Rails Server |
|---------|-----------|--------------|
| **Port** | 3001 | 3000 |
| **Heartbeats** | ✅ 30s | ✅ 30s |
| **Connection Management** | ✅ | ✅ |
| **Data Format** | ✅ Compatible | ✅ Compatible |
| **Performance** | ⚡ High | 🐌 Moderate |
| **Memory Usage** | 💾 Low | 💾 Higher |
| **Dependencies** | 🚀 None | 📦 Rails stack |

## 🚨 Troubleshooting

### Server won't start
- Check if port 3001 is available
- Ensure Go 1.21+ is installed
- Check build errors

### No heartbeats received
- Verify client is connecting to correct port (3001)
- Check server logs for connection errors
- Ensure client supports SSE format

### Connection issues
- Check firewall settings
- Verify network connectivity
- Review server logs for errors
