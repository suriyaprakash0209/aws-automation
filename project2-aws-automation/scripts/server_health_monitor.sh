#!/bin/bash
# =============================================================================
# server_health_monitor.sh
# Monitors CPU, Memory, Disk usage and logs results with alerts
# Author: Suriya Prakash Jagan | Junior DevOps Engineer
# =============================================================================

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
LOG_DIR="$(dirname "$0")/../logs"
LOG_FILE="$LOG_DIR/health_$(date +%Y-%m-%d).log"
ALERT_LOG="$LOG_DIR/alerts_$(date +%Y-%m-%d).log"

# Alert thresholds (%)
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90

# Colors for terminal output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ─── Setup ───────────────────────────────────────────────────────────────────
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)

# ─── Functions ───────────────────────────────────────────────────────────────

log() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

alert() {
    echo "[$TIMESTAMP] ⚠️  ALERT: $1" | tee -a "$ALERT_LOG" "$LOG_FILE"
}

get_cpu_usage() {
    # Get CPU usage percentage (average over 1 second)
    cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'.' -f1 2>/dev/null || \
               vmstat 1 1 | tail -1 | awk '{print $15}')
    echo $((100 - cpu_idle))
}

get_memory_usage() {
    # Returns used memory percentage
    free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}'
}

get_memory_details() {
    free -h | awk '/^Mem:/ {print "Total: "$2" | Used: "$3" | Free: "$4}'
}

get_disk_usage() {
    # Returns root partition usage percentage
    df / | awk 'NR==2 {print $5}' | tr -d '%'
}

get_disk_details() {
    df -h / | awk 'NR==2 {print "Total: "$2" | Used: "$3" | Available: "$4}'
}

get_load_average() {
    uptime | awk -F'load average:' '{print $2}' | xargs
}

get_top_processes() {
    ps aux --sort=-%cpu | awk 'NR==2,NR==4 {print $1, $3"%", $11}' | \
    awk '{printf "    %-15s CPU: %-8s %s\n", $1, $2, $3}'
}

check_services() {
    services=("ssh" "docker" "nginx" "cron")
    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            echo "    ✅ $svc: running"
        else
            echo "    ❌ $svc: not running (or not installed)"
        fi
    done
}

# ─── Main Health Check ────────────────────────────────────────────────────────

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   SERVER HEALTH MONITOR — $HOSTNAME${NC}"
echo -e "${BLUE}   $TIMESTAMP${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

log "=== Health Check Started for $HOSTNAME ==="

# ── CPU ──────────────────────────────────────────────────────────────────────
CPU=$(get_cpu_usage)
if [ "$CPU" -ge "$CPU_THRESHOLD" ]; then
    alert "CPU usage is HIGH: ${CPU}% (threshold: ${CPU_THRESHOLD}%)"
    echo -e "  CPU Usage:    ${RED}${CPU}%${NC} ⚠️  HIGH"
elif [ "$CPU" -ge $((CPU_THRESHOLD - 20)) ]; then
    echo -e "  CPU Usage:    ${YELLOW}${CPU}%${NC} ⚡ MODERATE"
else
    echo -e "  CPU Usage:    ${GREEN}${CPU}%${NC} ✅ NORMAL"
fi
log "CPU Usage: ${CPU}%"

# ── Memory ───────────────────────────────────────────────────────────────────
MEM=$(get_memory_usage)
MEM_DETAILS=$(get_memory_details)
if [ "$MEM" -ge "$MEMORY_THRESHOLD" ]; then
    alert "Memory usage is HIGH: ${MEM}% (threshold: ${MEMORY_THRESHOLD}%)"
    echo -e "  Memory:       ${RED}${MEM}%${NC} ⚠️  HIGH"
elif [ "$MEM" -ge $((MEMORY_THRESHOLD - 20)) ]; then
    echo -e "  Memory:       ${YELLOW}${MEM}%${NC} ⚡ MODERATE"
else
    echo -e "  Memory:       ${GREEN}${MEM}%${NC} ✅ NORMAL"
fi
echo -e "  Details:      $MEM_DETAILS"
log "Memory Usage: ${MEM}% — $MEM_DETAILS"

# ── Disk ─────────────────────────────────────────────────────────────────────
DISK=$(get_disk_usage)
DISK_DETAILS=$(get_disk_details)
if [ "$DISK" -ge "$DISK_THRESHOLD" ]; then
    alert "Disk usage is HIGH: ${DISK}% (threshold: ${DISK_THRESHOLD}%)"
    echo -e "  Disk (root):  ${RED}${DISK}%${NC} ⚠️  HIGH"
elif [ "$DISK" -ge $((DISK_THRESHOLD - 20)) ]; then
    echo -e "  Disk (root):  ${YELLOW}${DISK}%${NC} ⚡ MODERATE"
else
    echo -e "  Disk (root):  ${GREEN}${DISK}%${NC} ✅ NORMAL"
fi
echo -e "  Details:      $DISK_DETAILS"
log "Disk Usage: ${DISK}% — $DISK_DETAILS"

# ── Load Average ──────────────────────────────────────────────────────────────
LOAD=$(get_load_average)
echo -e "  Load Avg:     $LOAD"
log "Load Average: $LOAD"

# ── Top Processes ────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}  Top CPU Processes:${NC}"
get_top_processes
log "Top processes checked"

# ── Service Status ───────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}  Service Status:${NC}"
check_services

# ── Uptime ───────────────────────────────────────────────────────────────────
UPTIME=$(uptime -p 2>/dev/null || uptime)
echo ""
echo -e "  Server Uptime: $UPTIME"
log "Uptime: $UPTIME"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
log "=== Health Check Completed ==="
echo -e "  📄 Log saved: $LOG_FILE"
echo ""

# Exit with error if any threshold exceeded (useful for monitoring systems)
if [ "$CPU" -ge "$CPU_THRESHOLD" ] || [ "$MEM" -ge "$MEMORY_THRESHOLD" ] || [ "$DISK" -ge "$DISK_THRESHOLD" ]; then
    exit 1
fi

exit 0
