class MetricCollectionJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting metric collection job"
    
    # Collect simulated metrics
    cpu_usage = rand(10..90)
    memory_usage = rand(50..95)
    disk_usage = rand(30..80)
    network_speed = rand(5..50)
    
    # Create metric records
    Metric.create_metric(name: 'cpu', value: cpu_usage, unit: '%', category: 'cpu')
    Metric.create_metric(name: 'memory', value: memory_usage, unit: '%', category: 'memory')
    Metric.create_metric(name: 'disk', value: disk_usage, unit: '%', category: 'disk')
    Metric.create_metric(name: 'network', value: network_speed, unit: 'MB/s', category: 'network')
    
    # Log activity
    Activity.log_info("Metrics collected successfully")
    
    # Push update to all connected SSE clients
    broadcast_sse_update
    
    # Reschedule the job
    reschedule_job
  end

  private

  def broadcast_sse_update
    # Load fresh data
    system_status = SystemStatus.current_status
    cpu_metric = Metric.latest_by_category('cpu')
    memory_metric = Metric.latest_by_category('memory')
    disk_metric = Metric.latest_by_category('disk')
    network_metric = Metric.latest_by_category('network')
    recent_activities = Activity.latest(5)
    response_time = rand(50..200)
    
    data = {
      system_status: {
        status: system_status.status,
        uptime: system_status.formatted_uptime,
        last_check: system_status.last_check.strftime("%H:%M:%S"),
        message: system_status.details&.dig('message') || 'No status message'
      },
      metrics: {
        cpu: cpu_metric ? "#{cpu_metric.value}#{cpu_metric.unit}" : '--',
        memory: memory_metric ? "#{memory_metric.value}#{memory_metric.unit}" : '--',
        disk: disk_metric ? "#{disk_metric.value}#{disk_metric.unit}" : '--',
        network: network_metric ? "#{network_metric.value} #{network_metric.unit}" : '--',
        response_time: "#{response_time}ms"
      },
      activities: recent_activities.map do |activity|
        {
          time: activity.formatted_time,
          message: activity.message,
          level: activity.level,
          css_class: activity.css_class
        }
      end,
      timestamp: Time.current.strftime("%H:%M:%S")
    }
    
    # Push to all connected SSE clients
    push_to_sse_clients(data)
    
    # Also broadcast to WebSocket clients
    ActionCable.server.broadcast("dashboard_updates", data)
    
    Rails.logger.info "Pushed dashboard update via SSE and WebSocket"
  end

  def push_to_sse_clients(data)
    # Publish to pub/sub service for cross-process communication
    pubsub_service = PubsubService.instance
    pubsub_service.publish('dashboard_updates', data)
  end

  def reschedule_job
    self.class.set(wait: 30.seconds).perform_later
  end
end
