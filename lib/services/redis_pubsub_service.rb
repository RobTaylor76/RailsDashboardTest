class RedisPubsubService
  include Singleton

  def initialize
    @redis = nil
    @pubsub = nil
    @mutex = Mutex.new
    @connection_count = 0
  end

  # Get or create Redis connection with connection pooling
  def redis_connection
    @mutex.synchronize do
      if @redis.nil? || !@redis.connected?
        close_connections
        @redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379'))
        @connection_count += 1
        Rails.logger.info "Created Redis connection #{@connection_count}"
      end
      @redis
    end
  end

  # Get or create pubsub connection
  def pubsub_connection
    @mutex.synchronize do
      if @pubsub.nil? || !@pubsub.connected?
        close_pubsub_connection
        @pubsub = redis_connection.dup
        Rails.logger.info "Created Redis pubsub connection"
      end
      @pubsub
    end
  end

  # Check if pubsub connection is active
  def pubsub_active?
    @mutex.synchronize do
      @pubsub&.connected? || false
    end
  end

  # Publish data to a channel (called by background jobs)
  def publish(channel, data)
    redis = redis_connection
    redis.publish(channel, data.to_json)
    Rails.logger.info "Published to Redis channel '#{channel}': #{data[:type] || 'data'}"
  rescue => e
    Rails.logger.error "Redis publish error: #{e.message}"
    # Mark connection as potentially broken
    @mutex.synchronize { @redis = nil if @redis }
  end

  # Subscribe to a channel (called by web server)
  def subscribe(channel, &block)
    pubsub = pubsub_connection
    pubsub.subscribe(channel) do |on|
      on.message do |channel, message|
        begin
          data = JSON.parse(message)
          block.call(data)
        rescue => e
          # Handle different types of connection errors
          if e.message.include?('client disconnected') || 
             e.message.include?('Broken pipe') ||
             e.message.include?('Connection reset') ||
             e.message.include?('stream closed')
            Rails.logger.info "Redis pub/sub client disconnected: #{e.message}"
            break # Exit the subscription loop
          else
            Rails.logger.error "Error processing Redis message: #{e.message}"
          end
        end
      end
    end
  rescue => e
    Rails.logger.error "Redis subscribe error: #{e.message}"
    # Mark pubsub connection as potentially broken
    @mutex.synchronize { @pubsub = nil if @pubsub }
  end

  # Unsubscribe from a channel
  def unsubscribe(channel)
    pubsub = pubsub_connection
    pubsub.unsubscribe(channel)
  rescue => e
    Rails.logger.error "Redis unsubscribe error: #{e.message}"
  end

  # Close pubsub connection only
  def close_pubsub_connection
    if @pubsub
      @pubsub.close
      @pubsub = nil
      Rails.logger.info "Closed Redis pubsub connection"
    end
  rescue => e
    Rails.logger.error "Redis pubsub close error: #{e.message}"
  end

  # Close all connections
  def close_connections
    close_pubsub_connection
    if @redis
      @redis.close
      @redis = nil
      Rails.logger.info "Closed Redis connection"
    end
  rescue => e
    Rails.logger.error "Redis close error: #{e.message}"
  end

  # Get connection status
  def connection_status
    {
      redis_connected: @redis&.connected? || false,
      pubsub_connected: @pubsub&.connected? || false,
      pubsub_active: pubsub_active?,
      connection_count: @connection_count,
      last_activity: Time.current.strftime("%H:%M:%S")
    }
  end

  # Force cleanup of all connections (for debugging)
  def force_cleanup
    Rails.logger.info "Forcing cleanup of all Redis connections"
    close_connections
    @connection_count = 0
  end
end
