# Job Scheduler for Dashboard
# This initializer sets up periodic background jobs

Rails.application.config.after_initialize do
  # Only schedule jobs in development and production
  unless Rails.env.test?
    schedule_jobs
  end
end

def schedule_jobs
  # Schedule metric collection every 30 seconds
  MetricCollectionJob.set(wait: 30.seconds).perform_later
  
  # Schedule activity logging every 2 minutes
  ActivityLoggingJob.set(wait: 2.minutes).perform_later
  
  # Schedule status check every 30 seconds
  StatusCheckJob.set(wait: 30.seconds).perform_later
  
  Rails.logger.info "Dashboard jobs scheduled"
rescue => e
  Rails.logger.error "Failed to schedule dashboard jobs: #{e.message}"
end 