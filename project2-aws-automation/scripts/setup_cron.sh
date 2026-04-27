#!/bin/bash
# =============================================================================
# setup_cron.sh
# Installs automated cron jobs for health monitoring and S3 backup
# Run once on your server to activate full automation
# Author: Suriya Prakash Jagan | Junior DevOps Engineer
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   CRON JOB SETUP — DevOps Automation${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# Make scripts executable
chmod +x "$SCRIPT_DIR/server_health_monitor.sh"
chmod +x "$SCRIPT_DIR/s3_backup.sh"
echo -e "  ✅ Scripts marked executable"

# Create logs directory
mkdir -p "$SCRIPT_DIR/../logs"
echo -e "  ✅ Logs directory created"

# Build cron entries
HEALTH_CRON="*/30 * * * * $SCRIPT_DIR/server_health_monitor.sh >> $SCRIPT_DIR/../logs/cron.log 2>&1"
BACKUP_CRON="0 2 * * * $SCRIPT_DIR/s3_backup.sh >> $SCRIPT_DIR/../logs/cron.log 2>&1"
CLEANUP_CRON="0 3 * * 0 find $SCRIPT_DIR/../logs -name '*.log' -mtime +30 -delete >> $SCRIPT_DIR/../logs/cron.log 2>&1"

# Install cron jobs (avoid duplicates)
CURRENT_CRONTAB=$(crontab -l 2>/dev/null || echo "")

install_cron() {
    local job="$1"
    local name="$2"
    if echo "$CURRENT_CRONTAB" | grep -qF "$name"; then
        echo -e "  ⚡ $name already exists — skipping"
    else
        CURRENT_CRONTAB="${CURRENT_CRONTAB}
${job}"
        echo -e "  ✅ $name installed"
    fi
}

install_cron "$HEALTH_CRON" "server_health_monitor"
install_cron "$BACKUP_CRON" "s3_backup"
install_cron "$CLEANUP_CRON" "log_cleanup"

echo "$CURRENT_CRONTAB" | crontab -

echo ""
echo -e "${BLUE}  Scheduled Jobs:${NC}"
echo -e "  🔍 Health Monitor   → Every 30 minutes"
echo -e "  ☁️   S3 Backup        → Daily at 2:00 AM"
echo -e "  🧹 Log Cleanup      → Every Sunday at 3:00 AM"
echo ""
echo -e "${GREEN}  ✅ All cron jobs installed successfully!${NC}"
echo ""
echo -e "  View active cron jobs: ${BLUE}crontab -l${NC}"
echo -e "  Monitor logs:          ${BLUE}tail -f $SCRIPT_DIR/../logs/cron.log${NC}"
echo ""
