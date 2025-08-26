#!/bin/bash

# Go SSE Server Test Script

echo "🧪 Testing Go SSE Server"
echo "========================"

# Function to check if Go server is running
check_server() {
    if curl -s http://localhost:3001/health > /dev/null 2>&1; then
        echo "  ✅ Go server is running"
        return 0
    else
        echo "  ❌ Go server is not running"
        return 1
    fi
}

# Function to build and start server
start_server() {
    echo "🔨 Building Go server..."
    cd dashboard/goserver
    ./build.sh
    if [ $? -ne 0 ]; then
        echo "❌ Failed to build server"
        exit 1
    fi
    
    echo "🚀 Starting Go server..."
    ./sse-server > /tmp/goserver.log 2>&1 &
    SERVER_PID=$!
    cd ../..
    
    # Wait for server to start
    echo "⏳ Waiting for server to start..."
    for i in {1..10}; do
        if check_server; then
            echo "✅ Server started successfully (PID: $SERVER_PID)"
            return 0
        fi
        sleep 1
    done
    
    echo "❌ Server failed to start"
    return 1
}

# Function to test with Go client
test_with_client() {
    echo "🔗 Testing with Go client..."
    
    # Build Go client if needed
    if [ ! -f "dashboard/goclient/sse-client" ]; then
        echo "🔨 Building Go client..."
        cd dashboard/goclient
        go build -o sse-client main.go
        cd ../..
    fi
    
    # Test with Go client
    cd dashboard/goclient
    timeout 45s ./sse-client -url "http://localhost:3001/dashboard/stream" -clients 1 -debug > /tmp/goclient_test.log 2>&1 &
    CLIENT_PID=$!
    cd ../..
    
    echo "  🔗 Go client started (PID: $CLIENT_PID)"
    echo "  ⏳ Waiting for test to complete..."
    
    # Wait for test
    sleep 40
    
    # Check results
    if grep -q "💓 Heartbeat" /tmp/goclient_test.log; then
        echo "  ✅ Heartbeats detected!"
        echo "  📊 Heartbeat log:"
        grep "💓 Heartbeat" /tmp/goclient_test.log | head -3
    else
        echo "  ❌ No heartbeats detected"
        echo "  🔍 Debug log:"
        tail -10 /tmp/goclient_test.log
    fi
    
    # Check for data messages
    if grep -q "📡 Message" /tmp/goclient_test.log; then
        echo "  ✅ Data messages detected!"
    else
        echo "  ❌ No data messages detected"
    fi
    
    # Clean up
    kill $CLIENT_PID 2>/dev/null
    wait $CLIENT_PID 2>/dev/null
    rm -f /tmp/goclient_test.log
}

# Function to test manual SSE connection
test_manual_sse() {
    echo "🔗 Testing manual SSE connection..."
    
    # Start SSE connection
    curl -s -N -H "Accept: text/event-stream" http://localhost:3001/dashboard/stream > /tmp/sse_test.log 2>&1 &
    SSE_PID=$!
    
    echo "  🔗 SSE connection started (PID: $SSE_PID)"
    echo "  ⏳ Waiting for heartbeats..."
    
    # Wait for heartbeats
    sleep 35
    
    # Check what we received
    if [ -s /tmp/sse_test.log ]; then
        echo "  ✅ SSE data received:"
        head -10 /tmp/sse_test.log
    else
        echo "  ❌ No SSE data received"
    fi
    
    # Clean up
    kill $SSE_PID 2>/dev/null
    wait $SSE_PID 2>/dev/null
    rm -f /tmp/sse_test.log
}

# Function to test trigger endpoint
test_trigger() {
    echo "🧪 Testing trigger endpoint..."
    
    response=$(curl -s http://localhost:3001/dashboard/trigger-test)
    echo "  📡 Trigger response: $response"
    
    # Wait a moment for broadcast
    sleep 2
}

# Main test sequence
echo "📋 Test Plan:"
echo "1. Build and start Go server"
echo "2. Test with Go client"
echo "3. Test manual SSE connection"
echo "4. Test trigger endpoint"
echo ""

# Start server
if ! start_server; then
    exit 1
fi

# Test with Go client
echo ""
echo "🧪 Go Client Test"
echo "================"
test_with_client

# Test manual SSE
echo ""
echo "🔗 Manual SSE Test"
echo "================="
test_manual_sse

# Test trigger
echo ""
echo "🧪 Trigger Test"
echo "=============="
test_trigger

# Clean up
echo ""
echo "🧹 Cleaning up..."
kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null
rm -f /tmp/goserver.log

echo ""
echo "📊 Test Summary"
echo "==============="
echo "✅ Go SSE server test completed"
echo "💡 Server features:"
echo "   - SSE stream endpoint: /dashboard/stream"
echo "   - Heartbeats every 30 seconds"
echo "   - Test trigger: /dashboard/trigger-test"
echo "   - Debug endpoint: /dashboard/debug"
