# Bin Directory Scripts

Executable scripts for running the Rails application with separate web and background job processes.

## 🚀 Quick Start

| Command | What it does | When to use |
|---------|-------------|-------------|
| `./bin/dev` | **Start both web + worker** | Development (recommended) |
| `./bin/web` | Start web server only | Production web server |
| `./bin/worker` | Start worker only | Production worker |
| `foreman start` | Start both with Foreman | Alternative to `./bin/dev` |

## 📋 Scripts Overview

### Core Scripts

**`bin/web`** - Rails web server
- Runs on port 3000
- Handles HTTP requests
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

## 🛠 Usage Patterns

### Development

**Easiest way:**
```bash
./bin/dev
```

**Manual control:**
```bash
# Terminal 1
./bin/web

# Terminal 2  
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

### Job Processing
- **Adapter**: Solid Queue
- **Config**: `config/queue.yml`
- **Database**: PostgreSQL
- **Jobs**: `app/jobs/`

## 📊 Monitoring

### Check Job Status
```bash
# Rails console
bin/rails console
> SolidQueue::Job.count
> SolidQueue::Job.last

# View logs
tail -f log/development.log
```

### Check Processes
```bash
# Running processes
ps aux | grep -E "(rails|solid-queue)" | grep -v grep

# Stop processes
pkill -f "solid-queue"
pkill -f "rails server"
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

### Production  
- `RAILS_ENV=production`
- `DATABASE_URL`
- `REDIS_URL` (if using Redis)

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
