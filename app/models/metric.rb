class Metric < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :value, presence: true, numericality: true
  validates :unit, presence: true
  validates :category, presence: true
  validates :timestamp, presence: true

  # Scopes
  scope :recent, -> { order(timestamp: :desc) }
  scope :by_category, ->(category) { where(category: category) }
  scope :latest, -> { recent.limit(1) }
  scope :last_hour, -> { where('timestamp >= ?', 1.hour.ago) }
  scope :last_24_hours, -> { where('timestamp >= ?', 24.hours.ago) }

  # Class methods
  def self.latest_by_category(category)
    by_category(category).latest.first
  end

  def self.average_by_category(category, hours: 1)
    by_category(category).last_hour.average(:value)
  end

  def self.create_metric(name:, value:, unit: '%', category: 'system')
    create!(
      name: name,
      value: value,
      unit: unit,
      category: category,
      timestamp: Time.current
    )
  end
end
