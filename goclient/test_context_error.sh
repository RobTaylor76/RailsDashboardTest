#!/bin/bash

echo "🧪 Testing context cancellation error handling..."
echo ""

echo "This test will start an SSE client and immediately send SIGINT"
echo "Expected behavior: Should show 'SSE stream closed due to context cancellation' instead of 'Scanner error: context canceled'"
echo ""

# Start the client
echo "🚀 Starting SSE client..."
./sse-client -clients=1 -url="http://localhost:3000/dashboard/stream" -log-level=debug &
CLIENT_PID=$!

# Wait a very short time then send SIGINT
sleep 0.1
echo "🛑 Sending SIGINT to client (PID: $CLIENT_PID)..."
kill -INT $CLIENT_PID

# Wait for client to finish
echo "⏳ Waiting for client to shutdown..."
wait $CLIENT_PID
EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Test PASSED: Client handled context cancellation gracefully"
else
    echo "❌ Test FAILED: Client did not handle context cancellation properly (exit code: $EXIT_CODE)"
fi

echo ""
echo "🎉 Context cancellation test completed!"

