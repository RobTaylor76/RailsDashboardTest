# Redis Setup Guide for Dashboard Pub/Sub

## 🎯 Overview

Redis is used for real-time pub/sub communication between background jobs and the web server. This enables immediate updates to SSE clients when jobs complete.

## 🐳 Docker Setup (Recommended)

### **Quick Start:**
```bash
# Start Redis with Docker
./bin/redis start

# Check status
./bin/redis status

# Test connection
./bin/redis test
```

### **Docker Compose (Production-like):**
```bash
# Start all services
docker-compose up -d

# Start only Redis
docker-compose up -d redis

# View logs
docker-compose logs redis
```

## 🔧 Manual Installation

### **macOS (Homebrew):**
```bash
# Install Redis
brew install redis

# Start Redis service
brew services start redis

# Test connection
redis-cli ping
```

### **Ubuntu/Debian:**
```bash
# Install Redis
sudo apt update
sudo apt install redis-server

# Start Redis service
sudo systemctl start redis-server
sudo systemctl enable redis-server

# Test connection
redis-cli ping
```

### **CentOS/RHEL:**
```bash
# Install Redis
sudo yum install redis

# Start Redis service
sudo systemctl start redis
sudo systemctl enable redis

# Test connection
redis-cli ping
```

## ⚙️ Configuration

### **Environment Variables:**
```bash
# Default Redis URL
REDIS_URL=redis://localhost:6379

# With authentication
REDIS_URL=redis://:password@localhost:6379

# With database selection
REDIS_URL=redis://localhost:6379/1

# Remote Redis
REDIS_URL=redis://redis.example.com:6379
```

### **Rails Configuration:**
The application automatically detects Redis availability:

```ruby
# config/initializers/redis.rb
redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379')
```

## 🧪 Testing Redis

### **Connection Test:**
```bash
# Using the script
./bin/redis test

# Manual test
docker exec redis-dashboard redis-cli ping
```

### **Pub/Sub Test:**
```bash
# Test publishing
docker exec redis-dashboard redis-cli PUBLISH test_channel "Hello World"

# Test subscribing (in another terminal)
docker exec redis-dashboard redis-cli SUBSCRIBE test_channel
```

### **Performance Test:**
```bash
# Benchmark Redis
docker exec redis-dashboard redis-cli --eval - <<EOF
local start = redis.call('TIME')[1]
for i=1,1000 do
  redis.call('SET', 'test:' .. i, 'value')
end
local end_time = redis.call('TIME')[1]
return end_time - start
EOF
```

## 📊 Monitoring

### **Redis Info:**
```bash
# Get Redis information
./bin/redis info

# Memory usage
docker exec redis-dashboard redis-cli INFO memory

# Connected clients
docker exec redis-dashboard redis-cli INFO clients
```

### **Logs:**
```bash
# View Redis logs
./bin/redis logs

# Follow logs
docker logs -f redis-dashboard
```

## 🔒 Security

### **Basic Security:**
```bash
# Set Redis password
docker run -d --name redis-dashboard \
  -p 6379:6379 \
  redis:7-alpine \
  redis-server --requirepass yourpassword

# Connect with password
redis-cli -a yourpassword
```

### **Network Security:**
```bash
# Bind to localhost only
docker run -d --name redis-dashboard \
  -p 127.0.0.1:6379:6379 \
  redis:7-alpine
```

## 🚀 Production Setup

### **Docker Compose Production:**
```yaml
# docker-compose.prod.yml
version: '3.8'
services:
  redis:
    image: redis:7-alpine
    container_name: dashboard-redis-prod
    ports:
      - "127.0.0.1:6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    restart: unless-stopped
    networks:
      - dashboard-network

volumes:
  redis_data:

networks:
  dashboard-network:
    driver: bridge
```

### **Environment Variables:**
```bash
# .env.production
REDIS_URL=redis://:${REDIS_PASSWORD}@localhost:6379
REDIS_PASSWORD=your_secure_password
```

## 🔧 Troubleshooting

### **Connection Issues:**
```bash
# Check if Redis is running
./bin/redis status

# Check port availability
netstat -an | grep 6379

# Test connection manually
telnet localhost 6379
```

### **Permission Issues:**
```bash
# Fix Docker permissions
sudo chown $USER:$USER /var/run/docker.sock

# Fix Redis data directory
sudo chown -R redis:redis /var/lib/redis
```

### **Memory Issues:**
```bash
# Check Redis memory usage
docker exec redis-dashboard redis-cli INFO memory

# Flush Redis data
./bin/redis flush

# Monitor memory in real-time
watch -n 1 'docker exec redis-dashboard redis-cli INFO memory | grep used_memory_human'
```

## 📈 Performance Tuning

### **Redis Configuration:**
```bash
# Custom Redis config
docker run -d --name redis-dashboard \
  -p 6379:6379 \
  -v ./redis.conf:/usr/local/etc/redis/redis.conf \
  redis:7-alpine \
  redis-server /usr/local/etc/redis/redis.conf
```

### **Sample redis.conf:**
```conf
# Memory management
maxmemory 256mb
maxmemory-policy allkeys-lru

# Persistence
save 900 1
save 300 10
save 60 10000

# Network
tcp-keepalive 300
timeout 0

# Logging
loglevel notice
logfile ""
```

## 🔄 Backup & Recovery

### **Backup Redis Data:**
```bash
# Create backup
docker exec redis-dashboard redis-cli BGSAVE

# Copy RDB file
docker cp redis-dashboard:/data/dump.rdb ./redis-backup.rdb
```

### **Restore Redis Data:**
```bash
# Stop Redis
./bin/redis stop

# Copy backup file
docker cp ./redis-backup.rdb redis-dashboard:/data/dump.rdb

# Start Redis
./bin/redis start
```

## 🎯 Integration with Dashboard

### **Automatic Detection:**
The dashboard automatically detects Redis availability and falls back to database pub/sub if Redis is unavailable.

### **Testing Integration:**
```bash
# Start Redis
./bin/redis start

# Start dashboard
./bin/dev

# Trigger test job
curl http://localhost:3000/dashboard/trigger-test-pubsub

# Check pub/sub status
curl http://localhost:3000/dashboard/debug | jq '.pubsub_backend'
```

This setup provides a robust, scalable Redis solution for real-time pub/sub communication in your dashboard application.
