#!/bin/bash

# Redis Monitoring Script
# This script provides various Redis monitoring capabilities using Docker

REDIS_HOST=${REDIS_HOST:-"localhost"}
REDIS_PORT=${REDIS_PORT:-"6379"}
REDIS_PASSWORD=${REDIS_PASSWORD:-""}
REDIS_CONTAINER=${REDIS_CONTAINER:-"redis-dashboard"}

# Function to run redis-cli via Docker
redis_cli() {
    if [ -n "$REDIS_PASSWORD" ]; then
        docker exec "$REDIS_CONTAINER" redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" "$@"
    else
        docker exec "$REDIS_CONTAINER" redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" "$@"
    fi
}

# Function to get Redis connection count
get_connection_count() {
    echo "=== Redis Connection Count ==="
    redis_cli client list | wc -l
}

# Function to get detailed connection information
get_connection_details() {
    echo "=== Redis Connection Details ==="
    redis_cli client list | while IFS= read -r line; do
        if [[ $line == *"addr="* ]]; then
            echo "$line"
        fi
    done
}

# Function to get Redis INFO command output
get_redis_info() {
    echo "=== Redis INFO ==="
    redis_cli info | grep -E "(connected_clients|total_connections_received|total_commands_processed|keyspace_hits|keyspace_misses|used_memory|used_memory_peak)"
}

# Function to get pub/sub channel information
get_pubsub_info() {
    echo "=== Pub/Sub Channels ==="
    redis_cli pubsub channels "*"
}

# Function to get subscriber count for specific channels
get_subscriber_count() {
    echo "=== Subscriber Counts ==="
    redis_cli pubsub numsub dashboard_updates
}

# Function to get Redis memory usage
get_memory_usage() {
    echo "=== Memory Usage ==="
    redis_cli info memory | grep -E "(used_memory|used_memory_peak|used_memory_rss|mem_fragmentation_ratio)"
}

# Function to get Redis statistics
get_redis_stats() {
    echo "=== Redis Statistics ==="
    redis_cli info stats | grep -E "(total_connections_received|total_commands_processed|instantaneous_ops_per_sec|total_net_input_bytes|total_net_output_bytes|rejected_connections)"
}

# Function to monitor Redis in real-time
monitor_redis() {
    echo "=== Real-time Redis Monitor ==="
    echo "Press Ctrl+C to stop monitoring"
    redis_cli monitor
}

# Function to get slow log entries
get_slow_log() {
    echo "=== Slow Log (last 10 entries) ==="
    redis_cli slowlog get 10
}

# Function to get all available commands
show_help() {
    echo "Redis Monitoring Script (Docker)"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  connections    - Show connection count"
    echo "  details        - Show detailed connection information"
    echo "  info           - Show Redis INFO output"
    echo "  pubsub         - Show pub/sub channels"
    echo "  subscribers    - Show subscriber counts"
    echo "  memory         - Show memory usage"
    echo "  stats          - Show Redis statistics"
    echo "  monitor        - Real-time monitoring"
    echo "  slowlog        - Show slow log entries"
    echo "  all            - Show all information"
    echo "  help           - Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  REDIS_HOST         - Redis host (default: localhost)"
    echo "  REDIS_PORT         - Redis port (default: 6379)"
    echo "  REDIS_PASSWORD     - Redis password (optional)"
    echo "  REDIS_CONTAINER    - Redis container name (default: redis)"
}

# Main script logic
case "${1:-help}" in
    "connections")
        get_connection_count
        ;;
    "details")
        get_connection_details
        ;;
    "info")
        get_redis_info
        ;;
    "pubsub")
        get_pubsub_info
        ;;
    "subscribers")
        get_subscriber_count
        ;;
    "memory")
        get_memory_usage
        ;;
    "stats")
        get_redis_stats
        ;;
    "monitor")
        monitor_redis
        ;;
    "slowlog")
        get_slow_log
        ;;
    "all")
        echo "=== COMPREHENSIVE REDIS MONITORING REPORT ==="
        echo "Timestamp: $(date)"
        echo "Container: $REDIS_CONTAINER"
        echo ""
        get_connection_count
        echo ""
        get_redis_info
        echo ""
        get_pubsub_info
        echo ""
        get_subscriber_count
        echo ""
        get_memory_usage
        echo ""
        get_redis_stats
        ;;
    "help"|*)
        show_help
        ;;
esac
