class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  before_action :require_login
  before_action :log_request_details
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_csrf_error
  
  private
  
  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
  
  def logged_in?
    !!current_user
  end
  
  def require_login
    unless logged_in?
      redirect_to login_path, alert: 'You must be logged in to access this page.'
    end
  end
  
  def log_request_details
    Rails.logger.info "=== HTTP REQUEST DETAILS ==="
    Rails.logger.info "Method: #{request.method}"
    Rails.logger.info "URL: #{request.url}"
    Rails.logger.info "Path: #{request.path}"
    Rails.logger.info "Query String: #{request.query_string}"
    Rails.logger.info "Remote IP: #{request.remote_ip}"
    Rails.logger.info "User Agent: #{request.user_agent}"
    Rails.logger.info "Referer: #{request.referer}"
    Rails.logger.info "Request ID: #{request.request_id}"
    
    # HTTP Headers (comprehensive)
    Rails.logger.info "=== HTTP HEADERS ==="
    request.headers.each do |key, value|
      Rails.logger.info "#{key}: #{value}"
    end
    
    # Request Parameters
    Rails.logger.info "=== REQUEST PARAMETERS ==="
    begin
      Rails.logger.info "Params: #{params.to_unsafe_h}"
    rescue => e
      Rails.logger.info "Params (error): #{e.message}"
    end
    Rails.logger.info "Query params: #{request.query_parameters}"
    Rails.logger.info "Body params: #{request.request_parameters}"
    
    # CSRF Token Information (for POST/PUT/PATCH/DELETE)
    if %w[POST PUT PATCH DELETE].include?(request.method)
      Rails.logger.info "=== CSRF TOKEN INFO ==="
      Rails.logger.info "CSRF Token from params: #{params[:authenticity_token]}"
      Rails.logger.info "CSRF Token from headers: #{request.headers['X-CSRF-Token']}"
      Rails.logger.info "Session CSRF Token: #{session[:_csrf_token]}"
      Rails.logger.info "Form authenticity token: #{form_authenticity_token}"
      Rails.logger.info "Valid CSRF Token: #{valid_authenticity_token?(session, params[:authenticity_token])}"
    end
    
    # Cookie Information
    Rails.logger.info "=== COOKIE INFO ==="
    Rails.logger.info "All cookies: #{request.cookies.to_h}"
    Rails.logger.info "Session data: #{session.to_h}"
    Rails.logger.info "Session ID: #{session.id}"
    
    # Request Body (for POST/PUT/PATCH)
    if %w[POST PUT PATCH].include?(request.method) && request.body.present?
      Rails.logger.info "=== REQUEST BODY ==="
      Rails.logger.info "Content-Type: #{request.content_type}"
      Rails.logger.info "Content-Length: #{request.content_length}"
      begin
        body = request.body.read
        request.body.rewind
        Rails.logger.info "Body: #{body}"
      rescue => e
        Rails.logger.info "Body (error reading): #{e.message}"
      end
    end
    
    # Response preparation
    Rails.logger.info "=== RESPONSE PREPARATION ==="
    Rails.logger.info "Format: #{request.format}"
    Rails.logger.info "AJAX Request: #{request.xhr?}"
    Rails.logger.info "JSON Request: #{request.format.json?}"
    
    Rails.logger.info "=== END HTTP REQUEST DETAILS ==="
  end
  
  def handle_csrf_error(exception)
    Rails.logger.error "=== CSRF ERROR OCCURRED ==="
    Rails.logger.error "Exception: #{exception.message}"
    Rails.logger.error "Backtrace: #{exception.backtrace.first(10).join("\n")}"
    
    # Log additional context for CSRF failures
    Rails.logger.error "=== CSRF FAILURE CONTEXT ==="
    Rails.logger.error "Request method: #{request.method}"
    Rails.logger.error "Request path: #{request.path}"
    Rails.logger.error "Submitted token: #{params[:authenticity_token]}"
    Rails.logger.error "Expected token: #{session[:_csrf_token]}"
    Rails.logger.error "Token from header: #{request.headers['X-CSRF-Token']}"
    Rails.logger.error "Session ID: #{session.id}"
    Rails.logger.error "User ID in session: #{session[:user_id]}"
    
    # Return appropriate response
    if request.xhr? || request.format.json?
      render json: { error: 'CSRF token verification failed' }, status: :forbidden
    else
      redirect_to login_path, alert: 'Security token expired. Please try again.'
    end
  end
  
  helper_method :current_user, :logged_in?
end
