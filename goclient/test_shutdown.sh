#!/bin/bash

echo "🧪 Testing graceful shutdown functionality..."
echo ""

# Test 1: Start with many clients and interrupt quickly
echo "Test 1: Starting 10 clients and interrupting after 2 seconds..."
echo "Expected: Should shutdown gracefully within 30 seconds"
echo ""

# Start the client with many connections
./sse-client -clients=10 -url="http://localhost:3000/dashboard/stream" -log-level=info &
CLIENT_PID=$!

# Wait 2 seconds then send SIGINT
sleep 2
echo "🛑 Sending SIGINT to client (PID: $CLIENT_PID)..."
kill -INT $CLIENT_PID

# Wait for client to finish
echo "⏳ Waiting for client to shutdown..."
wait $CLIENT_PID
EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Test 1 PASSED: Client shutdown gracefully"
else
    echo "❌ Test 1 FAILED: Client did not shutdown properly (exit code: $EXIT_CODE)"
fi

echo ""
echo "Test 2: Starting 5 clients and interrupting during startup..."
echo "Expected: Should stop starting new clients and shutdown gracefully"
echo ""

# Start the client with moderate connections
./sse-client -clients=5 -url="http://localhost:3000/dashboard/stream" -log-level=debug &
CLIENT_PID=$!

# Wait 500ms then send SIGINT (during startup)
sleep 0.5
echo "🛑 Sending SIGINT to client (PID: $CLIENT_PID)..."
kill -INT $CLIENT_PID

# Wait for client to finish
echo "⏳ Waiting for client to shutdown..."
wait $CLIENT_PID
EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Test 2 PASSED: Client shutdown gracefully during startup"
else
    echo "❌ Test 2 FAILED: Client did not shutdown properly (exit code: $EXIT_CODE)"
fi

echo ""
echo "🎉 Shutdown tests completed!"

