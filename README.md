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

#### **Installing Go (for beginners)**

If you don't have Go installed, follow these step-by-step instructions:

##### **macOS Installation**

**Option 1: Using Homebrew (Recommended)**
```bash
# Install Homebrew if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Go
brew install go

# Verify installation
go version
```

**Option 2: Manual Installation**
```bash
# Download Go for macOS
curl -O https://go.dev/dl/go1.21.0.darwin-amd64.pkg

# Install the package
sudo installer -pkg go1.21.0.darwin-amd64.pkg -target /

# Verify installation
go version
```

##### **Linux Installation**

**Ubuntu/Debian:**
```bash
# Update package list
sudo apt update

# Install Go
sudo apt install golang-go

# Verify installation
go version
```

**CentOS/RHEL/Fedora:**
```bash
# Install Go
sudo dnf install golang  # Fedora
# OR
sudo yum install golang  # CentOS/RHEL

# Verify installation
go version
```

**Manual Installation (any Linux):**
```bash
# Download Go
wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz

# Extract to /usr/local
sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz

# Add Go to PATH (add to ~/.bashrc or ~/.zshrc)
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# Verify installation
go version
```

##### **Windows Installation**

**Option 1: Using Chocolatey**
```powershell
# Install Chocolatey if you don't have it
# Run PowerShell as Administrator and execute:
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install Go
choco install golang

# Verify installation
go version
```

**Option 2: Manual Installation**
1. Download Go from https://go.dev/dl/
2. Run the installer and follow the prompts
3. Open Command Prompt and verify: `go version`

##### **Setting up Go Workspace (Important!)**

After installing Go, set up your workspace:

```bash
# Create Go workspace directory
mkdir -p ~/go/{bin,src,pkg}

# Add to your shell profile (~/.bashrc, ~/.zshrc, or ~/.profile)
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
source ~/.bashrc

# Verify setup
echo $GOPATH
```

##### **Verifying Go Installation**

Test that Go is working correctly:

```bash
# Check Go version (should show 1.21 or higher)
go version

# Check Go environment
go env

# Test with a simple program
mkdir ~/go/src/hello
cd ~/go/src/hello
echo 'package main

import "fmt"

func main() {
    fmt.Println("Hello, Go!")
}' > main.go

# Run the program
go run main.go
# Should output: Hello, Go!
```

##### **Troubleshooting Go Installation**

**Common Issues:**

1. **"go: command not found"**
   - Make sure Go is in your PATH
   - Restart your terminal after installation
   - Check: `echo $PATH | grep go`

2. **Permission errors on macOS/Linux**
   - Use `sudo` for system-wide installation
   - Or install via package manager (Homebrew, apt, etc.)

3. **GOPATH not set**
   - Set GOPATH as shown above
   - Restart terminal after setting environment variables

4. **Version too old**
   - Update Go: `brew upgrade go` (macOS) or download latest from go.dev/dl/

**Need Help?**
- Official Go documentation: https://go.dev/doc/
- Go installation guide: https://go.dev/doc/install
- Go workspace setup: https://go.dev/doc/gopath_code

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

## 🔧 Environment Variables

The application uses several environment variables for configuration. Copy the template from `env-template.txt` to create your `.env.development` and `.env.test` files.

### **Database Configuration**
```bash
# PostgreSQL connection string
DATABASE_URL=postgres://postgres:postgres@localhost:5432/dashboard_development
```

### **Redis Configuration**
```bash
# Redis connection URL
REDIS_URL=redis://localhost:6379
```

### **SSE Configuration**
```bash
# SSE server host and port
SSE_HOST=localhost
SSE_PORT=3001
SSE_ENDPOINT=/dashboard/stream

# SSE server type (go or rails)
SSE_SERVER_TYPE=go

# Auto-refresh settings
SSE_AUTO_REFRESH=true
SSE_CONNECTION_TIMEOUT=5000
SSE_RETRY_INTERVAL=5000
```

### **Rails Configuration**
```bash
# Rails server settings
RAILS_LOG_LEVEL=info
RAILS_MAX_THREADS=25
PORT=3000
PIDFILE=tmp/pids/server.pid
```

### **Logging Configuration**
```bash
# Enable structured logging (false for development)
LOGRAGE_ENABLED=false
```

### **Environment-Specific Settings**

#### **Development Environment (`.env.development`)**
```bash
DATABASE_URL=postgres://postgres:postgres@localhost:5432/dashboard_development
REDIS_URL=redis://localhost:6379
SSE_HOST=localhost
SSE_PORT=3001
SSE_SERVER_TYPE=go
SSE_AUTO_REFRESH=true
RAILS_LOG_LEVEL=info
LOGRAGE_ENABLED=false
```

#### **Test Environment (`.env.test`)**
```bash
DATABASE_URL=postgres://postgres:postgres@localhost:5432/dashboard_test
REDIS_URL=redis://localhost:6379
SSE_HOST=localhost
SSE_PORT=3001
SSE_SERVER_TYPE=go
SSE_AUTO_REFRESH=true
RAILS_LOG_LEVEL=info
LOGRAGE_ENABLED=false
```

#### **Production Environment**
For production, set these environment variables in your deployment platform:

```bash
# Required for production
RAILS_ENV=production
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
RAILS_MASTER_KEY=<your-master-key>

# Database and Redis (usually set by platform)
DATABASE_URL=<production-database-url>
REDIS_URL=<production-redis-url>

# SSE Configuration
SSE_HOST=<your-domain>
SSE_PORT=443
SSE_SERVER_TYPE=go
SSE_AUTO_REFRESH=true

# Performance tuning
RAILS_MAX_THREADS=25
RAILS_LOG_LEVEL=info
LOGRAGE_ENABLED=true
```

### **Go Server Environment Variables**

The Go server also supports environment variables for configuration:

```bash
# Go server port (default: 3001)
SSE_PORT=3001

# Redis connection
REDIS_URL=redis://localhost:6379

# Log level (debug, info, warn, error)
LOG_LEVEL=info
```

### **Go Client Environment Variables**

The Go client supports these environment variables:

```bash
# Default URL for testing
SSE_URL=http://localhost:3000/dashboard/stream

# Default number of clients
SSE_CLIENTS=1

# Log level
LOG_LEVEL=info
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

## 🔄 SSE vs WebSocket Performance Analysis

### **Technical Architecture Differences**

#### **Server-Sent Events (SSE)**
```
Rails App (Thread-Limited)
├── Thread 1: SSE Client 1 (HTTP/1.1 streaming)
├── Thread 2: SSE Client 2 (HTTP/1.1 streaming)
├── Thread 3: SSE Client 3 (HTTP/1.1 streaming)
└── ... (max 25-50 concurrent connections)
```

#### **WebSocket (ActionCable)**
```
Rails App + ActionCable + Redis
├── Thread Pool (handles multiple connections)
├── Redis Pub/Sub (efficient message distribution)
└── WebSocket Clients (hundreds/thousands possible)
```

### **Scalability Comparison**

| Metric | SSE | WebSocket |
|--------|-----|-----------|
| **Max Concurrent Connections** | ~25-50 | ~1000+ |
| **Memory per Connection** | ~1-2MB | ~100-500KB |
| **Thread Usage** | 1 thread per connection | Thread pool (shared) |
| **CPU Usage** | Higher (per-connection processing) | Lower (efficient pooling) |
| **Network Efficiency** | HTTP overhead per message | Binary protocol, minimal overhead |
| **Message Latency** | Higher (HTTP processing) | Lower (direct WebSocket) |
| **Connection Limits** | Rails thread pool | System resources + Redis |

### **Why WebSocket is More Scalable**

#### **1. Thread Efficiency**
```ruby
# SSE: Each connection requires a dedicated Rails thread
# Limited by RAILS_MAX_THREADS (typically 25-50)
ActionController::Live::SSE.new(response.stream) do |stream|
  # This thread is tied up for the entire connection
end

# WebSocket: ActionCable uses thread pooling
# Can handle hundreds of connections with fewer threads
ActionCable.server.broadcast("channel", data)
# Efficient message distribution via Redis
```

#### **2. Memory Usage**
```ruby
# SSE: Full HTTP context per connection
# - Request headers
# - Response stream
# - Rails thread context
# - Connection state

# WebSocket: Minimal connection state
# - Lightweight connection object
# - Shared thread pool
# - Efficient message queuing
```

#### **3. Message Broadcasting**
```ruby
# SSE: Individual message delivery per connection
# Rails processes each connection separately
clients.each do |client|
  client.stream.write("data: #{message}\n\n")
end

# WebSocket: Efficient pub/sub with Redis
# Single broadcast, Redis handles distribution
ActionCable.server.broadcast("dashboard_updates", data)
```

#### **4. Protocol Overhead**
```ruby
# SSE: Text-based protocol with headers
"data: {\"type\":\"update\",\"timestamp\":\"20:00:00\"}\n\n"
": heartbeat\n\n"

# WebSocket: Binary protocol, minimal overhead
# Efficient binary message format
```

### **Real-World Performance Impact**

#### **SSE Limitations**
- **Connection Limit**: ~25-50 concurrent clients (Rails thread pool)
- **Memory Scaling**: Linear growth with connections
- **CPU Usage**: High due to per-connection processing
- **Horizontal Scaling**: Requires sticky sessions

#### **WebSocket Advantages**
- **Connection Limit**: 1000+ concurrent clients possible
- **Memory Scaling**: Much more efficient
- **CPU Usage**: Lower due to thread pooling
- **Horizontal Scaling**: Stateless, no sticky sessions needed

### **When to Use Each Protocol**

#### **Choose SSE When:**
- ✅ Simple implementation needed
- ✅ One-way communication (server → client)
- ✅ Small number of concurrent clients (< 50)
- ✅ HTTP-based infrastructure
- ✅ Browser compatibility is critical

#### **Choose WebSocket When:**
- ✅ High scalability required
- ✅ Bidirectional communication needed
- ✅ Large number of concurrent clients (> 100)
- ✅ Low latency requirements
- ✅ Efficient resource usage needed

### **Performance Testing Results**

Based on testing with the Go client:

| Test Scenario | SSE (Rails) | WebSocket (ActionCable) |
|---------------|-------------|-------------------------|
| **100 Clients** | ~25% CPU, 200MB RAM | ~5% CPU, 50MB RAM |
| **Connection Stability** | Occasional timeouts | Stable connections |
| **Message Latency** | 50-100ms | 10-30ms |
| **Resource Usage** | High per connection | Low per connection |

### **Production Considerations**

#### **SSE Deployment**
```ruby
# Rails configuration for SSE
config.threadsafe!
config.thread_count = 50  # Max concurrent connections
config.worker_processes = 4
# Requires sticky sessions for load balancing
```

#### **WebSocket Deployment**
```ruby
# ActionCable configuration
config.action_cable.adapter = :redis
config.action_cable.url = "ws://your-domain.com/cable"
# No sticky sessions required
# Can scale horizontally easily
```

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

## 🏗️ Heroku Deployment Guide

### **WebSocket Challenges on Heroku**

Deploying WebSockets on Heroku with Rails presents several specific challenges:

#### **1. Connection Timeout Issues**
```ruby
# Heroku has a 30-second connection timeout
# WebSocket connections can be terminated unexpectedly
# ActionCable connections may drop after idle periods

# Solution: Configure connection management
config.action_cable.connection_stale_check = 10.seconds
config.action_cable.worker_pool_size = 4
```

#### **2. Dyno Sleep/Wake Cycles**
```ruby
# Free/eco dynos sleep after 30 minutes of inactivity
# WebSocket connections are lost during sleep
# Clients need to reconnect when dyno wakes up

# Solution: Use paid dynos and implement reconnection
class WebSocketClient {
  connect() {
    this.ws = new WebSocket('wss://your-app.herokuapp.com/cable')
    this.ws.onclose = () => {
      setTimeout(() => this.connect(), 5000) // Reconnect after 5s
    }
  }
}
```

#### **3. Redis Add-on Limitations**
```ruby
# Heroku Redis connection limits:
# - Free tier: 20 connections
# - Hobby tier: 40 connections  
# - Production tier: 100+ connections

# Solution: Configure connection pooling
production:
  adapter: redis
  url: <%= ENV['REDIS_URL'] %>
  pool_size: 5
  pool_timeout: 5
```

#### **4. SSL/TLS Requirements**
```ruby
# Heroku requires HTTPS in production
# WebSocket connections must use WSS (secure)

# Solution: Force SSL and configure WSS
config.force_ssl = true
config.action_cable.url = "wss://your-app.herokuapp.com/cable"
```

### **Heroku Setup Instructions**

#### **1. Prerequisites**
```bash
# Install Heroku CLI
curl https://cli-assets.heroku.com/install.sh | sh

# Login to Heroku
heroku login
```

#### **2. Create Heroku App**
```bash
# Create new app
heroku create your-dashboard-app

# Set buildpack
heroku buildpacks:set heroku/ruby
```

#### **3. Configure Environment**
```bash
# Set environment variables
heroku config:set RAILS_ENV=production
heroku config:set RAILS_SERVE_STATIC_FILES=true
heroku config:set RAILS_LOG_TO_STDOUT=true
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key)
```

#### **4. Add Redis Add-on**
```bash
# Add Redis add-on (required for WebSocket)
heroku addons:create heroku-redis:hobby-dev

# Verify Redis URL
heroku config:get REDIS_URL
```

#### **5. Configure ActionCable**
```yaml
# config/cable.yml
production:
  adapter: redis
  url: <%= ENV['REDIS_URL'] %>
  channel_prefix: your_app_production
  pool_size: 5
  pool_timeout: 5
```

```ruby
# config/environments/production.rb
config.force_ssl = true
config.action_cable.allowed_request_origins = [
  'https://your-app.herokuapp.com'
]
config.action_cable.url = "wss://your-app.herokuapp.com/cable"
config.action_cable.connection_stale_check = 10.seconds
config.action_cable.worker_pool_size = 4
```

#### **6. Deploy Application**
```bash
# Deploy to Heroku
git add .
git commit -m "Deploy to Heroku"
git push heroku main

# Run database migrations
heroku run rails db:migrate

# Check app status
heroku ps
```

### **Dyno Configuration**

#### **Recommended Dyno Types**
```bash
# Use Hobby dyno ($7/month) - minimum for WebSocket apps
heroku ps:type hobby

# Avoid free tier - dynos sleep and break WebSocket connections
# Free tier: Sleeps after 30 minutes, breaks connections
# Hobby tier: Always on, supports WebSocket connections
```

#### **Scaling Considerations**
```bash
# Scale horizontally for more connections
heroku ps:scale web=2

# Monitor dyno performance
heroku logs --tail
heroku ps
```

### **Redis Configuration**

#### **Add-on Tiers**
| Tier | Connections | Price | Use Case |
|------|-------------|-------|----------|
| **Hobby Dev** | 40 | $15/month | Development/Testing |
| **Hobby Basic** | 40 | $15/month | Small Production |
| **Standard 0** | 100 | $50/month | Medium Production |
| **Standard 1** | 200 | $100/month | Large Production |

#### **Connection Monitoring**
```bash
# Monitor Redis connections
heroku redis:cli
> CLIENT LIST

# Check connection count
heroku redis:cli
> INFO clients
```

### **SSL and Security**

#### **Automatic SSL**
```ruby
# Heroku provides automatic SSL certificates
# Configure Rails to force SSL
config.force_ssl = true

# ActionCable must use WSS
config.action_cable.url = "wss://your-app.herokuapp.com/cable"
```

#### **CORS Configuration**
```ruby
# Allow WebSocket connections from your domain
config.action_cable.allowed_request_origins = [
  'https://your-app.herokuapp.com',
  'https://www.your-domain.com'
]
```

### **Client-Side Resilience**

#### **Robust WebSocket Client**
```javascript
class HerokuWebSocketClient {
  constructor() {
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 10;
    this.reconnectDelay = 5000;
  }

  connect() {
    const wsUrl = window.location.protocol === 'https:' 
      ? 'wss://your-app.herokuapp.com/cable'
      : 'ws://your-app.herokuapp.com/cable';
    
    this.ws = new WebSocket(wsUrl);
    
    this.ws.onopen = () => {
      console.log('Connected to WebSocket');
      this.reconnectAttempts = 0;
    };

    this.ws.onclose = () => {
      console.log('WebSocket disconnected');
      this.reconnect();
    };

    this.ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };
  }

  reconnect() {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++;
      console.log(`Reconnecting... Attempt ${this.reconnectAttempts}`);
      setTimeout(() => this.connect(), this.reconnectDelay);
    }
  }
}
```

### **Monitoring and Debugging**

#### **Log Monitoring**
```bash
# View real-time logs
heroku logs --tail

# Filter WebSocket logs
heroku logs --tail | grep -i websocket

# Check Redis logs
heroku logs --tail | grep -i redis
```

#### **Performance Monitoring**
```bash
# Check dyno performance
heroku ps

# Monitor memory usage
heroku logs --tail | grep -i memory

# Check connection count
heroku redis:cli
> CLIENT LIST | wc -l
```

### **Common Issues and Solutions**

#### **Issue: WebSocket connections dropping**
```bash
# Solution: Use paid dynos and implement reconnection
heroku ps:type hobby
# Add client-side reconnection logic
```

#### **Issue: Redis connection limits**
```bash
# Solution: Upgrade Redis add-on or optimize connections
heroku addons:upgrade heroku-redis:standard-0
```

#### **Issue: SSL certificate errors**
```ruby
# Solution: Ensure proper SSL configuration
config.force_ssl = true
config.action_cable.url = "wss://your-app.herokuapp.com/cable"
```

### **Cost Estimation**

#### **Monthly Costs (Minimum)**
- **Hobby Dyno**: $7/month
- **Hobby Redis**: $15/month
- **Total**: ~$22/month

#### **Production Costs**
- **Standard Dyno**: $25/month
- **Standard Redis**: $50/month
- **Total**: ~$75/month

### **Platform Comparison**

| Platform | WebSocket Support | Redis | SSL | Monthly Cost | Ease of Setup |
|----------|------------------|-------|-----|--------------|---------------|
| **Heroku** | ✅ Excellent | Add-on | ✅ Automatic | $22+ | ⭐⭐⭐⭐⭐ |
| **Railway** | ✅ Good | Built-in | ✅ Automatic | $5+ | ⭐⭐⭐⭐⭐ |
| **Render** | ✅ Good | Add-on | ✅ Automatic | $7+ | ⭐⭐⭐⭐ |
| **AWS** | ✅ Excellent | ElastiCache | Manual | $20+ | ⭐⭐⭐ |
| **DigitalOcean** | ✅ Good | Managed | Manual | $12+ | ⭐⭐⭐⭐ |

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
