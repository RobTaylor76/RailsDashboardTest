class ActivityLoggingJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting activity logging job"
    
    # Simulate various system activities
    activities = generate_system_activities
    
    activities.each do |activity|
      Activity.create!(
        message: activity[:message],
        level: activity[:level],
        source: activity[:source],
        timestamp: Time.current
      )
    end
    
    Rails.logger.info "Activity logging job completed"
    
    # Reschedule the job for the next execution
    reschedule_job
  end

  private

  def reschedule_job
    # Schedule the next execution
    self.class.set(wait: 2.minutes).perform_later
    Rails.logger.info "Activity logging job rescheduled for 2 minutes from now"
  end

  def generate_system_activities
    activities = []
    
    # Random chance to generate different types of activities
    case rand(1..10)
    when 1..3
      # Normal info activities
      activities << {
        message: "System health check completed",
        level: "info",
        source: "health_check"
      }
    when 4..6
      # Warning activities
      activities << {
        message: "High memory usage detected",
        level: "warning",
        source: "monitoring"
      }
    when 7..8
      # Error activities (rare)
      activities << {
        message: "Database connection timeout",
        level: "error",
        source: "database"
      }
    when 9..10
      # Multiple activities
      activities << {
        message: "Cache refreshed",
        level: "info",
        source: "cache"
      }
      activities << {
        message: "Background job completed",
        level: "info",
        source: "jobs"
      }
    end
    
    activities
  end
end
