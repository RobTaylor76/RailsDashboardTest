class DashboardUpdatesChannel < ApplicationCable::Channel
  def subscribed
    stream_from "dashboard_updates"
    Rails.logger.info "Dashboard SSE client connected: #{connection.id}"
  end

  def unsubscribed
    Rails.logger.info "Dashboard SSE client disconnected: #{connection.id}"
  end
end
