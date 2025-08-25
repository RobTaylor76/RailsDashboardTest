#!/bin/bash

# Redis Pub/Sub Test Script
# This script tests the Redis pub/sub system without SseManager

echo "🧪 Redis Pub/Sub Test"
echo "===================="

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

# Function to get Redis status from Rails
get_rails_redis_status() {
    curl -s http://localhost:3000/dashboard/debug | jq -r '.redis_connections // empty'
}

# Function to trigger test pubsub
trigger_pubsub() {
    echo "  📡 Triggering test pub/sub..."
    response=$(curl -s http://localhost:3000/dashboard/trigger-test-pubsub)
    echo "  Response: $(echo $response | jq -r '.message')"
    echo "  Redis status: $(echo $response | jq -r '.redis_status')"
}

# Function to test SSE connection
test_sse_connection() {
    echo "  🔗 Testing SSE connection..."
    
    # Start SSE connection in background
    curl -s -N -H "Accept: text/event-stream" http://localhost:3000/dashboard/stream > /tmp/sse_test.log 2>&1 &
    SSE_PID=$!
    
    # Wait a moment for connection to establish
    sleep 2
    
    # Trigger pub/sub
    trigger_pubsub
    
    # Wait for message to be received
    sleep 3
    
    # Check if we received any data
    if [ -s /tmp/sse_test.log ]; then
        echo "  ✅ SSE connection working - received data"
        head -5 /tmp/sse_test.log
    else
        echo "  ❌ SSE connection failed - no data received"
    fi
    
    # Clean up
    kill $SSE_PID 2>/dev/null
    wait $SSE_PID 2>/dev/null
    rm -f /tmp/sse_test.log
}

# Main test sequence
echo "📋 Test Plan:"
echo "1. Check initial state"
echo "2. Test pub/sub without SSE clients"
echo "3. Test SSE connection with pub/sub"
echo "4. Check final state"
echo ""

# Initial setup
echo "🔧 Initial Setup"
echo "================"
if ! check_rails_status; then
    echo "💡 Please start the Rails server: cd dashboard && rails server"
    exit 1
fi

initial_redis_connections=$(get_redis_connections)
echo "📊 Initial Redis connections: $initial_redis_connections"
echo ""

# Test 1: Pub/sub without SSE clients
echo "🧪 Test 1: Pub/Sub Without SSE Clients"
echo "======================================"
trigger_pubsub
sleep 2

redis_connections=$(get_redis_connections)
echo "  Redis connections after pub/sub: $redis_connections"
echo ""

# Test 2: SSE connection with pub/sub
echo "🧪 Test 2: SSE Connection with Pub/Sub"
echo "======================================"
test_sse_connection
echo ""

# Test 3: Multiple SSE connections
echo "🧪 Test 3: Multiple SSE Connections"
echo "==================================="
echo "  🔗 Starting 3 SSE connections..."

# Start multiple SSE connections
for i in {1..3}; do
    curl -s -N -H "Accept: text/event-stream" http://localhost:3000/dashboard/stream > /tmp/sse_test_$i.log 2>&1 &
    SSE_PIDS[$i]=$!
done

# Wait for connections to establish
sleep 3

# Check connection count
redis_connections=$(get_redis_connections)
echo "  Redis connections with 3 SSE clients: $redis_connections"

# Trigger pub/sub
trigger_pubsub

# Wait for messages
sleep 3

# Check if messages were received
messages_received=0
for i in {1..3}; do
    if [ -s /tmp/sse_test_$i.log ]; then
        messages_received=$((messages_received + 1))
    fi
done

echo "  Messages received by $messages_received/3 clients"

# Clean up
for i in {1..3}; do
    kill ${SSE_PIDS[$i]} 2>/dev/null
    wait ${SSE_PIDS[$i]} 2>/dev/null
    rm -f /tmp/sse_test_$i.log
done

# Wait for cleanup
sleep 3

# Final check
echo ""
echo "📊 Final Results"
echo "================"
final_redis_connections=$(get_redis_connections)
total_change=$((final_redis_connections - initial_redis_connections))

echo "Initial Redis connections: $initial_redis_connections"
echo "Final Redis connections: $final_redis_connections"
echo "Total change: $total_change"

if [ $total_change -gt 2 ]; then
    echo "❌ Potential connection leak detected! (+$total_change connections)"
    echo "💡 Try manual cleanup:"
    echo "   curl http://localhost:3000/dashboard/cleanup-redis-connections"
elif [ $total_change -gt 0 ]; then
    echo "⚠️  Minor connection increase (+$total_change connections)"
    echo "💡 This might be normal, but monitor for continued growth"
else
    echo "✅ No significant connection leak detected"
fi

echo ""
echo "🔍 For detailed monitoring, run:"
echo "   ruby dashboard/scripts/monitor_redis_connections.rb"
echo ""
echo "📊 To check Rails debug info:"
echo "   curl http://localhost:3000/dashboard/debug | jq"
