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
)

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
	Debug      bool
	mu         sync.Mutex
}

// NewSSEClient creates a new SSE client
func NewSSEClient(id int, url string, connectTimeout time.Duration) *SSEClient {
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
		Debug:  false,
	}
}

// Connect establishes an SSE connection and listens for messages
func (s *SSEClient) Connect(ctx context.Context, onConnect func()) error {
	log.Printf("[Client %d] 🔗 Attempting to connect to %s", s.ID, s.URL)

	req, err := http.NewRequestWithContext(ctx, "GET", s.URL, nil)
	if err != nil {
		log.Printf("[Client %d] ❌ Failed to create request: %v", s.ID, err)
		return fmt.Errorf("failed to create request: %w", err)
	}

	// Set SSE headers
	req.Header.Set("Accept", "text/event-stream")
	req.Header.Set("Cache-Control", "no-cache")
	req.Header.Set("Connection", "keep-alive")

	log.Printf("[Client %d] 📤 Sending HTTP request...", s.ID)
	startTime := time.Now()
	resp, err := s.Client.Do(req)
	connectDuration := time.Since(startTime)

	if err != nil {
		log.Printf("[Client %d] ❌ HTTP request failed after %v: %v", s.ID, connectDuration, err)
		return fmt.Errorf("failed to connect: %w", err)
	}
	defer resp.Body.Close()

	log.Printf("[Client %d] 📥 Received response: status=%d, duration=%v", s.ID, resp.StatusCode, connectDuration)

	if resp.StatusCode != http.StatusOK {
		log.Printf("[Client %d] ❌ Unexpected status code: %d", s.ID, resp.StatusCode)
		return fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	s.mu.Lock()
	s.Connected = true
	s.mu.Unlock()

	log.Printf("[Client %d] ✅ Connected to SSE stream at %s", s.ID, s.URL)

	// Call the onConnect callback to notify of successful connection
	if onConnect != nil {
		onConnect()
	}

	log.Printf("[Client %d] 📡 Starting to read SSE stream...", s.ID)
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
		if len(trimmedLine) > 0 && s.Debug {
			log.Printf("[Client %d] 🔍 Raw SSE line: '%s'", s.ID, trimmedLine)
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
				log.Printf("[Client %d] 💓 Heartbeat received (#%d)", s.ID, s.Heartbeats)
			} else {
				log.Printf("[Client %d] 💓 Heartbeat: %s (#%d)", s.ID, heartbeat, s.Heartbeats)
			}
		} else if len(trimmedLine) > 0 {
			// Log any other non-empty lines for debugging
			log.Printf("[Client %d] 📝 Other SSE line: %s", s.ID, trimmedLine)
		}
	}

	if err := scanner.Err(); err != nil {
		log.Printf("[Client %d] ❌ Scanner error: %v", s.ID, err)
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
		log.Printf("[Client %d] ❌ Failed to parse message: %v", s.ID, err)
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
		url        = flag.String("url", "http://localhost:3000/dashboard/stream", "SSE endpoint URL")
		numClients = flag.Int("clients", 1, "Number of concurrent SSE clients")
		showStats  = flag.Bool("stats", false, "Show periodic statistics")
		timeout    = flag.Duration("timeout", 60*time.Second, "Connection timeout (0 = no timeout)")
		debug      = flag.Bool("debug", false, "Enable debug logging")
	)
	flag.Parse()

	if *numClients < 1 {
		log.Fatal("Number of clients must be at least 1")
	}

	log.Printf("🚀 Starting SSE load test with %d clients", *numClients)
	log.Printf("📡 Target URL: %s", *url)
	log.Printf("⏱️  Connection timeout: %v", *timeout)

	// Create context for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		log.Println("\n🛑 Shutting down gracefully...")
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
					log.Printf("📊 Stats: %d clients, %d messages, %d heartbeats, %d errors, %d successful connections, %d active, %d closed, %d failed",
						clients, messages, heartbeats, errors, successful, active, closed, failed)
				}
			}
		}()
	}

	// Start all SSE clients
	var wg sync.WaitGroup
	for i := 1; i <= *numClients; i++ {
		log.Printf("🚀 Starting client %d of %d", i, *numClients)
		wg.Add(1)
		go func(clientID int) {
			client := NewSSEClient(clientID, *url, *timeout)
			client.Debug = *debug

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
						log.Printf("[Client %d] 🔄 Graceful shutdown", clientID)
						return
					}

					// Check if context is done (graceful shutdown)
					select {
					case <-ctx.Done():
						log.Printf("[Client %d] 🔄 Graceful shutdown (context done)", clientID)
						return
					default:
						// This is a real connection error
						log.Printf("[Client %d] ❌ Connection error: %v", clientID, err)
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
		}(i)

		// Small delay between client starts to avoid overwhelming the server
		if i < *numClients {
			log.Printf("⏳ Waiting 100ms before starting next client...")
			time.Sleep(100 * time.Millisecond)
		}
	}

	// Wait for all clients to finish
	wg.Wait()

	// Final statistics
	clients, messages, heartbeats, errors, successful, active, closed, failed := stats.GetStats()
	log.Printf("\n📊 Final Statistics:")
	log.Printf("   Total Clients: %d", clients)
	log.Printf("   Total Messages: %d", messages)
	log.Printf("   Total Heartbeats: %d", heartbeats)
	log.Printf("   Total Errors: %d", errors)
	log.Printf("   Successful Connections: %d", successful)
	log.Printf("   Active Connections: %d", active)
	log.Printf("   Closed Connections: %d", closed)
	log.Printf("   Failed Connections: %d", failed)
	log.Printf("   Messages per Client: %.2f", float64(messages)/float64(clients))
	log.Printf("   Heartbeats per Client: %.2f", float64(heartbeats)/float64(clients))
}
