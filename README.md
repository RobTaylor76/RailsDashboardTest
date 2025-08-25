# Dashboard Real-Time System

A comprehensive real-time dashboard system with multiple implementations for Server-Sent Events (SSE), featuring a Rails server, Go server, and Go client for testing and comparison.

## 🏗️ Architecture Overview

This system demonstrates different approaches to real-time data streaming:

- **Rails Server**: Traditional web application with SSE streaming
- **Go Server**: High-performance SSE server for scalability
- **Go Client**: Test client for load testing and validation
- **Redis**: Message broker for real-time data distribution

## 🚀 Components

### 1. Rails Server (`/app`)

**Capabilities:**
- **SSE Streaming**: Real-time data streaming using `ActionController::Live`
- **Redis Pub/Sub**: Real-time message distribution via Redis
- **Database Polling**: Fallback to database polling when Redis unavailable
- **Background Jobs**: ActiveJob integration for async processing
- **Connection Management**: Proper Redis connection pooling and cleanup
- **Heartbeat Support**: 30-second heartbeats to maintain connections
- **Error Handling**: Graceful handling of client disconnections

**Key Features:**
- RESTful API endpoints for dashboard data
- Real-time updates via Redis pub/sub
- Connection leak prevention
- Comprehensive logging and monitoring
- Health check endpoints

**Limitations:**
- Thread-limited (typically 100-500 concurrent connections)
- Higher memory usage per connection (~1-2MB)
- Requires sticky sessions for load balancing

### 2. Go Server (`/goserver`)

**Capabilities:**
- **High-Performance SSE**: Native Go HTTP server with goroutines
- **Unlimited Concurrency**: Can handle thousands of concurrent connections
- **Redis Pub/Sub**: Efficient Redis integration with one connection per client
- **Lightweight**: ~2KB memory per connection vs Rails' ~1-2MB
- **Stateless**: No sticky session requirements
- **Heartbeat Support**: 30-second heartbeats
- **Connection Management**: Automatic cleanup and resource management

**Key Features:**
- `/dashboard/stream` - SSE endpoint
- `/dashboard/debug` - Debug information
- `/health` - Health check
- Configurable port via environment variable
- Comprehensive logging

**Advantages:**
- Scales to 10,000+ concurrent connections
- Low memory footprint
- High performance
- Easy horizontal scaling
- No framework overhead

### 3. Go Client (`/goclient`)

**Capabilities:**
- **Load Testing**: Test multiple concurrent SSE connections
- **Performance Monitoring**: Real-time statistics and metrics
- **Flexible Configuration**: Configurable number of clients, URLs, and ports
- **Heartbeat Detection**: Monitors and logs heartbeat messages
- **Error Handling**: Comprehensive error reporting
- **Debug Mode**: Verbose logging for troubleshooting

**Key Features:**
- Single client testing
- Multiple client testing (configurable count)
- Load testing with statistics
- Custom URL testing
- Port configuration
- Real-time connection monitoring
- Heartbeat tracking

**Usage Scenarios:**
- Performance testing of SSE servers
- Load testing for capacity planning
- Debugging connection issues
- Comparing Rails vs Go server performance

## 🔧 Quick Start

### Prerequisites
- Ruby 3.3.9+
- Go 1.21+
- Redis (Docker recommended)
- Docker (optional)

### 1. Start Redis
```bash
docker run -d --name redis-dashboard -p 6379:6379 redis:7-alpine
```

### 2. Start Rails Server
```bash
cd dashboard
bundle install
rails server
# Server runs on http://localhost:3000
```

### 3. Start Go Server (Optional)
```bash
cd dashboard/goserver
./run.sh 3001
# Server runs on http://localhost:3001
```

### 4. Test with Go Client
```bash
cd dashboard/goclient
./test.sh
# Follow prompts to select test scenario and port
```

## 📊 Performance Comparison

| Aspect | Rails Server | Go Server |
|--------|-------------|-----------|
| **Max Connections** | ~100-500 | 10,000+ |
| **Memory per Connection** | ~1-2MB | ~2KB |
| **CPU Usage** | High | Low |
| **Horizontal Scaling** | Difficult | Easy |
| **Setup Complexity** | Simple | Simple |
| **Production Ready** | Yes (with tuning) | Yes |

## 🧪 Testing

### Load Testing
```bash
# Test Rails server (port 3000)
cd dashboard/goclient
./test.sh
# Select option 3 (Load test) and enter port 3000

# Test Go server (port 3001)
cd dashboard/goclient
./test.sh
# Select option 3 (Load test) and enter port 3001
```

### Custom Testing
```bash
# Test specific URL with custom parameters
cd dashboard/goclient
./test.sh
# Select option 4 (Custom URL test)
# Enter URL, number of clients, and enable stats
```

## 🔍 Monitoring

### Redis Connections
```bash
# Monitor Redis connections
docker exec redis-dashboard redis-cli client list

# Count active connections
docker exec redis-dashboard redis-cli client list | grep -c "flags=P"
```

### Server Logs
```bash
# Rails server logs
tail -f dashboard/log/development.log

# Go server logs (if running in foreground)
# Check terminal where Go server is running
```

## 📁 Project Structure

```
dashboard/
├── app/                    # Rails application
│   ├── controllers/       # Dashboard controller with SSE
│   ├── jobs/             # Background jobs
│   └── models/           # Data models
├── lib/services/         # Redis and pub/sub services
├── goserver/             # Go SSE server
│   ├── main.go          # Server implementation
│   ├── run.sh           # Server startup script
│   └── README.md        # Go server documentation
├── goclient/             # Go SSE client
│   ├── main.go          # Client implementation
│   ├── test.sh          # Test script
│   └── README.md        # Client documentation
├── scripts/              # Utility scripts
└── README_SSE_COMPARISON.md  # Detailed comparison
```

## 🚀 Deployment

### Rails Server
- Standard Rails deployment (Heroku, AWS, etc.)
- Configure Redis connection
- Set appropriate thread pool size
- Use sticky sessions for load balancing

### Go Server
- Deploy as standalone binary
- Use process manager (systemd, supervisor)
- Load balance across multiple instances
- No sticky sessions required

## 📚 Documentation

- [SSE Implementation Comparison](README_SSE_COMPARISON.md) - Detailed Rails vs Go comparison
- [Go Server Documentation](goserver/README.md) - Go server specific docs
- [Go Client Documentation](goclient/README.md) - Client testing guide

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with both Rails and Go servers
5. Submit a pull request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
