class MetricCollectionJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting metric collection job"
    
    # Collect CPU usage (simulated)
    cpu_usage = collect_cpu_usage
    Metric.create_metric(
      name: "cpu_usage",
      value: cpu_usage,
      unit: "%",
      category: "cpu"
    )

    # Collect memory usage (simulated)
    memory_usage = collect_memory_usage
    Metric.create_metric(
      name: "memory_usage",
      value: memory_usage,
      unit: "%",
      category: "memory"
    )

    # Collect disk usage (simulated)
    disk_usage = collect_disk_usage
    Metric.create_metric(
      name: "disk_usage",
      value: disk_usage,
      unit: "%",
      category: "disk"
    )

    # Collect network usage (simulated)
    network_usage = collect_network_usage
    Metric.create_metric(
      name: "network_usage",
      value: network_usage,
      unit: "MB/s",
      category: "network"
    )

    # Log activity
    Activity.log_info("Metrics collected successfully", source: "metric_collection_job")
    
    Rails.logger.info "Metric collection job completed"
    
    # Reschedule the job for the next execution
    reschedule_job
  end

  private

  def reschedule_job
    # Schedule the next execution
    self.class.set(wait: 30.seconds).perform_later
    Rails.logger.info "Metric collection job rescheduled for 30 seconds from now"
  end

  def collect_cpu_usage
    # Simulate CPU usage with some variation
    base_usage = 30
    variation = rand(-10..20)
    usage = base_usage + variation
    
    # Ensure usage is within reasonable bounds
    [usage, 100].min
  end

  def collect_memory_usage
    # Simulate memory usage
    base_usage = 60
    variation = rand(-15..25)
    usage = base_usage + variation
    
    # Ensure usage is within reasonable bounds
    [usage, 100].min
  end

  def collect_disk_usage
    # Simulate disk usage (slower changing)
    base_usage = 50
    variation = rand(-5..10)
    usage = base_usage + variation
    
    # Ensure usage is within reasonable bounds
    [usage, 100].min
  end

  def collect_network_usage
    # Simulate network usage
    base_usage = 15
    variation = rand(-8..15)
    usage = base_usage + variation
    
    # Ensure usage is positive
    [usage, 0].max
  end
end
