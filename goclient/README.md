# SSE Load Testing Client

A Go program for testing Server-Sent Events (SSE) endpoints with multiple concurrent connections.

## Features

- Create multiple concurrent SSE connections to test server scaling
- Automatic reconnection on connection failures
- Real-time message parsing and display
- Statistics tracking (messages received, errors, etc.)
- Graceful shutdown with Ctrl+C
- Configurable target URL and number of clients

## Usage

### Basic Usage

```bash
# Run with default settings (1 client, localhost:3000)
go run main.go

# Run with multiple clients
go run main.go -clients 10

# Specify a different URL
go run main.go -url http://localhost:3000/dashboard/stream -clients 5

# Enable periodic statistics reporting
go run main.go -clients 20 -stats
```

### Command Line Options

- `-url`: SSE endpoint URL (default: `http://localhost:3000/dashboard/stream`)
- `-clients`: Number of concurrent SSE clients (default: `1`)
- `-stats`: Show periodic statistics every 10 seconds (default: `false`)

### Examples

```bash
# Test with 5 clients
go run main.go -clients 5

# Test with 50 clients and show stats
go run main.go -clients 50 -stats

# Test against a remote server
go run main.go -url https://your-server.com/dashboard/stream -clients 10

# Build and run the binary
go build -o sse-client main.go
./sse-client -clients 25 -stats
```

## Output

The program displays:
- Connection status for each client
- Parsed SSE messages with formatted dashboard data
- Error messages for failed connections or parsing issues
- Periodic statistics (if enabled)
- Final summary statistics

### Sample Output

```
🚀 Starting SSE load test with 5 clients
📡 Target URL: http://localhost:3000/dashboard/stream
[Client 1] ✅ Connected to SSE stream at http://localhost:3000/dashboard/stream
[Client 2] ✅ Connected to SSE stream at http://localhost:3000/dashboard/stream
[Client 3] ✅ Connected to SSE stream at http://localhost:3000/dashboard/stream
[Client 4] ✅ Connected to SSE stream at http://localhost:3000/dashboard/stream
[Client 5] ✅ Connected to SSE stream at http://localhost:3000/dashboard/stream

[Client 1] 📡 Message #1 received at 14:30:25
   Status: online (Uptime: 2h 15m 30s)
   CPU: 45% | Memory: 67% | Disk: 52% | Network: 12 MB/s
   Response Time: 125ms
   Latest Activity: 14:30:20 - System check completed successfully (info)

[Client 2] 📡 Message #1 received at 14:30:25
   Status: online (Uptime: 2h 15m 30s)
   CPU: 45% | Memory: 67% | Disk: 52% | Network: 12 MB/s
   Response Time: 125ms
   Latest Activity: 14:30:20 - System check completed successfully (info)

📊 Stats: 5 clients, 10 messages, 0 errors
```

## Requirements

- Go 1.21 or later
- Network access to the SSE endpoint
- The target Rails server should be running with SSE enabled

## Building

```bash
# Build for current platform
go build -o sse-client main.go

# Build for different platforms
GOOS=linux GOARCH=amd64 go build -o sse-client-linux main.go
GOOS=darwin GOARCH=amd64 go build -o sse-client-mac main.go
GOOS=windows GOARCH=amd64 go build -o sse-client.exe main.go
```

## Testing Your Rails SSE Server

1. Start your Rails server:
   ```bash
   cd dashboard
   rails server
   ```

2. Run the SSE client:
   ```bash
   cd goclient
   go run main.go -clients 10 -stats
   ```

3. Monitor the output to see how your server handles multiple concurrent SSE connections.

## Notes

- The program automatically handles reconnections if the connection is lost
- Each client runs in its own goroutine for true concurrency
- Messages are parsed as JSON and displayed in a readable format
- Use Ctrl+C to gracefully shut down all connections
- The program tracks statistics per client and globally
