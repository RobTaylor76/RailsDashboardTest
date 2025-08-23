# Bin Directory Scripts

Executable scripts for running the Rails application with separate web and background job processes.

## 🚀 Quick Start

| Command | What it does | When to use |
|---------|-------------|-------------|
| `./bin/dev` | **Start both web + worker** | Development (recommended) |
| `./bin/web` | Start web server only | Production web server |
| `./bin/worker` | Start worker only | Production worker |
| `./bin/redis start` | Start Redis for pub/sub | Development/production |
| `foreman start` | Start both with Foreman | Alternative to `./bin/dev` |

## 📋 Scripts Overview

### Core Scripts

**`bin/web`** - Rails web server
- Runs on port 3000
- Handles HTTP requests
- Configured for 25 threads (supports 20+ SSE workers)
- Usage: `./bin/web`

**`bin/worker`** - Background job processor
- Uses Solid Queue (Rails 8 default)
- Processes jobs from database
- Usage: `./bin/worker`

**`bin/jobs`** - Built-in Solid Queue CLI
- Rails 8's job processing command
- Used internally by `bin/worker`
- Usage: `./bin/jobs [command]`

### Development Scripts

**`bin/dev`** - Development environment
- Starts both web and worker
- Uses Foreman for process management
- Usage: `./bin/dev`

**`bin/rails`** - Rails commands
- Database operations, generators, etc.
- Usage: `./bin/rails [command]`

**`bin/rake`** - Rake tasks
- Custom application tasks
- Usage: `./bin/rake [task]`

**`bin/redis`** - Redis management
- Start/stop Redis for pub/sub system
- Usage: `./bin/redis {start|stop|status|test}`

## 🛠 Usage Patterns

### Development

**Easiest way:**
```bash
# Start Redis first
./bin/redis start

# Then start the application
./bin/dev
```

**Manual control:**
```bash
# Terminal 1 - Start Redis
./bin/redis start

# Terminal 2 - Web server
./bin/web

# Terminal 3 - Worker
./bin/worker
```

**With Foreman:**
```bash
foreman start -f Procfile
```

### Production

**Separate processes:**
```bash
# Web server
./bin/web

# Worker (can be on different machine)
./bin/worker
```

## 🔧 Configuration

### Procfile
```
web: ./bin/web
worker: ./bin/worker
```

### Web Server (SSE Support)
- **Threads**: 25 (configurable via `RAILS_MAX_THREADS`)
- **SSE Workers**: Supports 20+ concurrent SSE connections
- **Database Pool**: Matches thread count for optimal performance
- **Config**: `config/puma.rb` and `config/database.yml`

### Job Processing
- **Adapter**: Solid Queue
- **Config**: `config/queue.yml`
- **Database**: PostgreSQL
- **Jobs**: `app/jobs/`

### Pub/Sub System
- **Unified Service**: `app/services/pubsub_service.rb` - Cross-process communication
- **Redis Backend**: Real-time pub/sub (preferred, requires Redis)
- **Database Backend**: Polling-based pub/sub (fallback, no Redis required)
- **SSE Manager**: `app/services/sse_manager.rb` - Manages SSE connections
- **ActionCable**: WebSocket support for real-time updates
- **Background Jobs**: Generate data and trigger broadcasts
- **Cross-Process**: Works with separate web/worker processes and servers

## 📊 Monitoring

### Process Management
```bash
# Check if processes are running
ps aux | grep -E "(rails|solid-queue)" | grep -v grep

# Check PID files
cat tmp/pids/server.pid    # Web server PID
cat tmp/pids/worker.pid    # Worker PID

# Stop processes using PID files
kill $(cat tmp/pids/server.pid) 2>/dev/null || echo "Web server not running"
kill $(cat tmp/pids/worker.pid) 2>/dev/null || echo "Worker not running"

# Stop all processes
pkill -f "solid-queue"
pkill -f "rails server"
```

### Check Job Status
```bash
# Rails console
bin/rails console
> SolidQueue::Job.count
> SolidQueue::Job.last

# View logs
tail -f log/development.log
```

### Redis Management
```bash
# Start Redis
./bin/redis start

# Check Redis status
./bin/redis status

# Test Redis pub/sub
./bin/redis test

# Stop Redis
./bin/redis stop

# View Redis logs
./bin/redis logs
```

### Test Pub/Sub System
```bash
# Trigger test job (broadcasts to SSE and WebSocket)
curl http://localhost:3000/dashboard/trigger-test-pubsub

# Check SSE connections and pub/sub status
curl http://localhost:3000/dashboard/debug | jq '.sse_connections, .pubsub_backend, .pubsub_events_count'

# Monitor logs for broadcasts
tail -f log/development.log | grep -E "(SSE|WebSocket|broadcast|pub/sub)"

# Check pub/sub events in database
bin/rails console
> PubsubEvent.count
> PubsubEvent.last
```



## 🚨 Troubleshooting

### Worker Issues
1. **Tables missing**: `bin/rails db:migrate`
2. **Wrong adapter**: Check `config/environments/development.rb`
3. **Segfault**: Use Ruby 3.3.9+ (avoid 3.4.1 with msgpack 1.8.0)

### Web Server Issues
1. **Port in use**: `lsof -i :3000`
2. **Database**: `bin/rails db:version`

## 🌍 Environment

### Development
- `RAILS_ENV=development`
- `PORT=3000`
- `RAILS_MAX_THREADS=25` (for SSE support)

### Production  
- `RAILS_ENV=production`
- `DATABASE_URL`
- `REDIS_URL` (if using Redis)
- `RAILS_MAX_THREADS=25` (for SSE support)

## 📁 File Structure

```
bin/
├── README.md          # This file
├── dev               # Development script
├── web               # Web server
├── worker            # Worker
├── jobs              # Solid Queue CLI
├── rails             # Rails commands
└── rake              # Rake tasks

Procfile              # Process definitions

tmp/pids/
├── server.pid        # Web server process ID
└── worker.pid        # Worker process ID
```

## 📚 Dependencies

- **Foreman**: `gem install foreman`
- **Solid Queue**: Included in Rails 8
- **PostgreSQL**: Database

## ✅ Best Practices

1. **Separate processes** for web and worker
2. **Monitor independently** in production
3. **Use process managers** (systemd, supervisor)
4. **Scale workers** horizontally
5. **Monitor job queues** for backlog
6. **Use Ruby 3.3.9+** for stability

## 🔗 Related Files

- `config/queue.yml` - Job configuration
- `config/environments/development.rb` - Job adapter
- `app/jobs/` - Job classes
- `log/` - Application logs
