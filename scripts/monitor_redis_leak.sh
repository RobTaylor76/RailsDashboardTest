#!/bin/bash

# Redis Connection Leak Monitor
# This script helps identify Redis connection leaks

echo "🔍 Redis Connection Leak Monitor"
echo "================================"

# Function to get Redis connection count
get_redis_connections() {
    docker exec redis-dashboard redis-cli info clients | grep "connected_clients:" | cut -d: -f2 | tr -d '\r'
}

# Function to get detailed connection info
get_connection_details() {
    echo "=== Redis Connection Details ==="
    docker exec redis-dashboard redis-cli client list | grep -E "(addr=|cmd=|age=|idle=)" | head -10
}

# Function to trigger background jobs
trigger_jobs() {
    echo "  📡 Triggering background jobs..."
    curl -s http://localhost:3000/dashboard/trigger-test-pubsub > /dev/null
    curl -s http://localhost:3000/dashboard/trigger-jobs > /dev/null
}

# Function to check Rails app status
check_rails_status() {
    if curl -s http://localhost:3000/dashboard/debug > /dev/null 2>&1; then
        echo "  ✅ Rails app is running"
        return 0
    else
        echo "  ❌ Rails app is not running"
        return 1
    fi
}

# Main monitoring sequence
echo "📋 Monitoring Plan:"
echo "1. Check initial Redis connections"
echo "2. Trigger background jobs"
echo "3. Monitor connection changes"
echo "4. Check for connection leaks"
echo ""

# Initial setup
echo "🔧 Initial Setup"
echo "================"
if ! check_rails_status; then
    echo "💡 Please start the Rails server: cd dashboard && rails server"
    exit 1
fi

initial_connections=$(get_redis_connections)
echo "📊 Initial Redis connections: $initial_connections"
echo ""

# Monitor for 60 seconds
echo "🧪 Connection Leak Test"
echo "======================"
echo "Monitoring Redis connections for 60 seconds..."
echo ""

start_time=$(date +%s)
last_connections=$initial_connections

for i in {1..12}; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    # Trigger jobs every 10 seconds
    if [ $((i % 2)) -eq 1 ]; then
        trigger_jobs
    fi
    
    # Wait 5 seconds
    sleep 5
    
    # Check connections
    current_connections=$(get_redis_connections)
    change=$((current_connections - last_connections))
    
    echo "[$elapsed seconds] Connections: $current_connections (change: $change)"
    
    # Show warning if connections are increasing
    if [ $change -gt 0 ]; then
        echo "  ⚠️  Connection increase detected!"
    elif [ $change -lt 0 ]; then
        echo "  ✅ Connection decrease"
    fi
    
    last_connections=$current_connections
done

# Final analysis
echo ""
echo "📊 Final Analysis"
echo "================"
final_connections=$(get_redis_connections)
total_change=$((final_connections - initial_connections))

echo "Initial connections: $initial_connections"
echo "Final connections: $final_connections"
echo "Total change: $total_change"

if [ $total_change -gt 5 ]; then
    echo ""
    echo "❌ CONNECTION LEAK DETECTED!"
    echo "   +$total_change connections over 60 seconds"
    echo ""
    echo "🔍 Possible causes:"
    echo "   - Background jobs creating new Redis connections"
    echo "   - PubsubService not reusing connections"
    echo "   - SSE streams not closing properly"
    echo "   - RedisPubsubService singleton issues"
    echo ""
    echo "💡 Next steps:"
    echo "   1. Check Rails logs: tail -f dashboard/log/development.log"
    echo "   2. Monitor specific connections: docker exec redis-dashboard redis-cli client list"
    echo "   3. Restart Rails server to clear connections"
    echo "   4. Check if worker process is creating connections"
elif [ $total_change -gt 0 ]; then
    echo ""
    echo "⚠️  Minor connection increase (+$total_change)"
    echo "   Monitor for continued growth"
else
    echo ""
    echo "✅ No significant connection leak detected"
fi

echo ""
echo "🔍 Detailed connection info:"
get_connection_details
