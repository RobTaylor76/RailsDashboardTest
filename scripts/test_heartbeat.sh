#!/bin/bash

# Heartbeat Test Script
# This script tests the heartbeat functionality between Rails and Go client

echo "💓 Heartbeat Test"
echo "================="

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

# Function to build Go client
build_client() {
    echo "🔨 Building Go client..."
    cd dashboard/goclient
    go build -o sse-client main.go
    if [ $? -eq 0 ]; then
        echo "  ✅ Go client built successfully"
    else
        echo "  ❌ Failed to build Go client"
        exit 1
    fi
    cd ../..
}

# Function to test heartbeat with debug logging
test_heartbeat() {
    echo "🧪 Testing heartbeat with debug logging..."
    
    # Start Go client with debug mode
    cd dashboard/goclient
    timeout 45s ./sse-client -clients 1 -debug > /tmp/heartbeat_test.log 2>&1 &
    CLIENT_PID=$!
    cd ../..
    
    echo "  🔗 Go client started (PID: $CLIENT_PID)"
    echo "  ⏳ Waiting for heartbeats..."
    
    # Wait a moment for connection to establish
    sleep 5
    
    # Check if we received any heartbeats
    if grep -q "💓 Heartbeat" /tmp/heartbeat_test.log; then
        echo "  ✅ Heartbeats detected!"
        echo "  📊 Heartbeat log:"
        grep "💓 Heartbeat" /tmp/heartbeat_test.log | head -3
    else
        echo "  ❌ No heartbeats detected"
        echo "  🔍 Debug log:"
        tail -10 /tmp/heartbeat_test.log
    fi
    
    # Check for raw SSE lines
    if grep -q "🔍 Raw SSE line" /tmp/heartbeat_test.log; then
        echo "  📝 Raw SSE lines detected:"
        grep "🔍 Raw SSE line" /tmp/heartbeat_test.log | head -5
    fi
    
    # Clean up
    kill $CLIENT_PID 2>/dev/null
    wait $CLIENT_PID 2>/dev/null
    rm -f /tmp/heartbeat_test.log
}

# Function to test SSE connection manually
test_sse_manual() {
    echo "🔗 Testing SSE connection manually..."
    
    # Start SSE connection and capture output
    curl -s -N -H "Accept: text/event-stream" http://localhost:3000/dashboard/stream > /tmp/sse_raw.log 2>&1 &
    SSE_PID=$!
    
    echo "  🔗 SSE connection started (PID: $SSE_PID)"
    echo "  ⏳ Waiting for heartbeats..."
    
    # Wait for heartbeats
    sleep 35
    
    # Check what we received
    if [ -s /tmp/sse_raw.log ]; then
        echo "  ✅ SSE data received:"
        head -10 /tmp/sse_raw.log
    else
        echo "  ❌ No SSE data received"
    fi
    
    # Clean up
    kill $SSE_PID 2>/dev/null
    wait $SSE_PID 2>/dev/null
    rm -f /tmp/sse_raw.log
}

# Main test sequence
echo "📋 Test Plan:"
echo "1. Check Rails app status"
echo "2. Build Go client"
echo "3. Test heartbeat with debug logging"
echo "4. Test SSE connection manually"
echo ""

# Initial setup
echo "🔧 Initial Setup"
echo "================"
if ! check_rails_status; then
    echo "💡 Please start the Rails server: cd dashboard && rails server"
    exit 1
fi

# Build client
build_client

# Test heartbeat
echo ""
echo "🧪 Heartbeat Test"
echo "================"
test_heartbeat

# Test SSE manually
echo ""
echo "🔗 Manual SSE Test"
echo "================="
test_sse_manual

echo ""
echo "📊 Test Summary"
echo "==============="
echo "✅ Heartbeat test completed"
echo "💡 If no heartbeats were detected, check:"
echo "   - Rails server logs for heartbeat sending"
echo "   - Go client debug output for raw SSE lines"
echo "   - Network connectivity between client and server"
