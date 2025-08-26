package main

import (
	"bufio"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/gorilla/websocket"
)

// LogLevel represents the logging level
type LogLevel int

const (
	DEBUG LogLevel = iota
	INFO
	WARN
	ERROR
)

// Logger represents a structured logger
type Logger struct {
	level LogLevel
}

// NewLogger creates a new logger with the specified level
func NewLogger(level string) *Logger {
	var logLevel LogLevel
	switch strings.ToLower(level) {
	case "debug":
		logLevel = DEBUG
	case "info":
		logLevel = INFO
	case "warn":
		logLevel = WARN
	case "error":
		logLevel = ERROR
	default:
		logLevel = INFO
	}
	return &Logger{level: logLevel}
}

// shouldLog checks if the message should be logged at the current level
func (l *Logger) shouldLog(level LogLevel) bool {
	return level >= l.level
}

// Debug logs a debug message
func (l *Logger) Debug(format string, args ...interface{}) {
	if l.shouldLog(DEBUG) {
		log.Printf("[DEBUG] "+format, args...)
	}
}

// Info logs an info message
func (l *Logger) Info(format string, args ...interface{}) {
	if l.shouldLog(INFO) {
		log.Printf("[INFO] "+format, args...)
	}
}

// Warn logs a warning message
func (l *Logger) Warn(format string, args ...interface{}) {
	if l.shouldLog(WARN) {
		log.Printf("[WARN] "+format, args...)
	}
}

// Error logs an error message
func (l *Logger) Error(format string, args ...interface{}) {
	if l.shouldLog(ERROR) {
		log.Printf("[ERROR] "+format, args...)
	}
}

// DashboardData represents the structure of the SSE messages
type DashboardData struct {
	SystemStatus struct {
		Status    string `json:"status"`
		Uptime    string `json:"uptime"`
		LastCheck string `json:"last_check"`
		Message   string `json:"message"`
	} `json:"system_status"`
	Metrics struct {
		CPU          string `json:"cpu"`
		Memory       string `json:"memory"`
		Disk         string `json:"disk"`
		Network      string `json:"network"`
		ResponseTime string `json:"response_time"`
	} `json:"metrics"`
	Activities []struct {
		Time     string `json:"time"`
		Message  string `json:"message"`
		Level    string `json:"level"`
		CSSClass string `json:"css_class"`
	} `json:"activities"`
	Timestamp string `json:"timestamp"`
}

// SSEClient represents a single SSE connection
type SSEClient struct {
	ID         int
	URL        string
	Client     *http.Client
	Messages   int
	Heartbeats int
	Errors     int
	Connected  bool
	logger     *Logger
	mu         sync.Mutex
}

// WebSocketClient represents a single WebSocket connection
type WebSocketClient struct {
	ID         int
	URL        string
	Conn       *websocket.Conn
	Messages   int
	Heartbeats int
	Errors     int
	Connected  bool
	logger     *Logger
	mu         sync.Mutex
}

// NewSSEClient creates a new SSE client
func NewSSEClient(id int, url string, connectTimeout time.Duration, logger *Logger) *SSEClient {
	// Create custom transport with separate timeouts
	transport := &http.Transport{
		DialContext: (&net.Dialer{
			Timeout:   connectTimeout, // Connection timeout
			KeepAlive: 30 * time.Second,
		}).DialContext,
		MaxIdleConns:          100,
		IdleConnTimeout:       90 * time.Second,
		TLSHandshakeTimeout:   10 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
	}

	// Create client with no timeout (for SSE streaming)
	client := &http.Client{
		Transport: transport,
		// No timeout - let the SSE stream run indefinitely
	}

	return &SSEClient{
		ID:     id,
		URL:    url,
		Client: client,
		logger: logger,
	}
}

// NewWebSocketClient creates a new WebSocket client
func NewWebSocketClient(id int, url string, logger *Logger) *WebSocketClient {
	return &WebSocketClient{
		ID:     id,
		URL:    url,
		logger: logger,
	}
}

// Connect establishes an SSE connection and listens for messages
func (s *SSEClient) Connect(ctx context.Context, onConnect func()) error {
	s.logger.Debug("[Client %d] 🔗 Attempting to connect to %s", s.ID, s.URL)

	req, err := http.NewRequestWithContext(ctx, "GET", s.URL, nil)
	if err != nil {
		s.logger.Error("[Client %d] ❌ Failed to create request: %v", s.ID, err)
		return fmt.Errorf("failed to create request: %w", err)
	}

	// Set SSE headers
	req.Header.Set("Accept", "text/event-stream")
	req.Header.Set("Cache-Control", "no-cache")
	req.Header.Set("Connection", "keep-alive")

	s.logger.Debug("[Client %d] 📤 Sending HTTP request...", s.ID)
	startTime := time.Now()
	resp, err := s.Client.Do(req)
	connectDuration := time.Since(startTime)

	if err != nil {
		s.logger.Error("[Client %d] ❌ HTTP request failed after %v: %v", s.ID, connectDuration, err)
		return fmt.Errorf("failed to connect: %w", err)
	}
	defer resp.Body.Close()

	s.logger.Debug("[Client %d] 📥 Received response: status=%d, duration=%v", s.ID, resp.StatusCode, connectDuration)

	if resp.StatusCode != http.StatusOK {
		s.logger.Error("[Client %d] ❌ Unexpected status code: %d", s.ID, resp.StatusCode)
		return fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	s.mu.Lock()
	s.Connected = true
	s.mu.Unlock()

	s.logger.Info("[Client %d] ✅ Connected to SSE stream at %s", s.ID, s.URL)

	// Call the onConnect callback to notify of successful connection
	if onConnect != nil {
		onConnect()
	}

	s.logger.Debug("[Client %d] 📡 Starting to read SSE stream...", s.ID)
	scanner := bufio.NewScanner(resp.Body)
	for scanner.Scan() {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		line := scanner.Text()

		if line == "" {
			continue
		}

		// Trim whitespace and check the line type
		trimmedLine := strings.TrimSpace(line)

		// Debug: Log all non-empty lines to see what we're receiving
		if len(trimmedLine) > 0 {
			s.logger.Debug("[Client %d] 🔍 Raw SSE line: '%s'", s.ID, trimmedLine)
		}

		// Handle data messages
		if len(trimmedLine) > 5 && trimmedLine[:5] == "data:" {
			// Remove "data:" prefix and trim any remaining whitespace
			data := strings.TrimSpace(trimmedLine[5:])
			s.handleMessage(data)
		} else if len(trimmedLine) > 1 && trimmedLine[:1] == ":" {
			// Handle heartbeat messages (lines starting with ":")
			heartbeat := strings.TrimSpace(trimmedLine[1:])
			s.mu.Lock()
			s.Heartbeats++
			s.mu.Unlock()

			if heartbeat == "heartbeat" {
				s.logger.Debug("[Client %d] 💓 Heartbeat received (#%d)", s.ID, s.Heartbeats)
			} else {
				s.logger.Debug("[Client %d] 💓 Heartbeat: %s (#%d)", s.ID, heartbeat, s.Heartbeats)
			}
		} else if len(trimmedLine) > 0 {
			// Log any other non-empty lines for debugging
			s.logger.Debug("[Client %d] 📝 Other SSE line: %s", s.ID, trimmedLine)
		}
	}

	if err := scanner.Err(); err != nil {
		s.logger.Error("[Client %d] ❌ Scanner error: %v", s.ID, err)
		return fmt.Errorf("scanner error: %w", err)
	}

	return nil
}

// handleMessage processes incoming SSE messages
func (s *SSEClient) handleMessage(data string) {
	s.mu.Lock()
	s.Messages++
	s.mu.Unlock()

	var dashboardData DashboardData
	if err := json.Unmarshal([]byte(data), &dashboardData); err != nil {
		s.logger.Error("[Client %d] ❌ Failed to parse message: %v", s.ID, err)
		s.mu.Lock()
		s.Errors++
		s.mu.Unlock()
		return
	}

	// Print formatted message to console
	fmt.Printf("\n[Client %d] 📡 Message #%d received at %s\n", s.ID, s.Messages, dashboardData.Timestamp)
	fmt.Printf("   Status: %s (Uptime: %s)\n", dashboardData.SystemStatus.Status, dashboardData.SystemStatus.Uptime)
	fmt.Printf("   CPU: %s | Memory: %s | Disk: %s | Network: %s\n",
		dashboardData.Metrics.CPU, dashboardData.Metrics.Memory,
		dashboardData.Metrics.Disk, dashboardData.Metrics.Network)
	fmt.Printf("   Response Time: %s\n", dashboardData.Metrics.ResponseTime)

	if len(dashboardData.Activities) > 0 {
		fmt.Printf("   Latest Activity: %s - %s (%s)\n",
			dashboardData.Activities[0].Time,
			dashboardData.Activities[0].Message,
			dashboardData.Activities[0].Level)
	}
}

// GetStats returns current statistics for this client
func (s *SSEClient) GetStats() (messages, heartbeats, errors int, connected bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.Messages, s.Heartbeats, s.Errors, s.Connected
}

// MarkDisconnected marks the client as disconnected
func (s *SSEClient) MarkDisconnected() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.Connected = false
}

// Connect establishes a WebSocket connection and listens for messages
func (w *WebSocketClient) Connect(ctx context.Context, onConnect func()) error {
	w.logger.Debug("[WebSocket Client %d] 🔗 Attempting to connect to %s", w.ID, w.URL)

	// Create WebSocket dialer
	dialer := websocket.Dialer{
		HandshakeTimeout: 10 * time.Second,
	}

	// Connect to WebSocket
	conn, _, err := dialer.DialContext(ctx, w.URL, nil)
	if err != nil {
		w.logger.Error("[WebSocket Client %d] ❌ Failed to connect: %v", w.ID, err)
		return fmt.Errorf("failed to connect: %w", err)
	}

	w.Conn = conn
	w.Connected = true
	w.logger.Info("[WebSocket Client %d] ✅ Connected successfully", w.ID)

	// Subscribe to the dashboard_updates channel
	if err := w.subscribeToChannel("dashboard_updates"); err != nil {
		w.logger.Warn("[WebSocket Client %d] ⚠️ Failed to subscribe to channel: %v", w.ID, err)
		// Don't return error, continue anyway
	}

	// Call onConnect callback
	if onConnect != nil {
		onConnect()
	}

	return nil
}

// subscribeToChannel subscribes to an ActionCable channel
func (w *WebSocketClient) subscribeToChannel(channelName string) error {
	// ActionCable subscription message format
	// Note: For ActionCable, we need to use the channel class name, not the identifier
	// The channel class name is "DashboardUpdatesChannel" for the "dashboard_updates" stream
	subscribeMsg := map[string]interface{}{
		"command":    "subscribe",
		"identifier": fmt.Sprintf(`{"channel":"DashboardUpdatesChannel"}`),
	}

	// Convert to JSON
	jsonData, err := json.Marshal(subscribeMsg)
	if err != nil {
		return fmt.Errorf("failed to marshal subscription message: %w", err)
	}

	// Send subscription message
	if err := w.Conn.WriteMessage(websocket.TextMessage, jsonData); err != nil {
		return fmt.Errorf("failed to send subscription message: %w", err)
	}

	w.logger.Debug("[WebSocket Client %d] 📡 Subscribed to channel: %s (DashboardUpdatesChannel)", w.ID, channelName)
	return nil
}

// handleMessages handles incoming WebSocket messages
func (w *WebSocketClient) handleMessages(ctx context.Context) error {
	defer func() {
		w.Connected = false
		if w.Conn != nil {
			w.Conn.Close()
		}
		w.logger.Debug("[WebSocket Client %d] 🔌 Connection closed", w.ID)
	}()

	for {
		select {
		case <-ctx.Done():
			w.logger.Debug("[WebSocket Client %d] 🛑 Context cancelled", w.ID)
			return ctx.Err()
		default:
			// Set read deadline
			w.Conn.SetReadDeadline(time.Now().Add(30 * time.Second))

			// Read message
			_, message, err := w.Conn.ReadMessage()
			if err != nil {
				if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
					w.logger.Error("[WebSocket Client %d] ❌ WebSocket error: %v", w.ID, err)
					w.incrementErrors()
				}
				return err
			}

			// Process message
			w.processMessage(message)
		}
	}
}

// processMessage processes a WebSocket message
func (w *WebSocketClient) processMessage(message []byte) {
	w.mu.Lock()
	defer w.mu.Unlock()

	w.logger.Debug("[WebSocket Client %d] 📨 Raw message: %s", w.ID, string(message))

	// Try to parse as JSON first
	var jsonData map[string]interface{}
	if err := json.Unmarshal(message, &jsonData); err != nil {
		w.logger.Warn("[WebSocket Client %d] ⚠️ Failed to parse JSON: %v", w.ID, err)
		return
	}

	// Check if this is an ActionCable channel message (has identifier and message fields)
	if identifier, hasIdentifier := jsonData["identifier"].(string); hasIdentifier {
		if msgData, hasMessage := jsonData["message"].(map[string]interface{}); hasMessage {
			// This is a channel message with dashboard data
			w.logger.Debug("[WebSocket Client %d] 📊 Dashboard message received from %s", w.ID, identifier)
			w.Messages++

			// Try to extract timestamp from the message
			if timestamp, ok := msgData["timestamp"].(string); ok {
				w.logger.Debug("[WebSocket Client %d] ✅ Received dashboard data: %s", w.ID, timestamp)
			} else {
				w.logger.Debug("[WebSocket Client %d] ✅ Received dashboard message", w.ID)
			}
			return
		}
	}

	// Check message type for control messages
	msgType, ok := jsonData["type"].(string)
	if !ok {
		w.logger.Warn("[WebSocket Client %d] ⚠️ No message type found", w.ID)
		return
	}

	switch msgType {
	case "welcome":
		w.logger.Debug("[WebSocket Client %d] 🎉 Welcome message received", w.ID)
		w.Messages++
	case "ping":
		w.logger.Debug("[WebSocket Client %d] 💓 Ping received", w.ID)
		w.Heartbeats++
	case "confirm_subscription":
		w.logger.Debug("[WebSocket Client %d] ✅ Channel subscription confirmed", w.ID)
		w.Messages++
	case "message":
		// This is where actual dashboard data would come
		w.logger.Debug("[WebSocket Client %d] 📊 Dashboard message received", w.ID)
		w.Messages++

		// Try to parse as DashboardData if it's a dashboard message
		var dashboardData DashboardData
		if err := json.Unmarshal(message, &dashboardData); err == nil && dashboardData.Timestamp != "" {
			w.logger.Debug("[WebSocket Client %d] ✅ Received dashboard data: %s", w.ID, dashboardData.Timestamp)
		} else {
			w.logger.Debug("[WebSocket Client %d] ✅ Received message: %s", w.ID, string(message))
		}
	default:
		// Check if this is a channel message (ActionCable format)
		if identifier, ok := jsonData["identifier"].(string); ok {
			// This is likely a channel message
			w.logger.Debug("[WebSocket Client %d] 📡 Channel message from %s: %s", w.ID, identifier, string(message))
			w.Messages++
		} else {
			w.logger.Debug("[WebSocket Client %d] ✅ Received %s message: %s", w.ID, msgType, string(message))
			w.Messages++
		}
	}
}

// incrementErrors increments the error count
func (w *WebSocketClient) incrementErrors() {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.Errors++
}

// GetStats returns the client statistics
func (w *WebSocketClient) GetStats() (int, int, int, bool) {
	w.mu.Lock()
	defer w.mu.Unlock()
	return w.Messages, w.Heartbeats, w.Errors, w.Connected
}

// Stats represents overall statistics
type Stats struct {
	TotalClients          int
	TotalMessages         int
	TotalHeartbeats       int
	TotalErrors           int
	SuccessfulConnections int
	ActiveConnections     int
	ClosedConnections     int
	FailedConnections     int
	mu                    sync.RWMutex
}

// UpdateStats updates the global statistics
func (s *Stats) UpdateStats(messages, heartbeats, errors int) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.TotalMessages += messages
	s.TotalHeartbeats += heartbeats
	s.TotalErrors += errors
}

// IncrementSuccessfulConnection increments successful connection count
func (s *Stats) IncrementSuccessfulConnection() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.SuccessfulConnections++
	s.ActiveConnections++
}

// IncrementFailedConnection increments failed connection count
func (s *Stats) IncrementFailedConnection() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.FailedConnections++
}

// DecrementActiveConnection decrements active connection count
func (s *Stats) DecrementActiveConnection() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.ActiveConnections > 0 {
		s.ActiveConnections--
	}
	s.ClosedConnections++
}

// GetStats returns a copy of current statistics
func (s *Stats) GetStats() (clients, messages, heartbeats, errors, successful, active, closed, failed int) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.TotalClients, s.TotalMessages, s.TotalHeartbeats, s.TotalErrors, s.SuccessfulConnections, s.ActiveConnections, s.ClosedConnections, s.FailedConnections
}

func main() {
	var (
		url        = flag.String("url", "http://localhost:3000/dashboard/stream", "SSE/WebSocket endpoint URL")
		numClients = flag.Int("clients", 1, "Number of concurrent clients")
		showStats  = flag.Bool("stats", false, "Show periodic statistics")
		timeout    = flag.Duration("timeout", 60*time.Second, "Connection timeout (0 = no timeout)")
		protocol   = flag.String("protocol", "sse", "Protocol to use: 'sse' or 'websocket'")
		logLevel   = flag.String("log-level", "info", "Log level: debug, info, warn, error")
	)
	flag.Parse()

	if *numClients < 1 {
		log.Fatal("Number of clients must be at least 1")
	}

	// Validate protocol
	if *protocol != "sse" && *protocol != "websocket" {
		log.Fatal("Protocol must be 'sse' or 'websocket'")
	}

	// Create logger
	logger := NewLogger(*logLevel)

	logger.Info("🚀 Starting %s load test with %d clients", strings.ToUpper(*protocol), *numClients)
	logger.Info("📡 Target URL: %s", *url)
	logger.Info("⏱️  Connection timeout: %v", *timeout)
	logger.Info("📝 Log level: %s", strings.ToUpper(*logLevel))

	// Create context for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		logger.Info("\n🛑 Shutting down gracefully...")
		cancel()
	}()

	// Create statistics tracker
	stats := &Stats{TotalClients: *numClients}

	// Start statistics reporting if enabled
	if *showStats {
		go func() {
			ticker := time.NewTicker(10 * time.Second)
			defer ticker.Stop()
			for {
				select {
				case <-ctx.Done():
					return
				case <-ticker.C:
					clients, messages, heartbeats, errors, successful, active, closed, failed := stats.GetStats()
					logger.Info("📊 Stats: %d clients, %d messages, %d heartbeats, %d errors, %d successful connections, %d active, %d closed, %d failed",
						clients, messages, heartbeats, errors, successful, active, closed, failed)
				}
			}
		}()
	}

	// Start all clients
	var wg sync.WaitGroup
	for i := 1; i <= *numClients; i++ {
		logger.Debug("🚀 Starting %s client %d of %d", strings.ToUpper(*protocol), i, *numClients)
		wg.Add(1)
		go func(clientID int) {
			if *protocol == "websocket" {
				// WebSocket client
				client := NewWebSocketClient(clientID, *url, logger)

				defer func() {
					// Mark client as disconnected when goroutine ends
					client.Connected = false
					stats.DecrementActiveConnection()
					wg.Done()
				}()

				// Retry loop for reconnection
				for {
					select {
					case <-ctx.Done():
						return
					default:
					}

					if err := client.Connect(ctx, func() {
						stats.IncrementSuccessfulConnection()
					}); err != nil {
						// Check if this is a context cancellation (graceful shutdown)
						if err == context.Canceled {
							logger.Debug("[WebSocket Client %d] 🔄 Graceful shutdown", clientID)
							return
						}

						// Check if context is done (graceful shutdown)
						select {
						case <-ctx.Done():
							logger.Debug("[WebSocket Client %d] 🔄 Graceful shutdown (context done)", clientID)
							return
						default:
							// This is a real connection error
							logger.Error("[WebSocket Client %d] ❌ Connection error: %v", clientID, err)
							stats.IncrementFailedConnection()
							client.mu.Lock()
							client.Errors++
							client.mu.Unlock()

							// Wait before retrying
							select {
							case <-ctx.Done():
								return
							case <-time.After(5 * time.Second):
								continue
							}
						}
					}

					// Handle messages in the same loop (no separate goroutine)
					if err := client.handleMessages(ctx); err != nil {
						// Check if this is a context cancellation (graceful shutdown)
						if err == context.Canceled {
							logger.Debug("[WebSocket Client %d] 🔄 Graceful shutdown", clientID)
							return
						}

						// Check if context is done (graceful shutdown)
						select {
						case <-ctx.Done():
							logger.Debug("[WebSocket Client %d] 🔄 Graceful shutdown (context done)", clientID)
							return
						default:
							// This is a real connection error, continue to retry
							logger.Warn("[WebSocket Client %d] 🔄 Connection lost, retrying...", clientID)
							continue
						}
					}
				}
			} else {
				// SSE client
				client := NewSSEClient(clientID, *url, *timeout, logger)

				defer func() {
					// Mark client as disconnected when goroutine ends
					client.MarkDisconnected()
					stats.DecrementActiveConnection()
					wg.Done()
				}()

				// Retry loop for reconnection
				for {
					select {
					case <-ctx.Done():
						return
					default:
					}

					if err := client.Connect(ctx, func() {
						stats.IncrementSuccessfulConnection()
					}); err != nil {
						// Check if this is a context cancellation (graceful shutdown)
						if err == context.Canceled {
							logger.Debug("[Client %d] 🔄 Graceful shutdown", clientID)
							return
						}

						// Check if context is done (graceful shutdown)
						select {
						case <-ctx.Done():
							logger.Debug("[Client %d] 🔄 Graceful shutdown (context done)", clientID)
							return
						default:
							// This is a real connection error
							logger.Error("[Client %d] ❌ Connection error: %v", clientID, err)
							stats.IncrementFailedConnection()
							client.mu.Lock()
							client.Errors++
							client.mu.Unlock()

							// Wait before retrying
							select {
							case <-ctx.Done():
								return
							case <-time.After(5 * time.Second):
								continue
							}
						}
					}
				}
			}
		}(i)

		// Small delay between client starts to avoid overwhelming the server
		if i < *numClients {
			log.Printf("⏳ Waiting 10ms before starting next client...")
			time.Sleep(10 * time.Millisecond)
		}
	}

	// Wait for all clients to finish
	wg.Wait()

	// Final statistics
	clients, messages, heartbeats, errors, successful, active, closed, failed := stats.GetStats()
	logger.Info("\n📊 Final Statistics:")
	logger.Info("   Total Clients: %d", clients)
	logger.Info("   Total Messages: %d", messages)
	logger.Info("   Total Heartbeats: %d", heartbeats)
	logger.Info("   Total Errors: %d", errors)
	logger.Info("   Successful Connections: %d", successful)
	logger.Info("   Active Connections: %d", active)
	logger.Info("   Closed Connections: %d", closed)
	logger.Info("   Failed Connections: %d", failed)
	logger.Info("   Messages per Client: %.2f", float64(messages)/float64(clients))
	logger.Info("   Heartbeats per Client: %.2f", float64(heartbeats)/float64(clients))
}
