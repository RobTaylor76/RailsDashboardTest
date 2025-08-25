class DashboardUpdatesChannel < ApplicationCable::Channel
  def self.channel_name
    "dashboard_updates"
  end

  def subscribed
    Rails.logger.info "DashboardUpdatesChannel#subscribed called"
    stream_from "dashboard_updates"
    Rails.logger.info "Dashboard WebSocket client connected: #{connection.connection_identifier}"
  end

  def unsubscribed
    Rails.logger.info "DashboardUpdatesChannel#unsubscribed called"
    Rails.logger.info "Dashboard WebSocket client disconnected: #{connection.connection_identifier}"
  end
end
