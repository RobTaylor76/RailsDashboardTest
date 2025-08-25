#!/bin/bash

# Redis Connection Leak Test Script
# This script helps test if Redis connections are being properly managed

echo "🧪 Redis Connection Leak Test"
echo "============================="

# Check if required tools are available
if ! command -v redis-cli &> /dev/null; then
    echo "❌ redis-cli is not installed. Please install Redis CLI tools."
    exit 1
fi

# Function to get Redis connection count
get_redis_connections() {
    redis-cli info clients | grep "connected_clients:" | cut -d: -f2 | tr -d '\r'
}

# Function to run Go client test
run_client_test() {
    local num_clients=$1
    local test_name=$2
    
    echo "🚀 Running $test_name with $num_clients clients..."
    
    # Get connection count before test
    connections_before=$(get_redis_connections)
    echo "  📊 Redis connections before: $connections_before"
    
    # Run the test
    cd dashboard/goclient
    timeout 30s ./test.sh <<< "2
$num_clients" > /dev/null 2>&1
    
    # Wait a moment for connections to settle
    sleep 3
    
    # Get connection count after test
    connections_after=$(get_redis_connections)
    echo "  📊 Redis connections after: $connections_after"
    
    # Calculate difference
    local diff=$((connections_after - connections_before))
    if [ $diff -gt 0 ]; then
        echo "  ⚠️  Connection increase: +$diff"
    elif [ $diff -lt 0 ]; then
        echo "  ✅ Connection decrease: $diff"
    else
        echo "  ✅ No connection change"
    fi
    
    echo ""
    cd ../..
}

# Function to check Rails app status
check_rails_status() {
    echo "🔍 Checking Rails app status..."
    
    if curl -s http://localhost:3000/dashboard/debug > /dev/null 2>&1; then
        echo "  ✅ Rails app is running"
        
        # Get Redis connection info from Rails
        redis_info=$(curl -s http://localhost:3000/dashboard/debug | jq -r '.redis_connections // empty')
        if [ ! -z "$redis_info" ]; then
            echo "  📊 Rails Redis status: $redis_info"
        fi
    else
        echo "  ❌ Rails app is not running on localhost:3000"
        echo "  💡 Please start the Rails server: cd dashboard && rails server"
        exit 1
    fi
    echo ""
}

# Main test sequence
echo "📋 Test Plan:"
echo "1. Check initial Redis connections"
echo "2. Run single client test"
echo "3. Run multiple client test (5 clients)"
echo "4. Run load test (10 clients)"
echo "5. Check final connection count"
echo ""

# Initial setup
echo "🔧 Initial Setup"
echo "================"
check_rails_status

initial_connections=$(get_redis_connections)
echo "📊 Initial Redis connections: $initial_connections"
echo ""

# Test 1: Single client
echo "🧪 Test 1: Single Client"
echo "========================"
run_client_test 1 "Single client test"

# Test 2: Multiple clients
echo "🧪 Test 2: Multiple Clients"
echo "==========================="
run_client_test 5 "Multiple clients test"

# Test 3: Load test
echo "🧪 Test 3: Load Test"
echo "===================="
run_client_test 10 "Load test"

# Final check
echo "📊 Final Results"
echo "================"
final_connections=$(get_redis_connections)
total_change=$((final_connections - initial_connections))

echo "Initial connections: $initial_connections"
echo "Final connections: $final_connections"
echo "Total change: $total_change"

if [ $total_change -gt 5 ]; then
    echo "❌ Potential connection leak detected! (+$total_change connections)"
    echo "💡 Check the Rails logs for Redis connection issues"
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
