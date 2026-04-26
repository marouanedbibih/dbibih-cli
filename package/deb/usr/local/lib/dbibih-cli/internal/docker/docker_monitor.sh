#!/bin/bash

# ANSI color codes
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
BLUE="\033[34m"

# Adjustable column widths
CONTAINER_WIDTH=13
NAME_WIDTH=18
IMAGE_WIDTH=25
STATUS_WIDTH=8
HEALTH_WIDTH=15
SIZE_WIDTH=10
CPU_WIDTH=10
MEM_WIDTH=12
NETIO_WIDTH=18

# Get terminal width
TERM_WIDTH=$(tput cols)
if [ $TERM_WIDTH -lt 150 ]; then
    CONTAINER_WIDTH=10
    NAME_WIDTH=15
    IMAGE_WIDTH=20
    NETIO_WIDTH=12
fi

clear

# Print title
echo -e "${BOLD}${BLUE}Docker Container Monitor${RESET}\n"

# Print header
printf "${BOLD}%-${CONTAINER_WIDTH}s %-${NAME_WIDTH}s %-${IMAGE_WIDTH}s %-${STATUS_WIDTH}s %-${HEALTH_WIDTH}s %-${SIZE_WIDTH}s %-${CPU_WIDTH}s %-${MEM_WIDTH}s %-${NETIO_WIDTH}s${RESET}\n" \
    "CONTAINER" "NAME" "IMAGE" "STATUS" "HEALTH" "SIZE" "CPU%" "MEM%" "NET I/O"
printf "${CYAN}%-${CONTAINER_WIDTH}s %-${NAME_WIDTH}s %-${IMAGE_WIDTH}s %-${STATUS_WIDTH}s %-${HEALTH_WIDTH}s %-${SIZE_WIDTH}s %-${CPU_WIDTH}s %-${MEM_WIDTH}s %-${NETIO_WIDTH}s${RESET}\n" \
    $(printf '%0.s-' $(seq 1 $CONTAINER_WIDTH)) \
    $(printf '%0.s-' $(seq 1 $NAME_WIDTH)) \
    $(printf '%0.s-' $(seq 1 $IMAGE_WIDTH)) \
    $(printf '%0.s-' $(seq 1 $STATUS_WIDTH)) \
    $(printf '%0.s-' $(seq 1 $HEALTH_WIDTH)) \
    $(printf '%0.s-' $(seq 1 $SIZE_WIDTH)) \
    $(printf '%0.s-' $(seq 1 $CPU_WIDTH)) \
    $(printf '%0.s-' $(seq 1 $MEM_WIDTH)) \
    $(printf '%0.s-' $(seq 1 $NETIO_WIDTH))

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed. Install it using your package manager.${RESET}"
    exit 1
fi

# Get containers
container_ids=$(docker ps -q)
if [ -z "$container_ids" ]; then
    echo -e "${YELLOW}No running containers found.${RESET}"
    exit 0
fi

# Get stats and inspect data
stats_data=$(docker stats --no-stream --format "{{.ID}},{{.CPUPerc}},{{.MemPerc}},{{.MemUsage}},{{.NetIO}}" $container_ids)
inspect_data=$(docker inspect $container_ids)

# Process each container
echo "$stats_data" | while IFS=',' read -r id cpu mem_percent mem_usage net_io; do
    container_info=$(echo "$inspect_data" | jq -r ".[] | select(.Id | startswith(\"$id\"))")

    short_id="${id:0:12}"
    [ ${#short_id} -gt $CONTAINER_WIDTH ] && short_id="${short_id:0:$(($CONTAINER_WIDTH-3))}..."

    container_name=$(echo "$container_info" | jq -r '.Name' | sed 's/^\///')
    [ ${#container_name} -gt $NAME_WIDTH ] && container_name="${container_name:0:$(($NAME_WIDTH-3))}..."

    image=$(echo "$container_info" | jq -r '.Config.Image')
    [ ${#image} -gt $IMAGE_WIDTH ] && image="${image:0:$(($IMAGE_WIDTH-3))}..."

    image_id=$(echo "$container_info" | jq -r '.Image')
    image_size=$(docker image inspect "$image" --format '{{.Size}}' | numfmt --to=iec --suffix=B --format="%.0f" | sed 's/B$//')

    container_status=$(echo "$container_info" | jq -r '.State.Status' | tr '[:lower:]' '[:upper:]')
    case $container_status in
        "RUNNING") status_color="${GREEN}" ;;
        "EXITED")  status_color="${RED}" ;;
        "PAUSED")  status_color="${YELLOW}" ;;
        *)         status_color="${CYAN}" ;;
    esac

    health_check=$(echo "$container_info" | jq -r 'if .State.Health then .State.Health.Status else "NO-CHECK" end' | tr '[:lower:]' '[:upper:]')
    case $health_check in
        "HEALTHY")   health_color="${GREEN}" ;;
        "UNHEALTHY") health_color="${RED}" ;;
        "NO-CHECK")  health_color="${YELLOW}" ;;
        *)           health_color="${RESET}" ;;
    esac

    mem_percent=$(echo "$mem_percent" | sed 's/%//')
    net_io=$(echo "$net_io" | sed 's/ \/ / ↔ /')
    [ ${#net_io} -gt $NETIO_WIDTH ] && net_io="${net_io:0:$(($NETIO_WIDTH-3))}..."

    # Print container line with STATUS & HEALTH after IMAGE
    printf "%-${CONTAINER_WIDTH}s %-${NAME_WIDTH}s %-${IMAGE_WIDTH}s " \
        "$short_id" "$container_name" "$image"
    printf "${status_color}%-${STATUS_WIDTH}s${RESET} ${health_color}%-${HEALTH_WIDTH}s${RESET} " \
        "$container_status" "$health_check"
    printf "%-${SIZE_WIDTH}s %-${CPU_WIDTH}s %-${MEM_WIDTH}s %-${NETIO_WIDTH}s\n" \
        "$image_size" "$cpu" "$mem_percent%" "$net_io"
done

# Footer
container_count=$(echo "$container_ids" | wc -w)
current_time=$(date "+%Y-%m-%d %H:%M:%S")
echo ""
echo -e "${BOLD}${container_count} containers | Updated: ${current_time}${RESET}"
