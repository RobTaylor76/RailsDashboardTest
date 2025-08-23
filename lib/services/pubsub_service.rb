class PubsubService
  include Singleton

  def initialize
    @backend = determine_backend
    Rails.logger.info "PubSub Service initialized with backend: #{@backend}"
  end

  # Publish data to a channel (called by background jobs)
  def publish(channel, data)
    case @backend
    when :redis
      RedisPubsubService.instance.publish(channel, data)
    when :database
      DatabasePubsubService.instance.publish(channel, data)
    else
      Rails.logger.error "No pub/sub backend configured"
    end
  end

  # Subscribe to a channel (called by web server)
  def subscribe(channel, &block)
    case @backend
    when :redis
      RedisPubsubService.instance.subscribe(channel, &block)
    when :database
      # Database backend uses polling instead of subscription
      Rails.logger.warn "Database backend doesn't support real-time subscription"
    else
      Rails.logger.error "No pub/sub backend configured"
    end
  end

  # Poll for events (database backend only)
  def poll_events(channel, since_id = nil)
    case @backend
    when :database
      DatabasePubsubService.instance.poll_events(channel, since_id)
    else
      []
    end
  end

  private

  def determine_backend
    # Check if Redis is available
    if redis_available?
      :redis
    else
      :database
    end
  end

  def redis_available?
    return false unless defined?(Redis)
    
    begin
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379'))
      redis.ping
      redis.close
      true
    rescue => e
      Rails.logger.warn "Redis not available: #{e.message}"
      false
    end
  end
end
