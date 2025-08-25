# Redis Monitoring Scripts (Docker)

This directory contains shell scripts to monitor Redis connection counts and message counts using Docker.

## Prerequisites

- Docker must be installed and running
- Redis container must be running and accessible
- The scripts assume your Redis container is named `redis-dashboard` (configurable via `REDIS_CONTAINER`)

## Scripts Overview

### 1. `redis-stats.sh` - Simple Stats
Quick one-time stats for connection count and message counts.

**Usage:**
```bash
# Get all stats
./redis-stats.sh

# Get specific stats
./redis-stats.sh connections    # Connection count only
./redis-stats.sh commands       # Total commands processed
./redis-stats.sh subscribers    # Pub/sub subscriber count
./redis-stats.sh memory         # Memory usage
```

**Example Output:**
```
=== Redis Stats ===
2024-01-15 14:30:25
Connections: 5
Total Commands: 12345
Dashboard Subscribers: 3
Memory Used: 2.5M
==================
```

### 2. `redis-watch.sh` - Live Monitoring
Continuous monitoring with periodic updates.

**Usage:**
```bash
# Default 5-second intervals
./redis-watch.sh

# Custom interval (e.g., 2 seconds)
INTERVAL=2 ./redis-watch.sh
```

**Example Output:**
```
=== Redis Live Monitor ===
Host: localhost:6379
Container: redis-dashboard
Update Interval: 5s
Press Ctrl+C to stop

Time                 | Connections     | Total Commands      | Subscribers
---------------------------------------------------------------------------
14:30:25             | 5               | 12345               | 3
14:30:30             | 6               | 12350               | 3
14:30:35             | 5               | 12355               | 2
```

### 3. `redis-monitor.sh` - Comprehensive Monitoring
Full-featured monitoring with multiple commands.

**Usage:**
```bash
# Show help
./redis-monitor.sh help

# Get connection count
./redis-monitor.sh connections

# Get detailed connection info
./redis-monitor.sh details

# Get Redis INFO output
./redis-monitor.sh info

# Get pub/sub channels
./redis-monitor.sh pubsub

# Get subscriber counts
./redis-monitor.sh subscribers

# Get memory usage
./redis-monitor.sh memory

# Get Redis statistics
./redis-monitor.sh stats

# Real-time monitoring
./redis-monitor.sh monitor

# Show slow log
./redis-monitor.sh slowlog

# Get all information
./redis-monitor.sh all
```

## Environment Variables

All scripts support these environment variables:

- `REDIS_HOST` - Redis host (default: localhost)
- `REDIS_PORT` - Redis port (default: 6379)
- `REDIS_PASSWORD` - Redis password (optional)
- `REDIS_CONTAINER` - Redis container name (default: redis-dashboard)
- `INTERVAL` - Update interval for watch script (default: 5 seconds)

**Example with custom Redis container:**
```bash
REDIS_CONTAINER=my-redis REDIS_HOST=redis.example.com REDIS_PORT=6380 REDIS_PASSWORD=mypassword ./redis-stats.sh
```

## Key Redis Commands Used (via Docker)

### Connection Count
```bash
docker exec redis-dashboard redis-cli client list | wc -l
```

### Total Commands Processed (Message Count Proxy)
```bash
docker exec redis-dashboard redis-cli info stats | grep total_commands_processed
```

### Pub/Sub Subscriber Count
```bash
docker exec redis-dashboard redis-cli pubsub numsub dashboard_updates
```

### Memory Usage
```bash
docker exec redis-dashboard redis-cli info memory | grep used_memory_human
```

### Detailed Connection Info
```bash
docker exec redis-dashboard redis-cli client list
```

## Integration with Your Rails Dashboard

These scripts work with your Rails dashboard's Redis setup:

1. **Connection Count**: Shows all active Redis connections (including Rails app, ActionCable, pub/sub)
2. **Message Count**: Uses `total_commands_processed` as a proxy for message count
3. **Subscriber Count**: Specifically monitors the `dashboard_updates` channel used by your pub/sub system

## Quick Commands

Here are some quick one-liners you can run directly:

```bash
# Get connection count
docker exec redis-dashboard redis-cli client list | wc -l

# Get total commands processed
docker exec redis-dashboard redis-cli info stats | grep total_commands_processed | cut -d: -f2

# Get subscriber count for dashboard channel
docker exec redis-dashboard redis-cli pubsub numsub dashboard_updates | tail -1

# Get memory usage
docker exec redis-dashboard redis-cli info memory | grep used_memory_human | cut -d: -f2

# Get all key metrics in one command
echo "Connections: $(docker exec redis-dashboard redis-cli client list | wc -l), Commands: $(docker exec redis-dashboard redis-cli info stats | grep total_commands_processed | cut -d: -f2), Subscribers: $(docker exec redis-dashboard redis-cli pubsub numsub dashboard_updates | tail -1)"
```

## Docker Setup

If you don't have Redis running in Docker yet, you can start it with:

```bash
# Start Redis container
docker run -d --name redis-dashboard -p 6379:6379 redis:7-alpine

# Or if you want to use your existing Redis setup, just make sure the container name matches
# You can check running containers with:
docker ps | grep redis
```

## Troubleshooting

1. **Container not found**: Make sure your Redis container is running and the name matches `REDIS_CONTAINER`
2. **Connection refused**: Check if Redis is accessible from within the container
3. **Authentication failed**: Set `REDIS_PASSWORD` environment variable
4. **Permission denied**: Make scripts executable with `chmod +x *.sh`
5. **Docker not running**: Ensure Docker daemon is started

## Finding Your Redis Container

If you're not sure what your Redis container is named:

```bash
# List all running containers
docker ps

# List all containers (including stopped ones)
docker ps -a

# Look for Redis containers
docker ps | grep -i redis
```

Then set the correct container name:
```bash
REDIS_CONTAINER=your-actual-container-name ./redis-stats.sh
```
