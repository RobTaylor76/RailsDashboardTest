# Job Scheduler for Dashboard
# This initializer sets up periodic background jobs

Rails.application.config.after_initialize do
  # Only schedule jobs in development and production
  unless Rails.env.test?
    schedule_jobs
  end
end

def schedule_jobs
  # Start the initial jobs immediately
  MetricCollectionJob.perform_later
  ActivityLoggingJob.perform_later
  StatusCheckJob.perform_later
  
  # Also schedule them with delays to ensure they run continuously
  MetricCollectionJob.set(wait: 30.seconds).perform_later
  StatusCheckJob.set(wait: 30.seconds).perform_later
  ActivityLoggingJob.set(wait: 2.minutes).perform_later
  
  Rails.logger.info "Dashboard jobs started with continuous scheduling"
rescue => e
  Rails.logger.error "Failed to start dashboard jobs: #{e.message}"
end 