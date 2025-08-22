class DashboardController < ApplicationController
  layout 'dashboard'
  
  def index
    load_dashboard_data
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def refresh
    load_dashboard_data
    
    respond_to do |format|
      format.turbo_stream { render :index }
    end
  end

  def trigger_jobs
    # Manually trigger jobs for testing
    MetricCollectionJob.perform_later
    ActivityLoggingJob.perform_later
    StatusCheckJob.perform_later
    
    redirect_to root_path, notice: "Background jobs triggered successfully"
  end

  def metrics
    # This will serve real-time metrics data
    # We'll implement this in Phase 3
    @metrics = Metric.recent.limit(20)
  end

  private

  def load_dashboard_data
    # Fetch current system status
    @system_status = SystemStatus.current_status
    
    # Fetch latest metrics by category
    @cpu_metric = Metric.latest_by_category('cpu')
    @memory_metric = Metric.latest_by_category('memory')
    @disk_metric = Metric.latest_by_category('disk')
    @network_metric = Metric.latest_by_category('network')
    
    # Fetch recent activities
    @recent_activities = Activity.latest(5)
    
    # Calculate response time (simulated for now)
    @response_time = rand(50..200) # milliseconds
  end
end 