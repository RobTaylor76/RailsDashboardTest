#!/bin/bash

# Simple Redis Stats Script
# Gets connection count and message counts from Redis using Docker

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

# Get connection count
get_connections() {
    echo "Connections: $(redis_cli client list | wc -l)"
}

# Get total commands processed (message count proxy)
get_commands() {
    echo "Total Commands: $(redis_cli info stats | grep total_commands_processed | cut -d: -f2)"
}

# Get pub/sub subscriber count for dashboard channel
get_subscribers() {
    echo "Dashboard Subscribers: $(redis_cli pubsub numsub dashboard_updates | tail -1)"
}

# Get memory usage
get_memory() {
    echo "Memory Used: $(redis_cli info memory | grep used_memory_human | cut -d: -f2)"
}

# Get all stats in one go
get_all_stats() {
    echo "=== Redis Stats ==="
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
    get_connections
    get_commands
    get_subscribers
    get_memory
    echo "=================="
}

# Main execution
case "${1:-all}" in
    "connections")
        get_connections
        ;;
    "commands")
        get_commands
        ;;
    "subscribers")
        get_subscribers
        ;;
    "memory")
        get_memory
        ;;
    "all"|*)
        get_all_stats
        ;;
esac
