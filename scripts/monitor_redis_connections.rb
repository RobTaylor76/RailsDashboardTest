#!/usr/bin/env ruby

# Redis Connection Monitor Script
# This script helps monitor Redis connections to detect leaks

require 'redis'
require 'json'

def get_redis_info
  redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379')
  redis = Redis.new(url: redis_url)
  
  info = redis.info
  redis.close
  
  {
    connected_clients: info['connected_clients'].to_i,
    used_memory_human: info['used_memory_human'],
    total_commands_processed: info['total_commands_processed'].to_i,
    keyspace_hits: info['keyspace_hits'].to_i,
    keyspace_misses: info['keyspace_misses'].to_i
  }
rescue => e
  { error: e.message }
end

def get_rails_app_status
  # Try to get status from Rails app debug endpoint
  require 'net/http'
  require 'json'
  
  uri = URI('http://localhost:3000/dashboard/debug')
  response = Net::HTTP.get_response(uri)
  
  if response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  else
    { error: "HTTP #{response.code}" }
  end
rescue => e
  { error: e.message }
end

def monitor_connections(interval = 5, duration = 60)
  puts "🔍 Redis Connection Monitor"
  puts "=========================="
  puts "Monitoring every #{interval} seconds for #{duration} seconds"
  puts "Press Ctrl+C to stop early"
  puts ""
  
  start_time = Time.now
  last_redis_info = nil
  
  loop do
    current_time = Time.now
    elapsed = (current_time - start_time).to_i
    
    if elapsed >= duration
      puts "\n⏰ Monitoring completed after #{duration} seconds"
      break
    end
    
    # Get Redis info
    redis_info = get_redis_info
    
    # Get Rails app status
    rails_status = get_rails_app_status
    
    # Display current status
    puts "[#{current_time.strftime('%H:%M:%S')}] Elapsed: #{elapsed}s"
    
    if redis_info[:error]
      puts "  ❌ Redis Error: #{redis_info[:error]}"
    else
      puts "  📊 Redis: #{redis_info[:connected_clients]} clients, #{redis_info[:used_memory_human]} memory"
      
      # Show connection change
      if last_redis_info && !last_redis_info[:error]
        client_change = redis_info[:connected_clients] - last_redis_info[:connected_clients]
        if client_change != 0
          change_symbol = client_change > 0 ? "📈" : "📉"
          puts "  #{change_symbol} Client change: #{client_change > 0 ? '+' : ''}#{client_change}"
        end
      end
    end
    
    if rails_status[:error]
      puts "  ❌ Rails Error: #{rails_status[:error]}"
    else
      redis_conn = rails_status.dig('redis_connections')
      if redis_conn
        puts "  🔗 Rails Redis: #{redis_conn['redis_connected'] ? '✅' : '❌'} main, #{redis_conn['pubsub_connected'] ? '✅' : '❌'} pubsub"
        puts "  📈 Total connections created: #{redis_conn['connection_count']}"
      end
      
      sse_conn = rails_status.dig('sse_connections', 'total_connections')
      if sse_conn
        puts "  📡 SSE Connections: #{sse_conn}"
      end
    end
    
    puts ""
    last_redis_info = redis_info
    
    sleep interval
  rescue Interrupt
    puts "\n🛑 Monitoring stopped by user"
    break
  rescue => e
    puts "  ❌ Monitor error: #{e.message}"
    sleep interval
  end
end

# Main execution
if __FILE__ == $0
  interval = ARGV[0]&.to_i || 5
  duration = ARGV[1]&.to_i || 60
  
  puts "Usage: ruby monitor_redis_connections.rb [interval_seconds] [duration_seconds]"
  puts "Default: 5 second intervals for 60 seconds"
  puts ""
  
  monitor_connections(interval, duration)
end
