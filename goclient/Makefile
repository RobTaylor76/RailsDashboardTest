# SSE Client Makefile

.PHONY: build clean test help run

# Default target
all: build

# Build the SSE client
build:
	@echo "🔨 Building SSE client..."
	go build -o sse-client main.go
	@echo "✅ Build complete!"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -f sse-client
	@echo "✅ Clean complete!"

# Run tests
test:
	@echo "🧪 Running tests..."
	go test ./...
	@echo "✅ Tests complete!"

# Run with default settings
run: build
	@echo "🚀 Running SSE client with default settings..."
	./sse-client

# Run with 5 clients
run-5: build
	@echo "🚀 Running SSE client with 5 clients..."
	./sse-client -clients 5

# Run load test with 20 clients and stats
load-test: build
	@echo "🚀 Running load test with 20 clients..."
	./sse-client -clients 20 -stats

# Run with custom settings
run-custom: build
	@echo "🚀 Running SSE client with custom settings..."
	@read -p "Enter number of clients: " clients; \
	read -p "Enter URL (default: http://localhost:3000/dashboard/stream): " url; \
	if [ -z "$$url" ]; then url="http://localhost:3000/dashboard/stream"; fi; \
	./sse-client -clients $$clients -url "$$url" -stats

# Show help
help:
	@echo "SSE Client Makefile"
	@echo "=================="
	@echo ""
	@echo "Available targets:"
	@echo "  build       - Build the SSE client binary"
	@echo "  clean       - Remove build artifacts"
	@echo "  test        - Run tests"
	@echo "  run         - Run with default settings (1 client)"
	@echo "  run-5       - Run with 5 clients"
	@echo "  load-test   - Run load test with 20 clients and stats"
	@echo "  run-custom  - Run with custom settings (interactive)"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make run-5"
	@echo "  make load-test"
	@echo "  make run-custom"
