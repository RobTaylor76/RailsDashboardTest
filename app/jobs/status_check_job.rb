class StatusCheckJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting status check job"
    
    # Get latest metrics to determine system health
    cpu_metric = Metric.latest_by_category('cpu')
    memory_metric = Metric.latest_by_category('memory')
    
    # Determine system status based on metrics
    new_status = determine_system_status(cpu_metric, memory_metric)
    
    # Update system status
    SystemStatus.update_status(status: new_status)
    
    # Log status change
    if new_status != 'online'
      Activity.log_warning("System status changed to #{new_status}")
    end
    
    # Push update to all connected SSE clients
    broadcast_sse_update
    
    # Reschedule the job
    reschedule_job
  end

  private

  def determine_system_status(cpu_metric, memory_metric)
    return 'offline' unless cpu_metric && memory_metric
    
    cpu_usage = cpu_metric.value.to_f
    memory_usage = memory_metric.value.to_f
    
    if cpu_usage > 90 || memory_usage > 95
      'offline'
    elsif cpu_usage > 70 || memory_usage > 80
      'warning'
    else
      'online'
    end
  end

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
