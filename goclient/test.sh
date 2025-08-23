#!/bin/bash

# SSE Client Test Script
# This script demonstrates different ways to use the SSE client

echo "🚀 SSE Client Test Script"
echo "=========================="

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "❌ Go is not installed. Please install Go 1.21 or later."
    exit 1
fi

# Check if the binary exists, if not build it
if [ ! -f "./sse-client" ]; then
    echo "🔨 Building SSE client..."
    go build -o sse-client main.go
fi

echo ""
echo "📋 Available test scenarios:"
echo "1. Single client test"
echo "2. Multiple clients test (5 clients)"
echo "3. Load test (20 clients with stats)"
echo "4. Custom URL test"
echo "5. Exit"
echo ""

read -p "Select a test scenario (1-5): " choice

case $choice in
    1)
        echo "🧪 Running single client test..."
        ./sse-client
        ;;
    2)
        echo "🧪 Running multiple clients test (5 clients)..."
        ./sse-client -clients 5
        ;;
    3)
        echo "🧪 Running load test (20 clients with stats)..."
        ./sse-client -clients 20 -stats
        ;;
    4)
        read -p "Enter custom URL (default: http://localhost:3000/dashboard/stream): " custom_url
        if [ -z "$custom_url" ]; then
            custom_url="http://localhost:3000/dashboard/stream"
        fi
        read -p "Enter number of clients (default: 5): " num_clients
        if [ -z "$num_clients" ]; then
            num_clients=5
        fi
        echo "🧪 Running custom test with URL: $custom_url and $num_clients clients..."
        ./sse-client -url "$custom_url" -clients "$num_clients" -stats
        ;;
    5)
        echo "👋 Goodbye!"
        exit 0
        ;;
    *)
        echo "❌ Invalid choice. Please select 1-5."
        exit 1
        ;;
esac
