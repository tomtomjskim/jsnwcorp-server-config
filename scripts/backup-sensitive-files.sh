#!/bin/bash

# Sensitive Files Backup Script
# Backs up .env files and user data with encryption

set -e

# Configuration
BACKUP_DIR="/home/deploy/backups/sensitive"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="sensitive_backup_${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "🔒 Sensitive Files Backup Script"
echo "========================================"
echo ""

# Create backup directory
mkdir -p "${BACKUP_DIR}"
mkdir -p "${BACKUP_PATH}"

echo "📁 Backup directory: ${BACKUP_PATH}"
echo ""

# Function to backup file with verification
backup_file() {
    local source="$1"
    local dest_name="$2"

    if [ -f "$source" ]; then
        cp "$source" "${BACKUP_PATH}/${dest_name}"
        echo -e "${GREEN}✓${NC} Backed up: $source"
        return 0
    else
        echo -e "${YELLOW}⚠${NC}  Skipped (not found): $source"
        return 1
    fi
}

# Function to backup directory
backup_directory() {
    local source="$1"
    local dest_name="$2"

    if [ -d "$source" ]; then
        cp -r "$source" "${BACKUP_PATH}/${dest_name}"
        echo -e "${GREEN}✓${NC} Backed up: $source"
        return 0
    else
        echo -e "${YELLOW}⚠${NC}  Skipped (not found): $source"
        return 1
    fi
}

echo "📋 Backing up .env files..."
echo "-----------------------------------"

# Main .env
backup_file "/home/deploy/.env" "main.env"

# Dashboard .env
backup_file "/home/deploy/projects/dashboard/.env" "dashboard.env"

# LottoMaster .env
backup_file "/home/deploy/projects/lotto-master/.env" "lotto-master.env"

# AI Chatbot .env (if exists)
backup_file "/home/deploy/projects/ai-chatbot/.env" "ai-chatbot.env"

# Today Fortune .env (if exists)
backup_file "/home/deploy/projects/today-fortune/.env" "today-fortune.env"

echo ""
echo "👤 Backing up user data..."
echo "-----------------------------------"

# Dashboard user data
backup_file "/home/deploy/projects/dashboard/data/users.json" "users.json"

# Dashboard sessions
if [ -d "/home/deploy/projects/dashboard/data/sessions" ]; then
    session_count=$(find /home/deploy/projects/dashboard/data/sessions -type f 2>/dev/null | wc -l)
    if [ "$session_count" -gt 0 ]; then
        backup_directory "/home/deploy/projects/dashboard/data/sessions" "sessions"
    else
        echo -e "${YELLOW}⚠${NC}  Skipped: sessions directory is empty"
    fi
fi

echo ""
echo "📄 Backing up PostgreSQL credentials documentation..."
echo "-----------------------------------"

# PostgreSQL credentials doc
backup_file "/home/deploy/POSTGRESQL_CREDENTIALS.md" "POSTGRESQL_CREDENTIALS.md"

echo ""
echo "📝 Creating backup manifest..."
echo "-----------------------------------"

# Create manifest file
cat > "${BACKUP_PATH}/MANIFEST.txt" << EOF
Sensitive Files Backup Manifest
Created: $(date '+%Y-%m-%d %H:%M:%S')
Server: $(hostname)
Backup ID: ${BACKUP_NAME}

Files included:
EOF

# List all backed up files with sizes
find "${BACKUP_PATH}" -type f -not -name "MANIFEST.txt" | while read file; do
    size=$(du -h "$file" | cut -f1)
    name=$(basename "$file")
    echo "  - $name ($size)" >> "${BACKUP_PATH}/MANIFEST.txt"
done

echo -e "${GREEN}✓${NC} Manifest created"

echo ""
echo "🗜️  Compressing backup..."
echo "-----------------------------------"

# Create tar.gz archive
cd "${BACKUP_DIR}"
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"

# Get archive size
ARCHIVE_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
echo -e "${GREEN}✓${NC} Archive created: ${BACKUP_NAME}.tar.gz (${ARCHIVE_SIZE})"

# Remove uncompressed directory
rm -rf "${BACKUP_NAME}"
echo -e "${GREEN}✓${NC} Cleaned up temporary files"

echo ""
echo "🔐 Encryption Options"
echo "-----------------------------------"
echo ""
echo "To encrypt this backup, use one of these methods:"
echo ""
echo "1. GPG Encryption (Recommended):"
echo "   gpg --symmetric --cipher-algo AES256 ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo "   # Creates: ${BACKUP_NAME}.tar.gz.gpg"
echo ""
echo "2. OpenSSL Encryption:"
echo "   openssl enc -aes-256-cbc -salt -in ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz -out ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz.enc"
echo "   # Creates: ${BACKUP_NAME}.tar.gz.enc"
echo ""
echo "3. Zip with Password:"
echo "   zip -e ${BACKUP_DIR}/${BACKUP_NAME}.zip ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo "   # Creates: ${BACKUP_NAME}.zip (password protected)"
echo ""

echo "========================================"
echo "✅ Backup Complete!"
echo "========================================"
echo ""
echo "📦 Backup file: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo "📊 Archive size: ${ARCHIVE_SIZE}"
echo ""
echo "⚠️  IMPORTANT:"
echo "  1. This backup contains SENSITIVE data (passwords, credentials)"
echo "  2. Encrypt the backup before transferring or storing"
echo "  3. Store in a secure location (NOT on Git)"
echo "  4. Delete old backups after successful migration"
echo ""

# List recent backups
echo "Recent backups in ${BACKUP_DIR}:"
ls -lht "${BACKUP_DIR}"/*.tar.gz 2>/dev/null | head -5 | awk '{print "  " $9 " (" $5 ")"}'

echo ""
echo "🔄 To restore this backup on new server:"
echo "  tar -xzf ${BACKUP_NAME}.tar.gz"
echo "  # Then copy files to their original locations"
echo ""
