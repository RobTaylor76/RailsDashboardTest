class StatusCheckJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting status check job"
    
    # Get current status
    current_status = SystemStatus.current_status
    
    # Check system health
    health_status = check_system_health
    
    # Update system status
    SystemStatus.update_status(
      status: health_status[:status],
      uptime: health_status[:uptime],
      details: health_status[:details]
    )
    
    # Log status change if significant
    if health_status[:status] != current_status.status
      Activity.log_warning(
        "System status changed to #{health_status[:status]}",
        source: "status_check_job"
      )
    end
    
    Rails.logger.info "Status check job completed"
  end

  private

  def check_system_health
    # Simulate system health check
    cpu_metric = Metric.latest_by_category('cpu')
    memory_metric = Metric.latest_by_category('memory')
    
    # Determine status based on metrics
    status = determine_status(cpu_metric, memory_metric)
    
    # Calculate uptime (increment by job interval)
    uptime = SystemStatus.current_status.uptime + 30 # 30 seconds
    
    # Prepare details
    details = {
      message: generate_status_message(status),
      cpu_usage: cpu_metric&.value,
      memory_usage: memory_metric&.value,
      last_check: Time.current.iso8601
    }
    
    {
      status: status,
      uptime: uptime,
      details: details
    }
  end

  def determine_status(cpu_metric, memory_metric)
    return 'offline' unless cpu_metric && memory_metric
    
    cpu_usage = cpu_metric.value
    memory_usage = memory_metric.value
    
    # Determine status based on thresholds
    if cpu_usage > 90 || memory_usage > 95
      'warning'
    elsif cpu_usage > 70 || memory_usage > 80
      'warning'
    else
      'online'
    end
  end

  def generate_status_message(status)
    case status
    when 'online'
      "System running normally"
    when 'warning'
      "System under moderate load"
    when 'offline'
      "System unavailable"
    else
      "System status unknown"
    end
  end
end
