class DashboardUpdatesChannel < ApplicationCable::Channel
  def subscribed
    stream_from "dashboard_updates"
    Rails.logger.info "Dashboard WebSocket client connected: #{connection.uuid}"
  end

  def unsubscribed
    Rails.logger.info "Dashboard WebSocket client disconnected: #{connection.uuid}"
  end
end
