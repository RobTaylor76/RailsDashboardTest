#!/bin/bash

# Go SSE Server Run Script

# Default port
DEFAULT_PORT=3001

# Function to show usage
show_usage() {
    echo "🚀 Go SSE Server Runner"
    echo "======================="
    echo ""
    echo "Usage: $0 [PORT]"
    echo ""
    echo "Arguments:"
    echo "  PORT    Port number to run the server on (default: $DEFAULT_PORT)"
    echo ""
    echo "Environment Variables:"
    echo "  LOG_LEVEL    Logging level: debug, info, warn, error (default: info)"
    echo ""
    echo "Examples:"
    echo "  $0              # Run on port $DEFAULT_PORT with info logging"
    echo "  $0 3002         # Run on port 3002 with info logging"
    echo "  $0 8080         # Run on port 8080 with info logging"
    echo "  LOG_LEVEL=debug $0  # Run with debug logging"
    echo "  LOG_LEVEL=warn $0   # Run with warning logging only"
    echo ""
    echo "Endpoints:"
    echo "  SSE Stream:     http://localhost:\$PORT/dashboard/stream"
    echo "  WebSocket:      ws://localhost:\$PORT/cable"
    echo "  Debug:          http://localhost:\$PORT/dashboard/debug"
    echo "  Health Check:   http://localhost:\$PORT/health"
}

# Function to check if port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "❌ Port $port is already in use"
        echo "💡 Try a different port or stop the process using port $port"
        return 1
    fi
    return 0
}

# Function to build server if needed
build_server() {
    if [ ! -f "./sse-server" ]; then
        echo "🔨 Building server..."
        ./build.sh
        if [ $? -ne 0 ]; then
            echo "❌ Failed to build server"
            exit 1
        fi
    fi
}

# Function to start server
start_server() {
    local port=$1
    
    # Set default logging level if not already set
    if [ -z "$LOG_LEVEL" ]; then
        export LOG_LEVEL=info
    fi
    
    echo "🚀 Starting Go SSE/WebSocket Server on port $port"
    echo "📡 SSE endpoint: http://localhost:$port/dashboard/stream"
    echo "🔌 WebSocket endpoint: ws://localhost:$port/cable"
    echo "🔍 Debug endpoint: http://localhost:$port/dashboard/debug"
    echo "💚 Health check: http://localhost:$port/health"
    echo "📝 Log level: $LOG_LEVEL"
    echo ""
    echo "Press Ctrl+C to stop the server"
    echo ""
    
    # Set environment variable for port
    export PORT=$port
    
    # Start the server
    ./sse-server
}

# Parse command line arguments
PORT=${1:-$DEFAULT_PORT}

# Show help if requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

# Validate port number
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo "❌ Invalid port number: $PORT"
    echo "💡 Port must be a number between 1 and 65535"
    exit 1
fi

# Check if port is available
if ! check_port $PORT; then
    exit 1
fi

# Build server if needed
build_server

# Start server
start_server $PORT
