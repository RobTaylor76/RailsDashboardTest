# Pub/Sub Architecture for Cross-Process Communication

## 🎯 Problem Solved

**Background jobs run in separate processes from the web server**, making it impossible for jobs to directly trigger SSE updates to connected clients.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Background    │    │   Pub/Sub       │    │   Web Server    │
│   Job Process   │───▶│   Service       │───▶│   (SSE/WS)      │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │   Backend       │
                       │   (Redis/DB)    │
                       └─────────────────┘
```

## 🔧 Components

### 1. **PubsubService** (`app/services/pubsub_service.rb`)
- **Unified interface** for cross-process communication
- **Auto-detects backend**: Redis (preferred) or Database (fallback)
- **Used by background jobs** to publish updates

### 2. **Redis Backend** (`app/services/redis_pubsub_service.rb`)
- **Real-time pub/sub** using Redis
- **Low latency** for immediate updates
- **Requires Redis server**

### 3. **Database Backend** (`app/services/database_pubsub_service.rb`)
- **Polling-based** using database table
- **No external dependencies**
- **Higher latency** but more reliable

### 4. **SSE Manager** (`app/services/sse_manager.rb`)
- **Manages SSE connections** in web server
- **Listens for pub/sub events**
- **Broadcasts to connected clients**

## 🚀 How It Works

### **Background Job Flow:**
1. Job generates data (metrics, activities, etc.)
2. Job calls `PubsubService.instance.publish('dashboard_updates', data)`
3. Service publishes to Redis or Database
4. Job continues processing

### **Web Server Flow:**
1. SSE Manager starts listening for pub/sub events
2. When event received, broadcasts to all connected SSE clients
3. WebSocket clients also receive updates via ActionCable

### **Client Flow:**
1. Browser connects to SSE endpoint (`/dashboard/stream`)
2. Browser receives real-time updates from background jobs
3. Updates appear immediately without page refresh

## 📊 Backend Comparison

| Feature | Redis Backend | Database Backend |
|---------|---------------|------------------|
| **Latency** | ~1ms | ~1000ms (polling) |
| **Dependencies** | Redis server | None |
| **Reliability** | High | Very High |
| **Scalability** | Excellent | Good |
| **Setup** | Requires Redis | Works out of box |

## 🔄 Auto-Detection Logic

```ruby
def determine_backend
  if redis_available?
    :redis
  else
    :database
  end
end
```

- **Checks Redis connection** on startup
- **Falls back to database** if Redis unavailable
- **Logs which backend** is being used

## 🛠️ Usage Examples

### **Background Job Publishing:**
```ruby
class MyJob < ApplicationJob
  def perform
    data = { type: "update", message: "Job completed" }
    PubsubService.instance.publish('dashboard_updates', data)
  end
end
```

### **Manual Testing:**
```bash
# Trigger test job
curl http://localhost:3000/dashboard/trigger-test-pubsub

# Check pub/sub status
curl http://localhost:3000/dashboard/debug
```

### **Monitoring:**
```bash
# Check pub/sub events
bin/rails console
> PubsubEvent.count
> PubsubEvent.last

# Monitor logs
tail -f log/development.log | grep "pub/sub"
```

## 🌐 Multi-Server Support

This architecture works across **multiple servers**:

```
Server A (Web)     Server B (Worker)     Server C (Worker)
     │                    │                    │
     └──────────┬─────────┴──────────┬─────────┘
                │                    │
         ┌──────▼──────┐      ┌──────▼──────┐
         │    Redis    │      │  Database   │
         │   (Pub/Sub) │      │  (Fallback) │
         └─────────────┘      └─────────────┘
```

- **Redis**: Shared across all servers
- **Database**: Already shared for job processing
- **No direct connections** between servers needed

## 🔧 Configuration

### **Environment Variables:**
```bash
# Redis (optional)
REDIS_URL=redis://localhost:6379

# Force backend (optional)
PUBSUB_BACKEND=redis    # or 'database'
```

### **Database Schema:**
```sql
CREATE TABLE pubsub_events (
  id SERIAL PRIMARY KEY,
  channel VARCHAR NOT NULL,
  data JSON NOT NULL,
  created_at TIMESTAMP NOT NULL
);
```

## 🎯 Benefits

1. **Cross-Process**: Works with separate web/worker processes
2. **Multi-Server**: Works across different servers
3. **Auto-Fallback**: Graceful degradation if Redis unavailable
4. **Real-Time**: Immediate updates to connected clients
5. **Scalable**: Can handle many concurrent connections
6. **Reliable**: Database fallback ensures message delivery

## 🚨 Troubleshooting

### **Redis Connection Issues:**
```bash
# Check Redis
redis-cli ping

# Check logs
tail -f log/development.log | grep "Redis"
```

### **Database Backend Issues:**
```bash
# Check pubsub_events table
bin/rails console
> PubsubEvent.count

# Check for errors
tail -f log/development.log | grep "Database"
```

### **SSE Connection Issues:**
```bash
# Check SSE connections
curl http://localhost:3000/dashboard/debug | jq '.sse_connections'

# Monitor SSE logs
tail -f log/development.log | grep "SSE"
```

This architecture provides a robust, scalable solution for real-time updates from background jobs to web clients, regardless of process or server separation.
