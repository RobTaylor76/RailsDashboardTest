class PubsubEvent < ApplicationRecord
  validates :channel, presence: true
  validates :data, presence: true

  # Create a new event and trigger cleanup
  def self.publish(channel, data)
    create!(
      channel: channel,
      data: data,
      created_at: Time.current
    )
    
    # Clean up old events (keep last 1000)
    cleanup_old_events
  end

  # Get recent events for a channel
  def self.recent_for_channel(channel, limit = 10)
    where(channel: channel)
      .order(created_at: :desc)
      .limit(limit)
  end

  # Clean up old events
  def self.cleanup_old_events
    # Keep only the last 1000 events
    count = count
    if count > 1000
      # Delete oldest events beyond the limit
      offset = count - 1000
      order(:created_at).limit(offset).delete_all
    end
  end

  # Poll for new events (for SSE manager)
  def self.poll_for_new_events(channel, since_id = nil)
    query = where(channel: channel)
    query = query.where('id > ?', since_id) if since_id
    query.order(:created_at).limit(50)
  end
end
