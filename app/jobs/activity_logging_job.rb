class ActivityLoggingJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting activity logging job"
    
    # Generate random system activities
    activities = [
      { level: 'info', message: 'System check completed successfully' },
      { level: 'warning', message: 'High memory usage detected' },
      { level: 'error', message: 'Database connection timeout' },
      { level: 'info', message: 'Backup process started' },
      { level: 'warning', message: 'Disk space running low' }
    ]
    
    # Select a random activity
    activity = activities.sample
    Activity.log_info(activity[:message]) if activity[:level] == 'info'
    Activity.log_warning(activity[:message]) if activity[:level] == 'warning'
    Activity.log_error(activity[:message]) if activity[:level] == 'error'
    
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
    # For development with memory store, we'll just log the data
    # In production with Redis, this would push to connected SSE clients
    Rails.logger.info "SSE Update: #{data.to_json}"
    
    # Note: In a production environment with Redis, this would be:
    # Rails.cache.redis.keys("sse_connection_*").each do |key|
    #   begin
    #     stream = Rails.cache.read(key)
    #     if stream && stream.respond_to?(:write)
    #       stream.write("data: #{data.to_json}\n\n")
    #     end
    #   rescue => e
    #     Rails.logger.error "Error pushing to SSE client #{key}: #{e.message}"
    #     Rails.cache.delete(key)
    #   end
    # end
  end

  def reschedule_job
    self.class.set(wait: 2.minutes).perform_later
  end
end
