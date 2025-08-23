# Redis configuration for pub/sub system
require 'redis'

# Configure Redis connection
redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379')

begin
  # Test Redis connection on startup
  redis = Redis.new(url: redis_url)
  redis.ping
  Rails.logger.info "✅ Redis connection established: #{redis_url}"
  
  # Store Redis instance for reuse
  Rails.application.config.redis = redis
  
rescue => e
  Rails.logger.warn "⚠️  Redis connection failed: #{e.message}"
  Rails.logger.info "📊 Pub/sub system will fall back to database backend"
  Rails.application.config.redis = nil
end

# Configure Redis connection pool for ActionCable (if using Redis adapter)
if Rails.application.config.action_cable.cable_adapter == 'redis'
  Rails.application.config.action_cable.redis_url = redis_url
end
