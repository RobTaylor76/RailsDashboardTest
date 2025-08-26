#!/bin/bash

# SSE/WebSocket Client Test Script
# This script demonstrates different ways to use the SSE/WebSocket client

echo "🚀 SSE/WebSocket Client Test Script"
echo "==================================="

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "❌ Go is not installed. Please install Go 1.21 or later."
    exit 1
fi

# Check if the binary exists, if not build it
if [ ! -f "./sse-client" ]; then
    echo "🔨 Building SSE/WebSocket client..."
    ./build.sh --deps
fi

# Get port number
read -p "Enter port number (default: 3000): " port
if [ -z "$port" ]; then
    port=3000
fi

# Get protocol
echo ""
echo "📡 Select protocol:"
echo "1. SSE (Server-Sent Events)"
echo "2. WebSocket"
read -p "Select protocol (1-2, default: 1): " protocol_choice

case $protocol_choice in
    2)
        protocol="websocket"
        endpoint="/cable"
        echo "🔌 Using WebSocket protocol"
        ;;
    *)
        protocol="sse"
        endpoint="/dashboard/stream"
        echo "📡 Using SSE protocol"
        ;;
esac

# Get log level
echo ""
echo "📝 Select log level:"
echo "1. Error (errors only)"
echo "2. Warn (warnings and errors)"
echo "3. Info (default - general information)"
echo "4. Debug (detailed debugging information)"
read -p "Select log level (1-4, default: 3): " log_level_choice

case $log_level_choice in
    1)
        log_level="error"
        echo "🔴 Using Error log level"
        ;;
    2)
        log_level="warn"
        echo "🟡 Using Warn log level"
        ;;
    4)
        log_level="debug"
        echo "🔵 Using Debug log level"
        ;;
    *)
        log_level="info"
        echo "🟢 Using Info log level (default)"
        ;;
esac

# Construct the correct URL based on protocol
if [ "$protocol" = "websocket" ]; then
    base_url="ws://localhost:$port"
else
    base_url="http://localhost:$port"
fi

echo ""
echo "📋 Available test scenarios:"
echo "1. Single client test"
echo "2. Multiple clients test"
echo "3. Load test with stats"
echo "4. Custom URL test"
echo "5. Exit"
echo ""

read -p "Select a test scenario (1-5): " choice

case $choice in
    1)
        echo "🧪 Running single $protocol client test on port $port..."
        ./sse-client -url "$base_url$endpoint" -protocol "$protocol" -log-level "$log_level"
        ;;
    2)
        read -p "Enter number of clients (default: 5): " num_clients
        if [ -z "$num_clients" ]; then
            num_clients=5
        fi
        echo "🧪 Running multiple $protocol clients test ($num_clients clients) on port $port..."
        ./sse-client -url "$base_url$endpoint" -protocol "$protocol" -clients "$num_clients" -log-level "$log_level"
        ;;
    3)
        read -p "Enter number of clients (default: 20): " num_clients
        if [ -z "$num_clients" ]; then
            num_clients=20
        fi
        echo "🧪 Running $protocol load test ($num_clients clients with stats) on port $port..."
        ./sse-client -url "$base_url$endpoint" -protocol "$protocol" -clients "$num_clients" -stats -log-level "$log_level"
        ;;
    4)
        read -p "Enter custom URL (default: $base_url$endpoint): " custom_url
        if [ -z "$custom_url" ]; then
            custom_url="$base_url$endpoint"
        fi
        read -p "Enter number of clients (default: 5): " num_clients
        if [ -z "$num_clients" ]; then
            num_clients=5
        fi
        read -p "Enable stats? (y/n, default: n): " enable_stats
        stats_flag=""
        if [[ "$enable_stats" =~ ^[Yy]$ ]]; then
            stats_flag="-stats"
        fi
        echo "🧪 Running custom $protocol test with URL: $custom_url and $num_clients clients..."
        ./sse-client -url "$custom_url" -protocol "$protocol" -clients "$num_clients" $stats_flag -log-level "$log_level"
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
