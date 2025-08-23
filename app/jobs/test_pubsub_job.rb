class TestPubsubJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting TestPubsubJob"
    
    # Generate test data
    test_data = {
      type: "test_update",
      message: "Test pub/sub broadcast from background job",
      timestamp: Time.current.strftime("%H:%M:%S"),
      random_value: rand(1000),
      job_id: SecureRandom.uuid[0..8],
      metrics: {
        cpu: "#{rand(20..80)}%",
        memory: "#{rand(40..90)}%",
        disk: "#{rand(10..50)}%",
        network: "#{rand(100..1000)} Mbps"
      },
      activities: [
        {
          time: Time.current.strftime("%H:%M:%S"),
          message: "Test activity from background job",
          level: "info",
          css_class: "activity-info"
        }
      ]
    }
    
    # Broadcast to SSE clients via pub/sub service
    pubsub_service = PubsubService.instance
    pubsub_service.publish('dashboard_updates', test_data)
    
    # Broadcast to WebSocket clients
    ActionCable.server.broadcast("dashboard_updates", test_data)
    
    Rails.logger.info "TestPubsubJob completed - broadcasted to #{sse_manager.stats[:total_connections]} SSE connections"
  end
end
