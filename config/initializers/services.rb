# Require all service classes
require_relative '../../lib/services/sse_manager'
require_relative '../../lib/services/pubsub_service'
require_relative '../../lib/services/redis_pubsub_service'
require_relative '../../lib/services/database_pubsub_service'

Rails.logger.info "✅ Services loaded: SseManager, PubsubService, RedisPubsubService, DatabasePubsubService"
