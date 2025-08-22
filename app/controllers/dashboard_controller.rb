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
      format.json { render json: dashboard_data_json }
    end
  end

  def test_action_cable
    # Test Action Cable broadcast
    ActionCable.server.broadcast("dashboard_updates", {
      message: "Action Cable test",
      timestamp: Time.current.strftime("%H:%M:%S"),
      status: "working"
    })
    
    render json: { message: "Action Cable test broadcast sent" }
  end

  def stream_test
    # Simple test endpoint
    render json: { message: "Test endpoint working", timestamp: Time.current.strftime("%H:%M:%S") }
  end

  def sse_test
    # SSE test page - load initial data
    load_dashboard_data
  end

  def trigger_jobs
    # Manually trigger jobs for testing
    MetricCollectionJob.perform_later
    ActivityLoggingJob.perform_later
    StatusCheckJob.perform_later
    
    redirect_to root_path, notice: "Background jobs triggered successfully"
  end

  def test_auto_refresh
    # Simple test page to verify auto-refresh
    @current_time = Time.current.strftime("%H:%M:%S")
    @system_status = SystemStatus.current_status
  end

  def debug
    # Debug endpoint to check if everything is working
    @debug_info = {
      current_time: Time.current.strftime("%H:%M:%S"),
      system_status: SystemStatus.current_status.last_check.strftime("%H:%M:%S"),
      metrics_count: Metric.count,
      activities_count: Activity.count,
      jobs_running: true
    }
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

  def dashboard_data_json
    {
      system_status: {
        status: @system_status.status,
        uptime: @system_status.formatted_uptime,
        last_check: @system_status.last_check.strftime("%H:%M:%S"),
        message: @system_status.details&.dig('message') || 'No status message'
      },
      metrics: {
        cpu: @cpu_metric ? "#{@cpu_metric.value}#{@cpu_metric.unit}" : '--',
        memory: @memory_metric ? "#{@memory_metric.value}#{@memory_metric.unit}" : '--',
        disk: @disk_metric ? "#{@disk_metric.value}#{@disk_metric.unit}" : '--',
        network: @network_metric ? "#{@network_metric.value} #{@network_metric.unit}" : '--',
        response_time: "#{@response_time}ms"
      },
      activities: @recent_activities.map do |activity|
        {
          time: activity.formatted_time,
          message: activity.message,
          level: activity.level,
          css_class: activity.css_class
        }
      end,
      timestamp: Time.current.strftime("%H:%M:%S")
    }
  end
end 