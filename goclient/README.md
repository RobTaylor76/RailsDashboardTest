# SSE/WebSocket Client

A Go-based load testing client for SSE (Server-Sent Events) and WebSocket connections. This client can test both the Rails SSE stream endpoint and the ActionCable WebSocket implementation.

## Features

- **Dual Protocol Support**: Test both SSE and WebSocket connections
- **Load Testing**: Support for multiple concurrent clients
- **Real-time Statistics**: Monitor connection status, messages, and errors
- **Debug Mode**: Verbose logging for troubleshooting
- **Cross-Process Testing**: Test WebSocket connections from background jobs
- **Graceful Shutdown**: Clean connection handling and statistics reporting

## Prerequisites

- Go 1.21 or later
- Git (for version information)

## Quick Start

### 1. Build the Client

```bash
# Normal build
./build.sh

# Clean build (removes old binary)
./build.sh --clean

# Install dependencies and build
./build.sh --deps

# Show build options
./build.sh --help
```

### 2. Run Tests

```bash
# Interactive test script
./test.sh

# Direct command line usage
./sse-client --help
```

## Usage Examples

### SSE Testing

```bash
# Single SSE client with debug
./sse-client -url "http://localhost:3000/dashboard/stream" -protocol sse -debug

# Multiple SSE clients with statistics
./sse-client -url "http://localhost:3000/dashboard/stream" -protocol sse -clients 10 -stats

# Test Go server SSE endpoint
./sse-client -url "http://localhost:3001/dashboard/stream" -protocol sse -clients 5
```

### WebSocket Testing

```bash
# Single WebSocket client with debug
./sse-client -url "ws://localhost:3000/cable" -protocol websocket -debug

# Multiple WebSocket clients
./sse-client -url "ws://localhost:3000/cable" -protocol websocket -clients 10 -stats

# Test with custom timeout
./sse-client -url "ws://localhost:3000/cable" -protocol websocket -timeout 30s
```

### Interactive Testing

```bash
./test.sh
```

The interactive script will prompt for:
- Port number (default: 3000)
- Protocol selection (SSE or WebSocket)
- Test scenario (single client, multiple clients, load test, custom)

## Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `-url` | Target URL for connections | `http://localhost:3000/dashboard/stream` |
| `-protocol` | Protocol to use: `sse` or `websocket` | `sse` |
| `-clients` | Number of concurrent clients | `1` |
| `-stats` | Show periodic statistics | `false` |
| `-timeout` | Connection timeout | `60s` |
| `-debug` | Enable debug logging | `false` |

## Build Script Options

| Option | Description |
|--------|-------------|
| `--clean` | Clean build artifacts before building |
| `--deps` | Install/update dependencies before building |
| `--build-only` | Only build, skip dependency management |
| `--help`, `-h` | Show help message |

## Architecture

### SSE Client
- Uses HTTP/1.1 streaming connections
- Handles SSE format messages (`data:`, `event:`, `: heartbeat`)
- Supports reconnection and error recovery
- Monitors connection health with heartbeats

### WebSocket Client
- Uses WebSocket protocol for bidirectional communication
- Connects to ActionCable endpoint (`/cable`)
- Handles JSON message format
- Supports ping/pong for connection health

### Statistics Tracking
- Total connections and messages
- Heartbeat and error counts
- Connection success/failure rates
- Real-time performance metrics

## Testing Scenarios

### 1. Single Client Test
- Basic connectivity verification
- Message format validation
- Debug output for troubleshooting

### 2. Multiple Clients Test
- Concurrent connection handling
- Load distribution testing
- Connection stability verification

### 3. Load Test with Statistics
- Performance benchmarking
- Resource usage monitoring
- Scalability testing
- Periodic statistics reporting

### 4. Custom URL Test
- Testing different endpoints
- Protocol comparison
- Custom configuration testing

## Integration with Rails Dashboard

### SSE Endpoints
- **Rails Server**: `http://localhost:3000/dashboard/stream`
- **Go Server**: `http://localhost:3001/dashboard/stream`

### WebSocket Endpoints
- **ActionCable**: `ws://localhost:3000/cable`

### Background Job Testing
1. Start the client: `./sse-client -protocol websocket -debug`
2. Trigger background job: `curl http://localhost:3000/dashboard/trigger-test-pubsub`
3. Verify WebSocket receives broadcast message

## Troubleshooting

### Common Issues

1. **Connection Refused**
   - Verify server is running on correct port
   - Check firewall settings
   - Ensure correct protocol (http vs ws)

2. **WebSocket Handshake Failed**
   - Verify ActionCable is properly configured
   - Check CORS settings
   - Ensure Redis adapter is configured

3. **No Messages Received**
   - Check server logs for errors
   - Verify background jobs are running
   - Test with debug mode enabled

### Debug Mode
Enable debug logging to see:
- Raw message content
- Connection attempts
- Error details
- Protocol-specific information

```bash
./sse-client -debug -protocol websocket
```

## Performance Considerations

- **Memory Usage**: Each client maintains its own connection
- **CPU Usage**: Minimal for idle connections, increases with message volume
- **Network**: Bandwidth scales with number of clients and message frequency
- **File Descriptors**: One per client connection

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with both SSE and WebSocket protocols
5. Submit a pull request

## License

This project is part of the Rails Dashboard system.
