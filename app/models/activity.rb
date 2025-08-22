class Activity < ApplicationRecord
  # Validations
  validates :message, presence: true
  validates :level, presence: true, inclusion: { in: %w[info warning error] }
  validates :source, presence: true
  validates :timestamp, presence: true

  # Scopes
  scope :recent, -> { order(timestamp: :desc) }
  scope :by_level, ->(level) { where(level: level) }
  scope :by_source, ->(source) { where(source: source) }
  scope :latest, ->(limit = 10) { recent.limit(limit) }
  scope :last_hour, -> { where('timestamp >= ?', 1.hour.ago) }
  scope :last_24_hours, -> { where('timestamp >= ?', 24.hours.ago) }

  # Class methods
  def self.log_info(message, source: 'system')
    create!(
      message: message,
      level: 'info',
      source: source,
      timestamp: Time.current
    )
  end

  def self.log_warning(message, source: 'system')
    create!(
      message: message,
      level: 'warning',
      source: source,
      timestamp: Time.current
    )
  end

  def self.log_error(message, source: 'system')
    create!(
      message: message,
      level: 'error',
      source: source,
      timestamp: Time.current
    )
  end

  # Instance methods
  def css_class
    case level
    when 'info'
      'activity-info'
    when 'warning'
      'activity-warning'
    when 'error'
      'activity-error'
    else
      'activity-info'
    end
  end

  def formatted_time
    timestamp.strftime('%H:%M')
  end
end
