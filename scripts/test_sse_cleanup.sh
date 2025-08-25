#!/bin/bash

# SSE Cleanup Test Script
# This script tests the Redis connection cleanup fix

echo "🧪 SSE Cleanup Test"
echo "==================="

# Function to get Redis connection count
get_redis_connections() {
    redis-cli info clients | grep "connected_clients:" | cut -d: -f2 | tr -d '\r'
}

# Function to check Rails app status
check_rails_status() {
    if curl -s http://localhost:3000/dashboard/debug > /dev/null 2>&1; then
        echo "  ✅ Rails app is running"
        return 0
    else
        echo "  ❌ Rails app is not running on localhost:3000"
        return 1
    fi
}

# Function to get SSE connection count from Rails
get_sse_connections() {
    curl -s http://localhost:3000/dashboard/debug | jq -r '.sse_connections.total_connections // 0'
}

# Function to get Redis status from Rails
get_rails_redis_status() {
    curl -s http://localhost:3000/dashboard/debug | jq -r '.redis_connections // empty'
}

# Function to trigger Redis cleanup
trigger_cleanup() {
    echo "  🔧 Triggering Redis cleanup..."
    curl -s http://localhost:3000/dashboard/cleanup-redis-connections | jq -r '.message'
}

# Function to trigger test pubsub
trigger_pubsub() {
    echo "  📡 Triggering test pub/sub..."
    curl -s http://localhost:3000/dashboard/trigger-test-pubsub | jq -r '.message'
}

# Main test sequence
echo "📋 Test Plan:"
echo "1. Check initial state"
echo "2. Start SSE client test"
echo "3. Monitor connections during test"
echo "4. Stop SSE client test"
echo "5. Check cleanup"
echo ""

# Initial setup
echo "🔧 Initial Setup"
echo "================"
if ! check_rails_status; then
    echo "💡 Please start the Rails server: cd dashboard && rails server"
    exit 1
fi

initial_redis_connections=$(get_redis_connections)
initial_sse_connections=$(get_sse_connections)

echo "📊 Initial state:"
echo "  Redis connections: $initial_redis_connections"
echo "  SSE connections: $initial_sse_connections"
echo ""

# Test 1: Trigger pub/sub without SSE clients
echo "🧪 Test 1: Pub/Sub Without SSE Clients"
echo "======================================"
trigger_pubsub
sleep 2

redis_connections=$(get_redis_connections)
echo "  Redis connections after pub/sub: $redis_connections"

# Test 2: Start SSE client test
echo ""
echo "🧪 Test 2: SSE Client Test"
echo "=========================="
echo "  🚀 Starting SSE client test in background..."
cd dashboard/goclient
./test.sh <<< "2
3" > /tmp/sse_test.log 2>&1 &
SSE_PID=$!
cd ../..

# Monitor for 10 seconds
echo "  📊 Monitoring for 10 seconds..."
for i in {1..10}; do
    sleep 1
    redis_conn=$(get_redis_connections)
    sse_conn=$(get_sse_connections)
    echo "    [$i/10] Redis: $redis_conn, SSE: $sse_conn"
done

# Stop SSE client test
echo "  🛑 Stopping SSE client test..."
kill $SSE_PID 2>/dev/null
wait $SSE_PID 2>/dev/null

# Wait for cleanup
echo "  ⏳ Waiting for cleanup..."
sleep 5

# Final check
echo ""
echo "📊 Final Results"
echo "================"
final_redis_connections=$(get_redis_connections)
final_sse_connections=$(get_sse_connections)

echo "Initial Redis connections: $initial_redis_connections"
echo "Final Redis connections: $final_redis_connections"
echo "Redis connection change: $((final_redis_connections - initial_redis_connections))"
echo ""
echo "Initial SSE connections: $initial_sse_connections"
echo "Final SSE connections: $final_sse_connections"
echo "SSE connection change: $((final_sse_connections - initial_sse_connections))"

# Check for connection leaks
redis_leak=$((final_redis_connections - initial_redis_connections))
if [ $redis_leak -gt 2 ]; then
    echo ""
    echo "❌ Potential Redis connection leak detected! (+$redis_leak connections)"
    echo "💡 Try manual cleanup:"
    echo "   curl http://localhost:3000/dashboard/cleanup-redis-connections"
elif [ $redis_leak -gt 0 ]; then
    echo ""
    echo "⚠️  Minor Redis connection increase (+$redis_leak connections)"
    echo "💡 This might be normal, but monitor for continued growth"
else
    echo ""
    echo "✅ No significant Redis connection leak detected"
fi

echo ""
echo "🔍 For detailed monitoring, run:"
echo "   ruby dashboard/scripts/monitor_redis_connections.rb"
echo ""
echo "📊 To check Rails debug info:"
echo "   curl http://localhost:3000/dashboard/debug | jq"
