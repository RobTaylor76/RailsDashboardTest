#!/bin/bash

# Redis Watch Script
# Continuously monitors Redis connection and message counts using Docker

REDIS_HOST=${REDIS_HOST:-"localhost"}
REDIS_PORT=${REDIS_PORT:-"6379"}
REDIS_PASSWORD=${REDIS_PASSWORD:-""}
REDIS_CONTAINER=${REDIS_CONTAINER:-"redis-dashboard"}
INTERVAL=${INTERVAL:-"5"}

# Function to run redis-cli via Docker
redis_cli() {
    if [ -n "$REDIS_PASSWORD" ]; then
        docker exec "$REDIS_CONTAINER" redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" "$@"
    else
        docker exec "$REDIS_CONTAINER" redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" "$@"
    fi
}

# Function to get current stats
get_stats() {
    local connections=$(redis_cli client list | wc -l)
    local commands=$(redis_cli info stats | grep total_commands_processed | cut -d: -f2)
    local subscribers=$(redis_cli pubsub numsub dashboard_updates | tail -1)
    local memory=$(redis_cli info memory | grep used_memory_human | cut -d: -f2)
    
    printf "%-20s | %-15s | %-20s | %-15s\n" "$(date '+%H:%M:%S')" "$connections" "$commands" "$subscribers"
}

# Function to show header
show_header() {
    echo "=== Redis Live Monitor ==="
    echo "Host: $REDIS_HOST:$REDIS_PORT"
    echo "Container: $REDIS_CONTAINER"
    echo "Update Interval: ${INTERVAL}s"
    echo "Press Ctrl+C to stop"
    echo ""
    printf "%-20s | %-15s | %-20s | %-15s\n" "Time" "Connections" "Total Commands" "Subscribers"
    echo "$(printf '%.0s-' {1..75})"
}

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "Monitoring stopped."
    exit 0
}

# Set up signal handling
trap cleanup SIGINT SIGTERM

# Main monitoring loop
show_header

while true; do
    get_stats
    sleep "$INTERVAL"
done
