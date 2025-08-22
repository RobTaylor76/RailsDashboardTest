Rails.application.configure do
  if !Rails.env.development? || ENV["LOGRAGE_ENABLED"] == "true" 

  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.lograge.custom_options = lambda do |event|
      { time: event.time.iso8601 }
  end

  else
    config.lograge.enabled = false
  end
end