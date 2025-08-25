package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"
)

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

// SSEServer represents the SSE server
type SSEServer struct {
	connections map[string]*SSEConnection
	mutex       sync.RWMutex
	redisClient *redis.Client
}

// SSEConnection represents a single SSE connection
type SSEConnection struct {
	ID       string
	Writer   http.ResponseWriter
	Flusher  http.Flusher
	Done     chan bool
	LastSeen time.Time
}

// NewSSEServer creates a new SSE server
func NewSSEServer() *SSEServer {
	// Initialize Redis client
	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		redisURL = "redis://localhost:6379"
	}

	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Printf("Warning: Failed to parse Redis URL: %v", err)
		opt = &redis.Options{
			Addr: "localhost:6379",
		}
	}

	redisClient := redis.NewClient(opt)

	// Test Redis connection
	ctx := context.Background()
	_, err = redisClient.Ping(ctx).Result()
	if err != nil {
		log.Printf("Warning: Redis not available: %v", err)
		redisClient = nil
	} else {
		log.Printf("✅ Redis connected successfully")
	}

	return &SSEServer{
		connections: make(map[string]*SSEConnection),
		redisClient: redisClient,
	}
}

// generateConnectionID generates a unique connection ID
func (s *SSEServer) generateConnectionID() string {
	return fmt.Sprintf("conn_%d", time.Now().UnixNano())
}

// addConnection adds a new SSE connection
func (s *SSEServer) addConnection(conn *SSEConnection) {
	s.mutex.Lock()
	defer s.mutex.Unlock()
	s.connections[conn.ID] = conn
	log.Printf("SSE connection added: %s (total: %d)", conn.ID, len(s.connections))
}

// removeConnection removes an SSE connection
func (s *SSEServer) removeConnection(id string) {
	s.mutex.Lock()
	defer s.mutex.Unlock()
	delete(s.connections, id)
	log.Printf("SSE connection removed: %s (total: %d)", id, len(s.connections))
}

// generateDashboardData generates sample dashboard data
func generateDashboardData() DashboardData {
	now := time.Now()

	data := DashboardData{}

	// System status
	data.SystemStatus.Status = "online"
	data.SystemStatus.Uptime = "2 days, 14 hours"
	data.SystemStatus.LastCheck = now.Format("15:04:05")
	data.SystemStatus.Message = "System running normally"

	// Metrics
	data.Metrics.CPU = "45%"
	data.Metrics.Memory = "67%"
	data.Metrics.Disk = "23%"
	data.Metrics.Network = "125 Mbps"
	data.Metrics.ResponseTime = "87ms"

	// Activities
	data.Activities = []struct {
		Time     string `json:"time"`
		Message  string `json:"message"`
		Level    string `json:"level"`
		CSSClass string `json:"css_class"`
	}{
		{
			Time:     now.Format("15:04:05"),
			Message:  "Dashboard updated",
			Level:    "info",
			CSSClass: "activity-info",
		},
		{
			Time:     now.Add(-time.Minute).Format("15:04:05"),
			Message:  "Metrics collected",
			Level:    "info",
			CSSClass: "activity-info",
		},
	}

	data.Timestamp = now.Format("15:04:05")

	return data
}

// streamHandler handles SSE stream requests
func (s *SSEServer) streamHandler(w http.ResponseWriter, r *http.Request) {
	// Set SSE headers
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")

	// Get the flusher
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
	s.addConnection(conn)
	defer s.removeConnection(conn.ID)

	log.Printf("SSE connection established: %s", conn.ID)

	// Send initial data
	// initialData := generateDashboardData()
	// jsonData, _ := json.Marshal(initialData)
	// fmt.Fprintf(w, "data: %s\n\n", jsonData)
	// flusher.Flush()

	// Setup Redis pub/sub if available
	var redisCh <-chan *redis.Message
	var pubsub *redis.PubSub
	if s.redisClient != nil {
		// Use the shared Redis client for pub/sub
		pubsub = s.redisClient.Subscribe(r.Context(), "dashboard_updates")
		defer pubsub.Close()
		redisCh = pubsub.Channel()
		log.Printf("Redis pub/sub started for connection: %s", conn.ID)
	}

	// Setup heartbeat timer
	heartbeatTicker := time.NewTicker(30 * time.Second)
	defer heartbeatTicker.Stop()

	// Combined select statement for all events
	for {
		select {
		case <-r.Context().Done():
			log.Printf("SSE client disconnected: %s", conn.ID)
			return
		case <-conn.Done:
			log.Printf("SSE connection closed: %s", conn.ID)
			return
		case <-heartbeatTicker.C:
			// Send heartbeat
			_, err := fmt.Fprintf(w, ": heartbeat\n\n")
			if err != nil {
				log.Printf("Error sending heartbeat to %s: %v", conn.ID, err)
				return
			}
			flusher.Flush()
			conn.LastSeen = time.Now()
		case msg := <-redisCh:
			// Handle Redis message
			var data interface{}
			err := json.Unmarshal([]byte(msg.Payload), &data)
			if err != nil {
				log.Printf("Error parsing Redis message: %v", err)
				continue
			}

			// Send the data to the client
			jsonData, err := json.Marshal(data)
			if err != nil {
				log.Printf("Error marshaling data: %v", err)
				continue
			}

			_, err = fmt.Fprintf(w, "data: %s\n\n", jsonData)
			if err != nil {
				log.Printf("Error sending Redis data to connection %s: %v", conn.ID, err)
				return
			}
			flusher.Flush()
			conn.LastSeen = time.Now()

			log.Printf("Redis message sent to connection %s: %s", conn.ID, msg.Payload)
		}
	}
}

// debugHandler provides debug information
func debugHandler(w http.ResponseWriter, r *http.Request) {
	data := map[string]interface{}{
		"current_time": time.Now().Format("15:04:05"),
		"server":       "Go SSE Server",
		"status":       "running",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}

func main() {
	// Get port from environment variable or use default
	port := os.Getenv("PORT")
	if port == "" {
		port = "3001"
	}
	port = ":" + port

	// Create SSE server
	sseServer := NewSSEServer()

	// Set up routes
	http.HandleFunc("/dashboard/stream", sseServer.streamHandler)
	http.HandleFunc("/dashboard/debug", debugHandler)

	// Health check
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("OK"))
	})

	log.Printf("🚀 Go SSE Server starting on port %s", port)
	log.Printf("📡 SSE endpoint: http://localhost%s/dashboard/stream", port)
	log.Printf("🔍 Debug endpoint: http://localhost%s/dashboard/debug", port)

	// Start server
	if err := http.ListenAndServe(port, nil); err != nil {
		log.Fatal("Server failed to start:", err)
	}
}
