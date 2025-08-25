# SSE Configuration
# This file configures the SSE endpoint settings for the dashboard

module SSEConfig
  # SSE Server Configuration
  SSE_HOST = ENV.fetch('SSE_HOST', 'localhost')
  SSE_PORT = ENV.fetch('SSE_PORT', '3001').to_i
  SSE_ENDPOINT = ENV.fetch('SSE_ENDPOINT', '/dashboard/stream')
  
  # Determine which server to use for SSE
  SSE_SERVER_TYPE = ENV.fetch('SSE_SERVER_TYPE', 'go').downcase # 'go' or 'rails'
  
  # Auto-refresh configuration
  SSE_AUTO_REFRESH = ENV.fetch('SSE_AUTO_REFRESH', 'true').downcase == 'true'
  
  # Connection timeout and retry settings
  SSE_CONNECTION_TIMEOUT = ENV.fetch('SSE_CONNECTION_TIMEOUT', '5000').to_i
  SSE_RETRY_INTERVAL = ENV.fetch('SSE_RETRY_INTERVAL', '5000').to_i
  
  # Get the full SSE URL
  def self.sse_url
    if SSE_SERVER_TYPE == 'go'
      "http://#{SSE_HOST}:#{SSE_PORT}#{SSE_ENDPOINT}"
    else
      SSE_ENDPOINT
    end
  end
  
  # Get configuration hash for JavaScript
  def self.js_config
    {
      sse_endpoint: SSE_ENDPOINT,
      sse_port: SSE_PORT,
      sse_host: SSE_HOST,
      sse_server_type: SSE_SERVER_TYPE,
      auto_refresh: SSE_AUTO_REFRESH,
      connection_timeout: SSE_CONNECTION_TIMEOUT,
      retry_interval: SSE_RETRY_INTERVAL
    }
  end
  
  # Log configuration on startup
  Rails.logger.info "🔧 SSE Configuration:"
  Rails.logger.info "   Server Type: #{SSE_SERVER_TYPE}"
  Rails.logger.info "   Host: #{SSE_HOST}"
  Rails.logger.info "   Port: #{SSE_PORT}"
  Rails.logger.info "   Endpoint: #{SSE_ENDPOINT}"
  Rails.logger.info "   Full URL: #{sse_url}"
  Rails.logger.info "   Auto-refresh: #{SSE_AUTO_REFRESH}"
end
