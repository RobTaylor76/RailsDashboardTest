#!/bin/bash

# SSE/WebSocket Client Build Script
# This script builds the SSE/WebSocket client application

set -e  # Exit on any error

echo "🔨 SSE/WebSocket Client Build Script"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Go is installed
if ! command -v go &> /dev/null; then
    print_error "Go is not installed. Please install Go 1.21 or later."
    exit 1
fi

# Get Go version
GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
print_status "Go version: $GO_VERSION"

# Check if we're in the right directory
if [ ! -f "main.go" ]; then
    print_error "main.go not found. Please run this script from the goclient directory."
    exit 1
fi

# Parse command line arguments
CLEAN=false
INSTALL_DEPS=false
BUILD_ONLY=false
SHOW_HELP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN=true
            shift
            ;;
        --deps)
            INSTALL_DEPS=true
            shift
            ;;
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --help|-h)
            SHOW_HELP=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            print_error "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Show help
if [ "$SHOW_HELP" = true ]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --clean       Clean build artifacts before building"
    echo "  --deps        Install/update dependencies before building"
    echo "  --build-only  Only build, skip dependency management"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Normal build"
    echo "  $0 --clean           # Clean and build"
    echo "  $0 --deps            # Install deps and build"
    echo "  $0 --clean --deps    # Clean, install deps, and build"
    exit 0
fi

# Clean build artifacts if requested
if [ "$CLEAN" = true ]; then
    print_status "Cleaning build artifacts..."
    rm -f sse-client
    rm -rf vendor/
    print_success "Clean completed"
fi

# Install/update dependencies if requested or if go.mod is missing
if [ "$INSTALL_DEPS" = true ] || [ ! -f "go.mod" ]; then
    print_status "Installing/updating dependencies..."
    go mod tidy
    print_success "Dependencies updated"
fi

# Build the application
print_status "Building SSE/WebSocket client..."
BUILD_TIME=$(date '+%Y-%m-%d %H:%M:%S')
BUILD_VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "unknown")

# Build with version information
go build -o sse-client main.go

if [ $? -eq 0 ]; then
    print_success "Build completed successfully!"
    
    # Show build information
    echo ""
    print_status "Build Information:"
    echo "  Binary: $(pwd)/sse-client"
    echo "  Size: $(du -h sse-client | cut -f1)"
    echo "  Build Time: $BUILD_TIME"
    echo "  Version: $BUILD_VERSION"
    
    # Test if binary is executable
    if [ -x "sse-client" ]; then
        print_success "Binary is executable"
    else
        print_warning "Binary is not executable, fixing permissions..."
        chmod +x sse-client
    fi
    
    # Show usage information
    echo ""
    print_status "Usage Examples:"
    echo "  ./sse-client --help                    # Show help"
    echo "  ./sse-client -protocol sse -clients 5  # Test SSE with 5 clients"
    echo "  ./sse-client -protocol websocket -debug # Test WebSocket with debug"
    echo "  ./test.sh                              # Run interactive test script"
    
else
    print_error "Build failed!"
    exit 1
fi

print_success "Build script completed successfully! 🎉"
