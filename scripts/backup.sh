#!/bin/bash

#############################################################################
# 백업 자동화 스크립트
# 용도: PostgreSQL 데이터베이스, 설정 파일, 프로젝트 파일 백업
# 작성일: 2025-10-15
#############################################################################

set -e

# 설정
BACKUP_DIR="/home/deploy/backups"
PROJECT_DIR="/home/deploy"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_RETENTION_DAYS=60
LOG_FILE="/home/deploy/logs/backup.log"

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 디렉토리 생성
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$BACKUP_DIR"

# 로그 함수
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_color() {
    echo -e "${2}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

# 에러 핸들링
error_exit() {
    log_color "❌ 오류: $1" "$RED"
    exit 1
}

#############################################################################
# 메인 로직 시작
#############################################################################

log_color "========================================" "$BLUE"
log_color "백업 시작" "$BLUE"
log_color "타임스탬프: $TIMESTAMP" "$BLUE"
log_color "========================================" "$BLUE"

# 초기 디스크 사용량
INITIAL_DISK=$(df -h "$BACKUP_DIR" | awk 'NR==2{print $3}')
DISK_FREE=$(df -h "$BACKUP_DIR" | awk 'NR==2{print $4}')
log "초기 디스크 사용량: $INITIAL_DISK (여유: $DISK_FREE)"

# 디스크 여유 공간 확인 (최소 1GB 필요)
DISK_FREE_MB=$(df -m "$BACKUP_DIR" | awk 'NR==2{print $4}')
if [ "$DISK_FREE_MB" -lt 1024 ]; then
    error_exit "디스크 여유 공간 부족 (${DISK_FREE_MB}MB < 1GB). 백업을 중단합니다."
fi

#############################################################################
# 1. PostgreSQL 데이터베이스 백업
#############################################################################

log_color "\n[1] PostgreSQL 데이터베이스 백업" "$GREEN"

# 환경 변수 로드
if [ -f "$PROJECT_DIR/.env" ]; then
    export $(grep -v '^#' "$PROJECT_DIR/.env" | xargs)
fi

# PostgreSQL 설정
POSTGRES_USER=${POSTGRES_USER:-appuser}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-changeme123}
POSTGRES_DB=${POSTGRES_DB:-maindb}
POSTGRES_CONTAINER="postgres"

# PostgreSQL이 실행 중인지 확인
if ! docker ps | grep -q "$POSTGRES_CONTAINER"; then
    log_color "⚠️  PostgreSQL 컨테이너가 실행 중이 아닙니다. DB 백업 생략." "$YELLOW"
else
    DB_BACKUP_FILE="$BACKUP_DIR/postgres_${TIMESTAMP}.sql.gz"

    log "데이터베이스 백업 중: $POSTGRES_DB"

    # pg_dump 실행 및 압축
    if docker exec "$POSTGRES_CONTAINER" pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" | gzip > "$DB_BACKUP_FILE"; then
        DB_SIZE=$(du -h "$DB_BACKUP_FILE" | cut -f1)
        log_color "✓ PostgreSQL 백업 완료: $DB_BACKUP_FILE ($DB_SIZE)" "$GREEN"
    else
        error_exit "PostgreSQL 백업 실패"
    fi
fi

#############################################################################
# 2. 설정 파일 백업
#############################################################################

log_color "\n[2] 설정 파일 백업" "$GREEN"

CONFIG_BACKUP_FILE="$BACKUP_DIR/config_${TIMESTAMP}.tar.gz"

# 백업할 설정 파일 목록
CONFIG_FILES=(
    "docker-compose.yml"
    ".env"
    "nginx/nginx.conf"
    "nginx/conf.d"
    "scripts"
)

log "설정 파일 압축 중..."

# tar 명령어로 압축
cd "$PROJECT_DIR"
tar -czf "$CONFIG_BACKUP_FILE" "${CONFIG_FILES[@]}" 2>/dev/null || log_color "⚠️  일부 파일을 찾을 수 없습니다" "$YELLOW"

if [ -f "$CONFIG_BACKUP_FILE" ]; then
    CONFIG_SIZE=$(du -h "$CONFIG_BACKUP_FILE" | cut -f1)
    log_color "✓ 설정 파일 백업 완료: $CONFIG_BACKUP_FILE ($CONFIG_SIZE)" "$GREEN"
else
    log_color "⚠️  설정 파일 백업 생략" "$YELLOW"
fi

#############################################################################
# 3. 프로젝트 파일 백업 (선택사항)
#############################################################################

log_color "\n[3] 프로젝트 파일 백업" "$GREEN"

PROJECT_BACKUP_FILE="$BACKUP_DIR/projects_${TIMESTAMP}.tar.gz"

# projects 디렉토리가 있으면 백업
if [ -d "$PROJECT_DIR/projects" ]; then
    log "프로젝트 파일 압축 중..."

    cd "$PROJECT_DIR"
    # node_modules, 로그, 캐시 등 제외
    tar -czf "$PROJECT_BACKUP_FILE" \
        --exclude='node_modules' \
        --exclude='*.log' \
        --exclude='.git' \
        --exclude='dist' \
        --exclude='build' \
        projects/ 2>/dev/null || true

    if [ -f "$PROJECT_BACKUP_FILE" ]; then
        PROJECT_SIZE=$(du -h "$PROJECT_BACKUP_FILE" | cut -f1)
        log_color "✓ 프로젝트 파일 백업 완료: $PROJECT_BACKUP_FILE ($PROJECT_SIZE)" "$GREEN"
    fi
else
    log "projects 디렉토리 없음, 백업 생략"
fi

#############################################################################
# 4. Redis 데이터 백업
#############################################################################

log_color "\n[4] Redis 데이터 백업" "$GREEN"

REDIS_CONTAINER="redis"

if ! docker ps | grep -q "$REDIS_CONTAINER"; then
    log_color "⚠️  Redis 컨테이너가 실행 중이 아닙니다. Redis 백업 생략." "$YELLOW"
else
    REDIS_BACKUP_FILE="$BACKUP_DIR/redis_${TIMESTAMP}.rdb"

    log "Redis 데이터 백업 중..."

    # Redis SAVE 명령 실행 및 dump.rdb 복사
    docker exec "$REDIS_CONTAINER" redis-cli --no-auth-warning -a "${REDIS_PASSWORD:-redispass}" SAVE > /dev/null 2>&1 || true
    docker cp "$REDIS_CONTAINER:/data/dump.rdb" "$REDIS_BACKUP_FILE" 2>/dev/null || true

    if [ -f "$REDIS_BACKUP_FILE" ]; then
        REDIS_SIZE=$(du -h "$REDIS_BACKUP_FILE" | cut -f1)
        log_color "✓ Redis 백업 완료: $REDIS_BACKUP_FILE ($REDIS_SIZE)" "$GREEN"
    else
        log_color "⚠️  Redis 백업 실패 또는 데이터 없음" "$YELLOW"
    fi
fi

#############################################################################
# 5. 오래된 백업 파일 정리
#############################################################################

log_color "\n[5] 오래된 백업 파일 정리 (${BACKUP_RETENTION_DAYS}일 이상)" "$GREEN"

OLD_BACKUPS=$(find "$BACKUP_DIR" -name "*.tar.gz" -o -name "*.sql.gz" -o -name "*.rdb" -type f -mtime +${BACKUP_RETENTION_DAYS} 2>/dev/null || true)

if [ -n "$OLD_BACKUPS" ]; then
    log "발견된 오래된 백업 파일:"
    echo "$OLD_BACKUPS" | while read -r file; do
        FILE_SIZE=$(du -h "$file" 2>/dev/null | cut -f1)
        FILE_DATE=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1)
        log "  - $file ($FILE_SIZE, $FILE_DATE)"
    done

    COUNT=$(echo "$OLD_BACKUPS" | wc -l)
    find "$BACKUP_DIR" \( -name "*.tar.gz" -o -name "*.sql.gz" -o -name "*.rdb" \) -type f -mtime +${BACKUP_RETENTION_DAYS} -delete 2>/dev/null
    log_color "✓ $COUNT 개의 오래된 백업 파일 삭제 완료" "$GREEN"
else
    log "삭제할 오래된 백업 파일 없음"
fi

#############################################################################
# 6. 백업 요약
#############################################################################

log_color "\n========================================" "$BLUE"
log_color "백업 완료" "$GREEN"
log_color "========================================" "$BLUE"

# 최종 디스크 사용량
FINAL_DISK=$(df -h "$BACKUP_DIR" | awk 'NR==2{print $3}')
DISK_FREE=$(df -h "$BACKUP_DIR" | awk 'NR==2{print $4}')

log "초기 디스크 사용량: $INITIAL_DISK"
log "최종 디스크 사용량: $FINAL_DISK"
log "현재 여유 공간: $DISK_FREE"

# 백업 파일 목록
log "\n백업된 파일:"
ls -lh "$BACKUP_DIR" | grep "$TIMESTAMP" | awk '{print "  - " $9 " (" $5 ")"}'

# 전체 백업 크기
TOTAL_BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
log "\n전체 백업 디렉토리 크기: $TOTAL_BACKUP_SIZE"

log_color "✓ 모든 백업 작업 완료" "$GREEN"
log_color "========================================" "$BLUE"

exit 0
