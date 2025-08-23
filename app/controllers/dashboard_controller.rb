class DashboardController < ApplicationController
  include ActionController::Live
  layout 'dashboard'
  
  helper_method :controller_action_to_controller_name
  
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

  def stream
    # SSE endpoint for real-time updates using direct Redis pub/sub
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['Connection'] = 'keep-alive'
    response.headers['X-Accel-Buffering'] = 'no'
    
    # Send initial data
    load_dashboard_data
    data = dashboard_data_json
    response.stream.write("data: #{data.to_json}\n\n")
    
    # Subscribe directly to Redis pub/sub for this connection
    pubsub_service = PubsubService.instance
    
    if pubsub_service.instance_variable_get(:@backend) == :redis
      # Create a dedicated Redis connection for this stream
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379'))
      pubsub = redis.dup
      
      begin
        # Subscribe to dashboard_updates channel
        pubsub.subscribe('dashboard_updates') do |on|
          on.message do |channel, message|
            begin
              data = JSON.parse(message)
              response.stream.write("data: #{data.to_json}\n\n")
            rescue => e
              Rails.logger.error "Error processing Redis message: #{e.message}"
            end
          end
        end
      rescue => e
        Rails.logger.error "Redis pub/sub error: #{e.message}"
      ensure
        pubsub.close
        redis.close
      end
    else
      # Fallback to database polling if Redis is not available
      last_event_id = 0
      loop do
        sleep 1 # Poll every second
        
        events = pubsub_service.poll_events('dashboard_updates', last_event_id)
        events.each do |event|
          response.stream.write("data: #{event.data.to_json}\n\n")
          last_event_id = event.id
        end
      rescue => e
        Rails.logger.error "Database pub/sub error: #{e.message}"
        sleep 5 # Wait longer on error
      end
    end
  rescue => e
    Rails.logger.error "SSE Stream Error: #{e.message}"
  ensure
    response.stream.close if response.stream
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

  def websocket_test
    # WebSocket test page - load initial data
    load_dashboard_data
  end

  def trigger_jobs
    # Manually trigger jobs for testing
    MetricCollectionJob.perform_later
    ActivityLoggingJob.perform_later
    StatusCheckJob.perform_later
    
    redirect_to root_path, notice: "Background jobs triggered successfully"
  end

  def trigger_test_pubsub
    # Trigger the test pub/sub job
    TestPubsubJob.perform_later
    
    render json: { 
      message: "Test pub/sub job triggered successfully",
      timestamp: Time.current.strftime("%H:%M:%S"),
      sse_connections: SseManager.instance.stats[:total_connections]
    }
  end

  def test_auto_refresh
    # Simple test page to verify auto-refresh
    @current_time = Time.current.strftime("%H:%M:%S")
    @system_status = SystemStatus.current_status
  end

  def debug
    # Debug endpoint to check if everything is working
    begin
      sse_manager = SseManager.instance
      sse_stats = sse_manager.stats
    rescue => e
      sse_stats = { total_connections: 0, connections: [] }
      Rails.logger.warn "Could not get SSE stats: #{e.message}"
    end
    
    begin
      pubsub_service = PubsubService.instance
      pubsub_backend = pubsub_service.instance_variable_get(:@backend)
    rescue => e
      pubsub_backend = :unknown
      Rails.logger.warn "Could not get pub/sub backend: #{e.message}"
    end
    
    @debug_info = {
      current_time: Time.current.strftime("%H:%M:%S"),
      system_status: SystemStatus.current_status.last_check.strftime("%H:%M:%S"),
      metrics_count: Metric.count,
      activities_count: Activity.count,
      jobs_running: true,
      services_loaded: defined?(SseManager) ? "Yes" : "No",
      sse_connections: sse_stats,
      pubsub_backend: pubsub_backend,
      pubsub_events_count: PubsubEvent.count
    }
  end

  def metrics
    # This will serve real-time metrics data
    # We'll implement this in Phase 3
    @metrics = Metric.recent.limit(20)
  end

  private

  def controller_action_to_controller_name
    case action_name
    when 'sse_test'
      'sse-dashboard'
    when 'websocket_test'
      'websocket-dashboard'
    else
      'dashboard'
    end
  end

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