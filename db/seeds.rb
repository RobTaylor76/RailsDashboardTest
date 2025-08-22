# Clear existing data
puts "Clearing existing data..."
Metric.destroy_all
Activity.destroy_all
SystemStatus.destroy_all

# Create initial system status
puts "Creating system status..."
SystemStatus.create_default_status

# Create sample metrics for the last 24 hours
puts "Creating sample metrics..."
categories = ['cpu', 'memory', 'disk', 'network']
units = { 'cpu' => '%', 'memory' => '%', 'disk' => '%', 'network' => 'MB/s' }

# Generate metrics for the last 24 hours (every 5 minutes)
start_time = 24.hours.ago
end_time = Time.current

(start_time.to_i..end_time.to_i).step(5.minutes) do |timestamp|
  time = Time.at(timestamp)
  
  categories.each do |category|
    # Generate realistic values with some variation
    case category
    when 'cpu'
      value = rand(20..85) # CPU usage between 20-85%
    when 'memory'
      value = rand(45..90) # Memory usage between 45-90%
    when 'disk'
      value = rand(30..75) # Disk usage between 30-75%
    when 'network'
      value = rand(5..50) # Network usage between 5-50 MB/s
    end
    
    Metric.create!(
      name: "#{category}_usage",
      value: value,
      unit: units[category],
      category: category,
      timestamp: time
    )
  end
end

# Create sample activities
puts "Creating sample activities..."
activities = [
  { message: "Dashboard application started", level: "info", source: "system" },
  { message: "Database connection established", level: "info", source: "database" },
  { message: "High CPU usage detected (85%)", level: "warning", source: "monitoring" },
  { message: "Memory usage above threshold", level: "warning", source: "monitoring" },
  { message: "Backup completed successfully", level: "info", source: "backup" },
  { message: "New user registered", level: "info", source: "auth" },
  { message: "API rate limit exceeded", level: "warning", source: "api" },
  { message: "Cache cleared", level: "info", source: "cache" },
  { message: "Email sent successfully", level: "info", source: "mailer" },
  { message: "Database query optimized", level: "info", source: "database" }
]

activities.each_with_index do |activity, index|
  Activity.create!(
    message: activity[:message],
    level: activity[:level],
    source: activity[:source],
    timestamp: Time.current - (index * 30.minutes)
  )
end

# Update system status with realistic uptime
puts "Updating system status..."
SystemStatus.current_status.update!(
  uptime: rand(3600..86400), # 1-24 hours in seconds
  details: {
    message: "System running normally",
    version: "1.0.0",
    environment: Rails.env
  }
)

puts "Seed data created successfully!"
puts "Created #{Metric.count} metrics"
puts "Created #{Activity.count} activities"
puts "Created #{SystemStatus.count} system status records"
