package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/gorilla/websocket"
	"github.com/redis/go-redis/v9"
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

// DashboardData represents the dashboard data structure
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

// ActionCableMessage represents ActionCable message format
type ActionCableMessage struct {
	Command    string      `json:"command,omitempty"`
	Identifier string      `json:"identifier,omitempty"`
	Message    interface{} `json:"message,omitempty"`
	Type       string      `json:"type,omitempty"`
}

// WebSocketConnection represents a WebSocket connection
type WebSocketConnection struct {
	ID            string
	Conn          *websocket.Conn
	Subscriptions map[string]bool
	LastSeen      time.Time
	mu            sync.RWMutex // Protects Subscriptions map from concurrent access
}

// Server represents the combined SSE and WebSocket server
type Server struct {
	sseConnections map[string]*SSEConnection
	wsConnections  map[string]*WebSocketConnection
	sseMutex       sync.RWMutex
	wsMutex        sync.RWMutex
	redisClient    *redis.Client
	upgrader       websocket.Upgrader
	logger         *Logger
	stats          *ServerStats
}

// ServerStats represents server statistics
type ServerStats struct {
	TotalSSEConnections         int64
	TotalWebSocketConnections   int64
	CurrentSSEConnections       int64
	CurrentWebSocketConnections int64
	TotalSSEMessages            int64
	TotalWebSocketMessages      int64
	TotalRedisMessages          int64
	StartTime                   time.Time
	mu                          sync.RWMutex
}

// NewServerStats creates new server statistics
func NewServerStats() *ServerStats {
	return &ServerStats{
		StartTime: time.Now(),
	}
}

// IncrementSSEConnection increments SSE connection count
func (s *ServerStats) IncrementSSEConnection() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.TotalSSEConnections++
	s.CurrentSSEConnections++
}

// DecrementSSEConnection decrements SSE connection count
func (s *ServerStats) DecrementSSEConnection() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.CurrentSSEConnections > 0 {
		s.CurrentSSEConnections--
	}
}

// IncrementWebSocketConnection increments WebSocket connection count
func (s *ServerStats) IncrementWebSocketConnection() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.TotalWebSocketConnections++
	s.CurrentWebSocketConnections++
}

// DecrementWebSocketConnection decrements WebSocket connection count
func (s *ServerStats) DecrementWebSocketConnection() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.CurrentWebSocketConnections > 0 {
		s.CurrentWebSocketConnections--
	}
}

// IncrementSSEMessage increments SSE message count
func (s *ServerStats) IncrementSSEMessage() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.TotalSSEMessages++
}

// IncrementWebSocketMessage increments WebSocket message count
func (s *ServerStats) IncrementWebSocketMessage() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.TotalWebSocketMessages++
}

// IncrementRedisMessage increments Redis message count
func (s *ServerStats) IncrementRedisMessage() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.TotalRedisMessages++
}

// GetStats returns a copy of current statistics
func (s *ServerStats) GetStats() (totalSSE, currentSSE, totalWS, currentWS, sseMsgs, wsMsgs, redisMsgs int64, uptime time.Duration) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.TotalSSEConnections, s.CurrentSSEConnections, s.TotalWebSocketConnections, s.CurrentWebSocketConnections, s.TotalSSEMessages, s.TotalWebSocketMessages, s.TotalRedisMessages, time.Since(s.StartTime)
}

// SSEConnection represents a single SSE connection
type SSEConnection struct {
	ID       string
	Writer   http.ResponseWriter
	Flusher  http.Flusher
	Done     chan bool
	LastSeen time.Time
}

// NewServer creates a new combined server
func NewServer(logLevel string) *Server {
	// Initialize logger
	logger := NewLogger(logLevel)

	// Initialize Redis client
	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		redisURL = "redis://localhost:6379"
	}

	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		logger.Warn("Failed to parse Redis URL: %v", err)
		opt = &redis.Options{
			Addr: "localhost:6379",
		}
	}

	redisClient := redis.NewClient(opt)

	// Test Redis connection
	ctx := context.Background()
	_, err = redisClient.Ping(ctx).Result()
	if err != nil {
		logger.Warn("Redis not available: %v", err)
		redisClient = nil
	} else {
		logger.Info("✅ Redis connected successfully")
	}

	return &Server{
		sseConnections: make(map[string]*SSEConnection),
		wsConnections:  make(map[string]*WebSocketConnection),
		redisClient:    redisClient,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true // Allow all origins for development
			},
		},
		logger: logger,
		stats:  NewServerStats(),
	}
}

// generateConnectionID generates a unique connection ID
func (s *Server) generateConnectionID() string {
	return fmt.Sprintf("conn_%d", time.Now().UnixNano())
}

// addSSEConnection adds a new SSE connection
func (s *Server) addSSEConnection(conn *SSEConnection) {
	s.sseMutex.Lock()
	defer s.sseMutex.Unlock()
	s.sseConnections[conn.ID] = conn
	s.stats.IncrementSSEConnection()
	s.logger.Debug("SSE connection added: %s (total: %d)", conn.ID, len(s.sseConnections))
}

// removeSSEConnection removes an SSE connection
func (s *Server) removeSSEConnection(id string) {
	s.sseMutex.Lock()
	defer s.sseMutex.Unlock()
	delete(s.sseConnections, id)
	s.stats.DecrementSSEConnection()
	s.logger.Debug("SSE connection removed: %s (total: %d)", id, len(s.sseConnections))
}

// addWSConnection adds a new WebSocket connection
func (s *Server) addWSConnection(conn *WebSocketConnection) {
	s.wsMutex.Lock()
	defer s.wsMutex.Unlock()
	s.wsConnections[conn.ID] = conn
	s.stats.IncrementWebSocketConnection()
	s.logger.Info("✅ WebSocket connection added: %s (total: %d)", conn.ID, len(s.wsConnections))
}

// removeWSConnection removes a WebSocket connection
func (s *Server) removeWSConnection(id string) {
	s.wsMutex.Lock()
	defer s.wsMutex.Unlock()
	delete(s.wsConnections, id)
	s.stats.DecrementWebSocketConnection()
	s.logger.Info("❌ WebSocket connection removed: %s (total: %d)", id, len(s.wsConnections))
}

// broadcastToSSE broadcasts a message to all SSE connections
func (s *Server) broadcastToSSE(data interface{}) {
	jsonData, err := json.Marshal(data)
	if err != nil {
		s.logger.Error("Error marshaling SSE data: %v", err)
		return
	}

	s.sseMutex.RLock()
	defer s.sseMutex.RUnlock()

	s.logger.Debug("Broadcasting to %d SSE connections", len(s.sseConnections))
	for _, conn := range s.sseConnections {
		_, err := fmt.Fprintf(conn.Writer, "data: %s\n\n", jsonData)
		if err != nil {
			s.logger.Error("Error sending SSE data to connection %s: %v", conn.ID, err)
			continue
		}
		conn.Flusher.Flush()
		conn.LastSeen = time.Now()
		s.stats.IncrementSSEMessage()
		s.logger.Debug("Sent SSE data to connection %s", conn.ID)
	}
}

// broadcastToWebSocket broadcasts a message to all WebSocket connections subscribed to a channel
func (s *Server) broadcastToWebSocket(channel string, data interface{}) {
	// Map stream name back to channel class for the identifier
	var channelClass string
	switch channel {
	case "dashboard_updates":
		channelClass = "DashboardUpdatesChannel"
	default:
		channelClass = channel // fallback
	}

	message := ActionCableMessage{
		Identifier: fmt.Sprintf(`{"channel":"%s"}`, channelClass),
		Message:    data,
	}

	jsonData, err := json.Marshal(message)
	if err != nil {
		s.logger.Error("Error marshaling WebSocket data: %v", err)
		return
	}

	s.wsMutex.RLock()
	defer s.wsMutex.RUnlock()

	s.logger.Debug("Broadcasting to WebSocket connections subscribed to '%s' (channel class: %s)", channel, channelClass)
	s.logger.Debug("Message: %s", string(jsonData))

	for _, conn := range s.wsConnections {
		conn.mu.RLock()
		if conn.Subscriptions[channel] {
			s.logger.Debug("Sending to WebSocket connection %s (subscribed to %s)", conn.ID, channel)
			err := conn.Conn.WriteMessage(websocket.TextMessage, jsonData)
			if err != nil {
				s.logger.Error("Error sending WebSocket data to connection %s: %v", conn.ID, err)
				continue
			}
			conn.LastSeen = time.Now()
			s.logger.Debug("Successfully sent message to WebSocket connection %s", conn.ID)
		} else {
			s.logger.Debug("WebSocket connection %s not subscribed to %s (subscriptions: %v)", conn.ID, channel, conn.Subscriptions)
		}
		conn.mu.RUnlock()
	}
}

// streamHandler handles SSE stream requests
func (s *Server) streamHandler(w http.ResponseWriter, r *http.Request) {
	// Set CORS headers for SSE
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Cache-Control")
	w.Header().Set("Access-Control-Allow-Credentials", "true")

	// Handle preflight requests
	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	// Set SSE headers
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")

	// Get flusher for streaming
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "Streaming unsupported", http.StatusInternalServerError)
		return
	}

	// Create connection
	conn := &SSEConnection{
		ID:       s.generateConnectionID(),
		Writer:   w,
		Flusher:  flusher,
		Done:     make(chan bool),
		LastSeen: time.Now(),
	}

	// Add connection
	s.addSSEConnection(conn)
	defer s.removeSSEConnection(conn.ID)

	s.logger.Debug("SSE connection established: %s", conn.ID)

	// Setup Redis pub/sub if available
	var redisCh <-chan *redis.Message
	var pubsub *redis.PubSub
	if s.redisClient != nil {
		// Use the shared Redis client for pub/sub
		pubsub = s.redisClient.Subscribe(r.Context(), "dashboard_updates")
		defer pubsub.Close()
		redisCh = pubsub.Channel()
		s.logger.Debug("Redis pub/sub started for SSE connection: %s", conn.ID)
	}

	// Setup heartbeat timer with reset capability
	heartbeatTicker := time.NewTicker(30 * time.Second)
	defer heartbeatTicker.Stop()

	// Combined select statement for all events
	for {
		select {
		case <-r.Context().Done():
			s.logger.Info("SSE client disconnected: %s", conn.ID)
			return
		case <-conn.Done:
			s.logger.Info("SSE connection closed: %s", conn.ID)
			return
		case <-heartbeatTicker.C:
			// Send heartbeat
			_, err := fmt.Fprintf(w, ": heartbeat\n\n")
			if err != nil {
				s.logger.Error("Error sending heartbeat to %s: %v", conn.ID, err)
				return
			}
			flusher.Flush()
			conn.LastSeen = time.Now()
			s.logger.Debug("💓 Heartbeat sent to SSE connection %s", conn.ID)
		case msg := <-redisCh:
			// Handle Redis message
			var data interface{}
			err := json.Unmarshal([]byte(msg.Payload), &data)
			if err != nil {
				s.logger.Error("Error parsing Redis message: %v", err)
				continue
			}

			// Send the data to the client
			jsonData, err := json.Marshal(data)
			if err != nil {
				s.logger.Error("Error marshaling data: %v", err)
				continue
			}

			_, err = fmt.Fprintf(w, "data: %s\n\n", jsonData)
			if err != nil {
				s.logger.Error("Error sending Redis data to SSE connection %s: %v", conn.ID, err)
				return
			}
			flusher.Flush()
			conn.LastSeen = time.Now()

			// Reset heartbeat timer since we just sent data
			heartbeatTicker.Reset(30 * time.Second)

			s.logger.Debug("Redis message sent to SSE connection %s: %s", conn.ID, msg.Payload)
		}
	}
}

// websocketHandler handles WebSocket connections
func (s *Server) websocketHandler(w http.ResponseWriter, r *http.Request) {
	// Log connection attempt
	s.logger.Info("🔗 WebSocket connection attempt from %s", r.RemoteAddr)

	// Upgrade HTTP connection to WebSocket
	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		s.logger.Error("❌ WebSocket upgrade failed: %v", err)
		return
	}
	defer func() {
		s.logger.Info("🔌 WebSocket connection closed for %s", r.RemoteAddr)
		conn.Close()
	}()

	// Create WebSocket connection
	wsConn := &WebSocketConnection{
		ID:            s.generateConnectionID(),
		Conn:          conn,
		Subscriptions: make(map[string]bool),
		LastSeen:      time.Now(),
	}

	// Add connection
	s.addWSConnection(wsConn)
	defer s.removeWSConnection(wsConn.ID)

	s.logger.Debug("WebSocket connection established: %s", wsConn.ID)

	// Send welcome message
	welcomeMsg := ActionCableMessage{Type: "welcome"}
	if err := conn.WriteJSON(welcomeMsg); err != nil {
		s.logger.Error("❌ Error sending welcome message: %v", err)
		return
	}
	s.logger.Info("🎉 Welcome message sent to WebSocket connection: %s", wsConn.ID)

	// Setup Redis pub/sub if available
	var redisCh <-chan *redis.Message
	var pubsub *redis.PubSub
	if s.redisClient != nil {
		pubsub = s.redisClient.Subscribe(r.Context(), "dashboard_updates")
		defer func() {
			s.logger.Info("🔌 Redis pub/sub closed for WebSocket connection: %s", wsConn.ID)
			pubsub.Close()
		}()
		redisCh = pubsub.Channel()
		s.logger.Info("🔗 Redis pub/sub started for WebSocket connection: %s", wsConn.ID)
	} else {
		s.logger.Warn("⚠️ Redis not available for WebSocket connection: %s", wsConn.ID)
	}

	// Setup ping ticker (keep-alive pings every 60 seconds)
	pingTicker := time.NewTicker(60 * time.Second)
	defer pingTicker.Stop()

	// Create a channel for incoming messages
	incomingMessages := make(chan []byte, 10)
	readDone := make(chan bool)

	// Start a separate goroutine for reading messages
	// Note: No read deadline is set to allow long-lived connections
	go func() {
		defer func() {
			s.logger.Info("🛑 WebSocket read goroutine exiting for connection: %s", wsConn.ID)
			close(readDone)
		}()

		for {
			select {
			case <-r.Context().Done():
				s.logger.Info("🛑 WebSocket read goroutine context done for connection: %s", wsConn.ID)
				return
			default:
			}

			// Read message (no deadline - let WebSocket handle timeouts naturally)
			_, message, err := conn.ReadMessage()
			if err != nil {
				if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
					s.logger.Error("❌ WebSocket read error for connection %s: %v", wsConn.ID, err)
					s.logger.Error("❌ WebSocket read error type: %T", wsConn.ID, err)
				} else {
					s.logger.Info("🔌 Normal WebSocket close for connection %s: %v", wsConn.ID, err)
				}
				return
			}

			// Send message to main loop
			select {
			case incomingMessages <- message:
			case <-r.Context().Done():
				return
			}
		}
	}()

	// Main loop for handling all messages (Redis, ping, incoming)
	for {
		select {
		case <-r.Context().Done():
			s.logger.Info("🛑 WebSocket client disconnected (context done): %s", wsConn.ID)
			return
		case <-readDone:
			s.logger.Info("🛑 WebSocket read goroutine finished: %s", wsConn.ID)
			return
		case <-pingTicker.C:
			// Send ping
			pingMsg := ActionCableMessage{Type: "ping"}
			if err := conn.WriteJSON(pingMsg); err != nil {
				s.logger.Error("❌ Error sending ping to WebSocket connection %s: %v", wsConn.ID, err)
				s.logger.Info("🛑 WebSocket connection terminated due to ping error: %s", wsConn.ID)
				return
			}
			wsConn.LastSeen = time.Now()
			s.logger.Info("💓 Ping sent to WebSocket connection %s", wsConn.ID)
		case msg := <-redisCh:
			// Handle Redis message - send directly to this connection if subscribed
			s.stats.IncrementRedisMessage()
			var data interface{}
			err := json.Unmarshal([]byte(msg.Payload), &data)
			if err != nil {
				s.logger.Error("Error parsing Redis message: %v", err)
				continue
			}

			// Check if this connection is subscribed to dashboard_updates
			wsConn.mu.RLock()
			if wsConn.Subscriptions["dashboard_updates"] {
				// Map stream name back to channel class for the identifier
				channelClass := "DashboardUpdatesChannel"
				message := ActionCableMessage{
					Identifier: fmt.Sprintf(`{"channel":"%s"}`, channelClass),
					Message:    data,
				}

				jsonData, err := json.Marshal(message)
				if err != nil {
					s.logger.Error("Error marshaling WebSocket data: %v", err)
					wsConn.mu.RUnlock()
					continue
				}

				s.logger.Debug("Sending Redis message to WebSocket connection %s", wsConn.ID)
				err = conn.WriteMessage(websocket.TextMessage, jsonData)
				if err != nil {
					s.logger.Error("❌ Error sending WebSocket data to connection %s: %v", wsConn.ID, err)
					s.logger.Info("🛑 WebSocket connection terminated due to write error: %s", wsConn.ID)
					wsConn.mu.RUnlock()
					return
				}
				wsConn.LastSeen = time.Now()
				s.stats.IncrementWebSocketMessage()
				s.logger.Debug("Successfully sent message to WebSocket connection %s", wsConn.ID)
			}
			wsConn.mu.RUnlock()
			s.logger.Debug("Redis message processed for WebSocket connection %s: %s", wsConn.ID, msg.Payload)
		case message := <-incomingMessages:
			// Process incoming message
			s.handleWebSocketMessage(wsConn, message)
		}
	}
}

// handleWebSocketMessage processes incoming WebSocket messages
func (s *Server) handleWebSocketMessage(conn *WebSocketConnection, message []byte) {
	var msg ActionCableMessage
	if err := json.Unmarshal(message, &msg); err != nil {
		s.logger.Error("Error parsing WebSocket message: %v", err)
		return
	}

	switch msg.Command {
	case "subscribe":
		// Parse identifier to get channel name
		var identifier map[string]string
		if err := json.Unmarshal([]byte(msg.Identifier), &identifier); err != nil {
			s.logger.Error("Error parsing identifier: %v", err)
			return
		}

		channelClass := identifier["channel"]
		if channelClass != "" {
			// Map ActionCable channel class to actual stream name
			// DashboardUpdatesChannel streams from "dashboard_updates"
			var streamName string
			switch channelClass {
			case "DashboardUpdatesChannel":
				streamName = "dashboard_updates"
			default:
				streamName = channelClass // fallback
			}

			conn.mu.Lock()
			conn.Subscriptions[streamName] = true
			conn.mu.Unlock()

			// Send confirmation
			confirmMsg := ActionCableMessage{
				Type:       "confirm_subscription",
				Identifier: msg.Identifier,
			}
			if err := conn.Conn.WriteJSON(confirmMsg); err != nil {
				s.logger.Error("❌ Error sending subscription confirmation: %v", err)
			} else {
				s.logger.Info("✅ Subscription confirmation sent to connection %s for channel: %s", conn.ID, channelClass)
			}

			s.logger.Info("📡 WebSocket connection %s subscribed to channel: %s (stream: %s)", conn.ID, channelClass, streamName)
			s.logger.Debug("Current subscriptions for connection %s: %v", conn.ID, conn.Subscriptions)
		}

	case "unsubscribe":
		// Parse identifier to get channel name
		var identifier map[string]string
		if err := json.Unmarshal([]byte(msg.Identifier), &identifier); err != nil {
			s.logger.Error("Error parsing identifier: %v", err)
			return
		}

		channelClass := identifier["channel"]
		if channelClass != "" {
			// Map ActionCable channel class to actual stream name
			var streamName string
			switch channelClass {
			case "DashboardUpdatesChannel":
				streamName = "dashboard_updates"
			default:
				streamName = channelClass // fallback
			}

			conn.mu.Lock()
			delete(conn.Subscriptions, streamName)
			conn.mu.Unlock()

			s.logger.Debug("WebSocket connection %s unsubscribed from channel: %s (stream: %s)", conn.ID, channelClass, streamName)
		}

	default:
		s.logger.Warn("Unknown WebSocket command: %s", msg.Command)
	}
}

// debugHandler provides debug information
func debugHandler(w http.ResponseWriter, r *http.Request) {
	data := map[string]interface{}{
		"current_time": time.Now().Format("15:04:05"),
		"server":       "Go SSE/WebSocket Server",
		"status":       "running",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}

// statsHandler provides server statistics
func (s *Server) statsHandler(w http.ResponseWriter, r *http.Request) {
	totalSSE, currentSSE, totalWS, currentWS, sseMsgs, wsMsgs, redisMsgs, uptime := s.stats.GetStats()

	data := map[string]interface{}{
		"server": map[string]interface{}{
			"name":    "Go SSE/WebSocket Server",
			"status":  "running",
			"uptime":  uptime.String(),
			"started": s.stats.StartTime.Format("2006-01-02 15:04:05"),
		},
		"connections": map[string]interface{}{
			"sse": map[string]interface{}{
				"total":    totalSSE,
				"current":  currentSSE,
				"messages": sseMsgs,
			},
			"websocket": map[string]interface{}{
				"total":    totalWS,
				"current":  currentWS,
				"messages": wsMsgs,
			},
		},
		"redis": map[string]interface{}{
			"messages_received": redisMsgs,
		},
		"timestamp": time.Now().Format("2006-01-02 15:04:05"),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}

// CORS middleware function
func corsMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Set CORS headers
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Cache-Control")
		w.Header().Set("Access-Control-Allow-Credentials", "true")

		// Handle preflight requests
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next(w, r)
	}
}

func main() {
	// Get log level from environment variable or use default
	logLevel := os.Getenv("LOG_LEVEL")
	if logLevel == "" {
		logLevel = "info"
	}

	// Get port from environment variable or use default
	port := os.Getenv("PORT")
	if port == "" {
		port = "3001"
	}
	port = ":" + port

	// Create server
	server := NewServer(logLevel)

	// Set up routes
	http.HandleFunc("/dashboard/stream", corsMiddleware(server.streamHandler))
	http.HandleFunc("/cable", corsMiddleware(server.websocketHandler)) // ActionCable endpoint
	http.HandleFunc("/dashboard/debug", debugHandler)
	http.HandleFunc("/dashboard/stats", corsMiddleware(server.statsHandler))

	// Health check
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("OK"))
	})

	server.logger.Info("🚀 Go SSE/WebSocket Server starting on port %s", port)
	server.logger.Info("📡 SSE endpoint: http://localhost%s/dashboard/stream", port)
	server.logger.Info("🔌 WebSocket endpoint: ws://localhost%s/cable", port)
	server.logger.Info("🔍 Debug endpoint: http://localhost%s/dashboard/debug", port)
	server.logger.Info("📊 Stats endpoint: http://localhost%s/dashboard/stats", port)
	server.logger.Info("📝 Log level: %s", strings.ToUpper(logLevel))

	// Create context for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Start periodic stats logging
	go func() {
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				totalSSE, currentSSE, totalWS, currentWS, sseMsgs, wsMsgs, redisMsgs, uptime := server.stats.GetStats()
				server.logger.Info("📊 Stats: SSE[%d/%d] WS[%d/%d] Messages[SSE:%d WS:%d Redis:%d] Uptime:%s",
					currentSSE, totalSSE, currentWS, totalWS, sseMsgs, wsMsgs, redisMsgs, uptime.Round(time.Second))
			}
		}
	}()

	// Handle graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		server.logger.Info("🛑 Received shutdown signal, starting graceful shutdown...")

		// Log final statistics
		totalSSE, currentSSE, totalWS, currentWS, sseMsgs, wsMsgs, redisMsgs, uptime := server.stats.GetStats()
		server.logger.Info("📊 FINAL STATS:")
		server.logger.Info("   Server Uptime: %s", uptime.Round(time.Second))
		server.logger.Info("   SSE Connections: %d total, %d current", totalSSE, currentSSE)
		server.logger.Info("   WebSocket Connections: %d total, %d current", totalWS, currentWS)
		server.logger.Info("   Messages Sent:")
		server.logger.Info("     - SSE: %d", sseMsgs)
		server.logger.Info("     - WebSocket: %d", wsMsgs)
		server.logger.Info("   Redis Messages Received: %d", redisMsgs)
		server.logger.Info("   Message Rates:")
		if uptime.Seconds() > 0 {
			server.logger.Info("     - SSE: %.2f msg/sec", float64(sseMsgs)/uptime.Seconds())
			server.logger.Info("     - WebSocket: %.2f msg/sec", float64(wsMsgs)/uptime.Seconds())
			server.logger.Info("     - Redis: %.2f msg/sec", float64(redisMsgs)/uptime.Seconds())
		}
		server.logger.Info("   Connection Rates:")
		if uptime.Seconds() > 0 {
			server.logger.Info("     - SSE: %.2f conn/sec", float64(totalSSE)/uptime.Seconds())
			server.logger.Info("     - WebSocket: %.2f conn/sec", float64(totalWS)/uptime.Seconds())
		}

		// Cancel context to stop background goroutines
		cancel()

		// Give some time for graceful shutdown
		time.Sleep(2 * time.Second)

		server.logger.Info("👋 Server shutdown complete")
		os.Exit(0)
	}()

	// Start server
	server.logger.Info("🌐 Starting HTTP server...")
	if err := http.ListenAndServe(port, nil); err != nil {
		server.logger.Error("Server failed to start: %v", err)
		os.Exit(1)
	}
}
