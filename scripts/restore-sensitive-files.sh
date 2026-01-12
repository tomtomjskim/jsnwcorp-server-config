#!/bin/bash

# Sensitive Files Restore Script
# Restores .env files and user data from backup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "🔓 Sensitive Files Restore Script"
echo "========================================"
echo ""

# Check if backup file is provided
if [ -z "$1" ]; then
    echo -e "${RED}❌ Error: No backup file specified${NC}"
    echo ""
    echo "Usage: $0 <backup-file.tar.gz>"
    echo ""
    echo "Available backups:"
    ls -lht /home/deploy/backups/sensitive/*.tar.gz 2>/dev/null | head -5 | awk '{print "  " $9}'
    echo ""
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}❌ Error: Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

echo "📦 Backup file: $BACKUP_FILE"
echo ""

# Extract to temporary directory
TEMP_DIR="/tmp/sensitive_restore_$$"
mkdir -p "$TEMP_DIR"

echo "🗜️  Extracting backup..."
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# Find the extracted directory
EXTRACTED_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "sensitive_backup_*" | head -1)

if [ -z "$EXTRACTED_DIR" ]; then
    echo -e "${RED}❌ Error: Could not find extracted backup directory${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "${GREEN}✓${NC} Backup extracted to: $EXTRACTED_DIR"
echo ""

# Show manifest if exists
if [ -f "$EXTRACTED_DIR/MANIFEST.txt" ]; then
    echo "📋 Backup Manifest:"
    echo "-----------------------------------"
    cat "$EXTRACTED_DIR/MANIFEST.txt"
    echo ""
fi

echo "⚠️  WARNING: This will overwrite existing files!"
echo ""
read -p "Continue with restore? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled"
    rm -rf "$TEMP_DIR"
    exit 0
fi

echo ""
echo "🔄 Restoring files..."
echo "-----------------------------------"

# Function to restore file
restore_file() {
    local source_name="$1"
    local dest_path="$2"

    if [ -f "${EXTRACTED_DIR}/${source_name}" ]; then
        # Create destination directory if needed
        mkdir -p "$(dirname "$dest_path")"

        # Backup existing file if it exists
        if [ -f "$dest_path" ]; then
            cp "$dest_path" "${dest_path}.backup_$(date +%Y%m%d_%H%M%S)"
            echo -e "${YELLOW}⚠${NC}  Backed up existing: $dest_path"
        fi

        # Restore file
        cp "${EXTRACTED_DIR}/${source_name}" "$dest_path"
        chmod 600 "$dest_path"  # Set secure permissions
        echo -e "${GREEN}✓${NC} Restored: $dest_path"
        return 0
    else
        echo -e "${YELLOW}⚠${NC}  Skipped (not in backup): $source_name"
        return 1
    fi
}

# Function to restore directory
restore_directory() {
    local source_name="$1"
    local dest_path="$2"

    if [ -d "${EXTRACTED_DIR}/${source_name}" ]; then
        # Create parent directory if needed
        mkdir -p "$(dirname "$dest_path")"

        # Backup existing directory if it exists
        if [ -d "$dest_path" ]; then
            mv "$dest_path" "${dest_path}.backup_$(date +%Y%m%d_%H%M%S)"
            echo -e "${YELLOW}⚠${NC}  Backed up existing: $dest_path"
        fi

        # Restore directory
        cp -r "${EXTRACTED_DIR}/${source_name}" "$dest_path"
        chmod 700 "$dest_path"  # Set secure permissions
        echo -e "${GREEN}✓${NC} Restored: $dest_path"
        return 0
    else
        echo -e "${YELLOW}⚠${NC}  Skipped (not in backup): $source_name"
        return 1
    fi
}

# Restore .env files
echo ""
echo "📋 Restoring .env files..."

restore_file "main.env" "/home/deploy/.env"
restore_file "dashboard.env" "/home/deploy/projects/dashboard/.env"
restore_file "lotto-master.env" "/home/deploy/projects/lotto-master/.env"
restore_file "ai-chatbot.env" "/home/deploy/projects/ai-chatbot/.env"
restore_file "today-fortune.env" "/home/deploy/projects/today-fortune/.env"

# Restore user data
echo ""
echo "👤 Restoring user data..."

restore_file "users.json" "/home/deploy/projects/dashboard/data/users.json"
restore_directory "sessions" "/home/deploy/projects/dashboard/data/sessions"

# Restore documentation
echo ""
echo "📄 Restoring documentation..."

restore_file "POSTGRESQL_CREDENTIALS.md" "/home/deploy/POSTGRESQL_CREDENTIALS.md"

# Cleanup
echo ""
echo "🧹 Cleaning up..."
rm -rf "$TEMP_DIR"
echo -e "${GREEN}✓${NC} Temporary files removed"

echo ""
echo "========================================"
echo "✅ Restore Complete!"
echo "========================================"
echo ""
echo "📝 Next steps:"
echo "  1. Verify .env files have correct values"
echo "  2. Check file permissions (should be 600)"
echo "  3. Restart services if needed:"
echo "     docker compose restart"
echo ""
echo "🔍 Verify restored files:"
echo "  ls -la /home/deploy/.env"
echo "  ls -la /home/deploy/projects/dashboard/.env"
echo "  ls -la /home/deploy/projects/dashboard/data/"
echo ""
