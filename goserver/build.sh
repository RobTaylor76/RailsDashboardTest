#!/bin/bash

# Go SSE Server Build Script

echo "🔨 Building Go SSE Server"
echo "========================="

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "❌ Go is not installed. Please install Go 1.21 or later."
    exit 1
fi

# Build the server
echo "📦 Building server..."
go build -o sse-server main.go

if [ $? -eq 0 ]; then
    echo "✅ Server built successfully!"
    echo "🚀 Run with: ./sse-server"
    echo "📡 SSE endpoint: http://localhost:3001/dashboard/stream"
    echo "🔍 Debug endpoint: http://localhost:3001/dashboard/debug"
    echo "🧪 Test endpoint: http://localhost:3001/dashboard/trigger-test"
else
    echo "❌ Build failed!"
    exit 1
fi
