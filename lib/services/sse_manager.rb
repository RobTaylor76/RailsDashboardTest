class SseManager
  include Singleton

  def initialize
    @connections = {}
    @mutex = Mutex.new
    @pubsub_service = PubsubService.instance
    
    # Start listening for pub/sub messages in a separate thread
    start_pubsub_listener
  end

  private

  def start_pubsub_listener
    Thread.new do
      Rails.logger.info "Starting pub/sub listener for SSE broadcasts"
      
      # For Redis backend, use subscription
      if @pubsub_service.instance_variable_get(:@backend) == :redis
        @pubsub_service.subscribe('dashboard_updates') do |data|
          broadcast_to_sse_clients(data)
        end
      else
        # For database backend, use polling
        poll_for_events
      end
    rescue => e
      Rails.logger.error "Pub/sub listener error: #{e.message}"
    end
  end

  def poll_for_events
    last_event_id = 0
    
    loop do
      sleep 1 # Poll every second
      
      events = @pubsub_service.poll_events('dashboard_updates', last_event_id)
      events.each do |event|
        broadcast_to_sse_clients(event.data)
        last_event_id = event.id
      end
    rescue => e
      Rails.logger.error "Event polling error: #{e.message}"
      sleep 5 # Wait longer on error
    end
  end

  # Register a new SSE connection
  def register_connection(connection_id, stream)
    @mutex.synchronize do
      @connections[connection_id] = {
        stream: stream,
        created_at: Time.current,
        last_activity: Time.current
      }
      Rails.logger.info "SSE connection registered: #{connection_id} (total: #{@connections.size})"
    end
  end

  # Remove a SSE connection
  def remove_connection(connection_id)
    @mutex.synchronize do
      @connections.delete(connection_id)
      Rails.logger.info "SSE connection removed: #{connection_id} (total: #{@connections.size})"
    end
  end

  # Broadcast data to all connected SSE clients
  def broadcast(data)
    # This method is now deprecated - use broadcast_to_sse_clients instead
    broadcast_to_sse_clients(data)
  end

  # Broadcast data to all connected SSE clients (internal method)
  def broadcast_to_sse_clients(data)
    @mutex.synchronize do
      Rails.logger.info "Broadcasting to #{@connections.size} SSE connections"
      
      @connections.each do |connection_id, connection_info|
        begin
          stream = connection_info[:stream]
          if stream && stream.respond_to?(:write)
            stream.write("data: #{data.to_json}\n\n")
            connection_info[:last_activity] = Time.current
            Rails.logger.debug "Sent update to SSE client: #{connection_id}"
          else
            Rails.logger.warn "Invalid stream for SSE client: #{connection_id}"
            @connections.delete(connection_id)
          end
        rescue => e
          Rails.logger.error "Error sending to SSE client #{connection_id}: #{e.message}"
          @connections.delete(connection_id)
        end
      end
    end
  end

  # Get connection statistics
  def stats
    @mutex.synchronize do
      {
        total_connections: @connections.size,
        connections: @connections.map do |id, info|
          {
            id: id,
            created_at: info[:created_at],
            last_activity: info[:last_activity],
            age_seconds: (Time.current - info[:created_at]).to_i
          }
        end
      }
    end
  end

  # Clean up stale connections
  def cleanup_stale_connections(max_age_seconds = 3600) # 1 hour
    @mutex.synchronize do
      now = Time.current
      stale_connections = @connections.select do |id, info|
        (now - info[:last_activity]) > max_age_seconds
      end
      
      stale_connections.each do |id, _|
        @connections.delete(id)
        Rails.logger.info "Removed stale SSE connection: #{id}"
      end
      
      Rails.logger.info "Cleaned up #{stale_connections.size} stale SSE connections"
    end
  end

  # Generate a unique connection ID
  def generate_connection_id
    SecureRandom.uuid
  end
end
