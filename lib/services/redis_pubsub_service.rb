class RedisPubsubService
  include Singleton

  def initialize
    @redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379'))
    @pubsub = @redis.dup
  end

  # Publish data to a channel (called by background jobs)
  def publish(channel, data)
    @redis.publish(channel, data.to_json)
    Rails.logger.info "Published to Redis channel '#{channel}': #{data[:type] || 'data'}"
  rescue => e
    Rails.logger.error "Redis publish error: #{e.message}"
  end

  # Subscribe to a channel (called by web server)
  def subscribe(channel, &block)
    @pubsub.subscribe(channel) do |on|
      on.message do |channel, message|
        begin
          data = JSON.parse(message)
          block.call(data)
        rescue => e
          Rails.logger.error "Error processing Redis message: #{e.message}"
        end
      end
    end
  rescue => e
    Rails.logger.error "Redis subscribe error: #{e.message}"
  end

  # Unsubscribe from a channel
  def unsubscribe(channel)
    @pubsub.unsubscribe(channel)
  rescue => e
    Rails.logger.error "Redis unsubscribe error: #{e.message}"
  end

  # Close connections
  def close
    @redis.close
    @pubsub.close
  rescue => e
    Rails.logger.error "Redis close error: #{e.message}"
  end
end
