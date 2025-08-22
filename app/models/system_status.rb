class SystemStatus < ApplicationRecord
  # Validations
  validates :status, presence: true, inclusion: { in: %w[online offline warning] }
  validates :uptime, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :last_check, presence: true

  # Scopes
  scope :latest, -> { order(last_check: :desc).limit(1) }
  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { where('last_check >= ?', 5.minutes.ago) }

  # Class methods
  def self.current_status
    latest.first || create_default_status
  end

  def self.update_status(status:, uptime: nil, details: {})
    current = current_status
    current.update!(
      status: status,
      uptime: uptime || current.uptime,
      last_check: Time.current,
      details: details
    )
    current
  end

  def self.create_default_status
    create!(
      status: 'online',
      uptime: 0,
      last_check: Time.current,
      details: { message: 'System initialized' }
    )
  end

  # Instance methods
  def online?
    status == 'online'
  end

  def offline?
    status == 'offline'
  end

  def warning?
    status == 'warning'
  end

  def formatted_uptime
    hours = uptime / 3600
    minutes = (uptime % 3600) / 60
    seconds = uptime % 60
    
    if hours > 0
      "#{hours}h #{minutes}m #{seconds}s"
    elsif minutes > 0
      "#{minutes}m #{seconds}s"
    else
      "#{seconds}s"
    end
  end

  def status_css_class
    case status
    when 'online'
      'status-online'
    when 'offline'
      'status-offline'
    when 'warning'
      'status-warning'
    else
      'status-unknown'
    end
  end
end
