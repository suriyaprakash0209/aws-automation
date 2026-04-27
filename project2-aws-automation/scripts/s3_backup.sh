#!/bin/bash
# =============================================================================
# s3_backup.sh
# Compresses logs/files and uploads them to AWS S3 automatically
# Author: Suriya Prakash Jagan | Junior DevOps Engineer
# =============================================================================

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
# Load from environment or set defaults
S3_BUCKET="${S3_BUCKET:-your-backup-bucket-name}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
BACKUP_SOURCE="${BACKUP_SOURCE:-$(dirname "$0")/../logs}"
BACKUP_DIR="/tmp/devops_backups"
SERVER_NAME=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
DATE_TODAY=$(date '+%Y-%m-%d')

# Retention: delete S3 backups older than N days
RETENTION_DAYS=30

# Log file for this script
SCRIPT_LOG="$(dirname "$0")/../logs/backup_$(date +%Y-%m-%d).log"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ─── Setup ───────────────────────────────────────────────────────────────────
mkdir -p "$BACKUP_DIR" "$(dirname "$SCRIPT_LOG")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$SCRIPT_LOG"
}

error_exit() {
    log "❌ ERROR: $1"
    exit 1
}

# ─── Preflight Checks ────────────────────────────────────────────────────────

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   AWS S3 BACKUP SYSTEM — $SERVER_NAME${NC}"
echo -e "${BLUE}   $TIMESTAMP${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

log "=== S3 Backup Started ==="

# Check AWS CLI is installed
if ! command -v aws &>/dev/null; then
    error_exit "AWS CLI not found. Install it: https://aws.amazon.com/cli/"
fi

# Check source directory exists
if [ ! -d "$BACKUP_SOURCE" ]; then
    log "⚠️  Source directory not found: $BACKUP_SOURCE. Creating empty placeholder."
    mkdir -p "$BACKUP_SOURCE"
    echo "placeholder — no logs yet" > "$BACKUP_SOURCE/placeholder.txt"
fi

log "Source directory: $BACKUP_SOURCE"
log "S3 Bucket: s3://$S3_BUCKET"

# ─── Verify AWS Credentials ──────────────────────────────────────────────────

echo -e "  ${BLUE}Checking AWS credentials...${NC}"
if aws sts get-caller-identity --region "$AWS_REGION" &>/dev/null; then
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    echo -e "  ${GREEN}✅ Authenticated — Account: $AWS_ACCOUNT${NC}"
    log "AWS authenticated — Account: $AWS_ACCOUNT"
else
    error_exit "AWS credentials not configured. Run: aws configure"
fi

# ─── Create Compressed Archive ───────────────────────────────────────────────

ARCHIVE_NAME="${SERVER_NAME}_backup_${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="$BACKUP_DIR/$ARCHIVE_NAME"

echo ""
echo -e "  ${BLUE}📦 Compressing files...${NC}"

SOURCE_SIZE=$(du -sh "$BACKUP_SOURCE" 2>/dev/null | cut -f1)
log "Source size before compression: $SOURCE_SIZE"

tar -czf "$ARCHIVE_PATH" -C "$(dirname "$BACKUP_SOURCE")" "$(basename "$BACKUP_SOURCE")" 2>/dev/null || \
    error_exit "Failed to create archive"

ARCHIVE_SIZE=$(du -sh "$ARCHIVE_PATH" | cut -f1)
echo -e "  ${GREEN}✅ Archive created: $ARCHIVE_NAME ($ARCHIVE_SIZE)${NC}"
log "Archive created: $ARCHIVE_NAME (size: $ARCHIVE_SIZE)"

# ─── Upload to S3 ────────────────────────────────────────────────────────────

S3_KEY="backups/$DATE_TODAY/$ARCHIVE_NAME"
S3_PATH="s3://$S3_BUCKET/$S3_KEY"

echo ""
echo -e "  ${BLUE}☁️  Uploading to S3...${NC}"
echo -e "  Target: $S3_PATH"

if aws s3 cp "$ARCHIVE_PATH" "$S3_PATH" \
    --region "$AWS_REGION" \
    --storage-class STANDARD_IA \
    --metadata "server=$SERVER_NAME,date=$DATE_TODAY,source=devops-automation"; then
    echo -e "  ${GREEN}✅ Upload successful!${NC}"
    log "Upload successful: $S3_PATH"
else
    error_exit "S3 upload failed"
fi

# ─── Verify Upload ───────────────────────────────────────────────────────────

echo ""
echo -e "  ${BLUE}🔍 Verifying upload...${NC}"
if aws s3 ls "$S3_PATH" --region "$AWS_REGION" &>/dev/null; then
    S3_SIZE=$(aws s3 ls "$S3_PATH" --region "$AWS_REGION" | awk '{print $3}')
    echo -e "  ${GREEN}✅ Verified on S3 — Size: $S3_SIZE bytes${NC}"
    log "S3 verification passed — $S3_PATH ($S3_SIZE bytes)"
else
    error_exit "Verification failed — file not found on S3"
fi

# ─── Retention Policy — Delete Old Backups ───────────────────────────────────

echo ""
echo -e "  ${BLUE}🧹 Applying retention policy (${RETENTION_DAYS} days)...${NC}"

CUTOFF_DATE=$(date -d "$RETENTION_DAYS days ago" '+%Y-%m-%d' 2>/dev/null || \
              date -v-${RETENTION_DAYS}d '+%Y-%m-%d')

DELETED_COUNT=0

# List all backup folders and delete old ones
aws s3 ls "s3://$S3_BUCKET/backups/" --region "$AWS_REGION" 2>/dev/null | while read -r line; do
    FOLDER_DATE=$(echo "$line" | awk '{print $2}' | tr -d '/')
    if [[ "$FOLDER_DATE" < "$CUTOFF_DATE" ]] && [[ "$FOLDER_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo -e "  ${YELLOW}Deleting old backup: $FOLDER_DATE${NC}"
        aws s3 rm "s3://$S3_BUCKET/backups/$FOLDER_DATE/" \
            --recursive --region "$AWS_REGION" 2>/dev/null && \
        log "Deleted old backup folder: $FOLDER_DATE"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
done

echo -e "  ${GREEN}✅ Retention policy applied${NC}"

# ─── Cleanup Local Temp Files ────────────────────────────────────────────────

rm -f "$ARCHIVE_PATH"
log "Local temp archive cleaned up"

# ─── Summary ────────────────────────────────────────────────────────────────

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}✅ BACKUP COMPLETE${NC}"
echo -e "  Archive:  $ARCHIVE_NAME"
echo -e "  S3 Path:  $S3_PATH"
echo -e "  Size:     $ARCHIVE_SIZE → $S3_SIZE bytes on S3"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

log "=== Backup Completed Successfully ==="
exit 0
