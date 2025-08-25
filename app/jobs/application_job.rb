class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # Ensure Redis connections are properly cleaned up after job execution
  after_perform :cleanup_redis_connections

  private

  def cleanup_redis_connections
    # Clean up any Redis connections that may have been created during job execution
    if defined?(RedisPubsubService)
      begin
        RedisPubsubService.instance.force_cleanup
        Rails.logger.info "Cleaned up Redis connections after job: #{self.class.name}"
      rescue => e
        Rails.logger.warn "Failed to cleanup Redis connections: #{e.message}"
      end
    end
  end
end
