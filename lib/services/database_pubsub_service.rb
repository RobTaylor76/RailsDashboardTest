class DatabasePubsubService
  include Singleton

  def initialize
    @last_event_id = 0
  end

  # Publish data to a channel (called by background jobs)
  def publish(channel, data)
    PubsubEvent.publish(channel, data)
    Rails.logger.info "Published to database channel '#{channel}': #{data[:type] || 'data'}"
  rescue => e
    Rails.logger.error "Database publish error: #{e.message}"
  end

  # Poll for new events (called by web server)
  def poll_events(channel, since_id = nil)
    since_id ||= @last_event_id
    events = PubsubEvent.poll_for_new_events(channel, since_id)
    
    if events.any?
      @last_event_id = events.last.id
    end
    
    events
  rescue => e
    Rails.logger.error "Database poll error: #{e.message}"
    []
  end

  # Get the latest event ID for a channel
  def latest_event_id(channel)
    PubsubEvent.where(channel: channel).maximum(:id) || 0
  rescue => e
    Rails.logger.error "Database latest_event_id error: #{e.message}"
    0
  end
end
