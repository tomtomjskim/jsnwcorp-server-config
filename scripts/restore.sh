#!/bin/bash

#############################################################################
# 전체 복원 스크립트
# 용도: PostgreSQL, 설정 파일, 프로젝트 파일 복원 (서버 이전용)
# 작성일: 2026-01-12
# 사용법: ./restore.sh [백업_타임스탬프] 또는 ./restore.sh --list
#############################################################################

set -e

# 설정
BACKUP_DIR="/home/deploy/backups"
PROJECT_DIR="/home/deploy"
LOG_FILE="/home/deploy/logs/restore.log"

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 로그 디렉토리 생성
mkdir -p "$(dirname "$LOG_FILE")"

# 로그 함수
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_color() {
    echo -e "${2}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

error_exit() {
    log_color "❌ 오류: $1" "$RED"
    exit 1
}

# 사용법 출력
usage() {
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  --list              사용 가능한 백업 목록 표시"
    echo "  --timestamp XXXXXX  특정 타임스탬프의 백업 복원"
    echo "  --latest            가장 최근 백업 복원"
    echo "  --db-only           PostgreSQL만 복원"
    echo "  --config-only       설정 파일만 복원"
    echo "  --help              이 도움말 표시"
    echo ""
    echo "예시:"
    echo "  $0 --list"
    echo "  $0 --latest"
    echo "  $0 --timestamp 20260112_020001"
    echo "  $0 --latest --db-only"
    exit 0
}

# 백업 목록 표시
list_backups() {
    log_color "========================================" "$BLUE"
    log_color "사용 가능한 백업 목록" "$BLUE"
    log_color "========================================" "$BLUE"
    echo ""

    echo "PostgreSQL 백업:"
    ls -lht "$BACKUP_DIR"/postgres_*.sql.gz 2>/dev/null | head -10 | awk '{print "  " $9 " (" $5 ", " $6 " " $7 " " $8 ")"}'
    echo ""

    echo "설정 파일 백업:"
    ls -lht "$BACKUP_DIR"/config_*.tar.gz 2>/dev/null | head -10 | awk '{print "  " $9 " (" $5 ", " $6 " " $7 " " $8 ")"}'
    echo ""

    echo "프로젝트 백업:"
    ls -lht "$BACKUP_DIR"/projects_*.tar.gz 2>/dev/null | head -10 | awk '{print "  " $9 " (" $5 ", " $6 " " $7 " " $8 ")"}'
    echo ""

    echo "Redis 백업:"
    ls -lht "$BACKUP_DIR"/redis_*.rdb 2>/dev/null | head -10 | awk '{print "  " $9 " (" $5 ", " $6 " " $7 " " $8 ")"}'
    echo ""

    # 최근 타임스탬프 추출
    LATEST=$(ls -t "$BACKUP_DIR"/postgres_*.sql.gz 2>/dev/null | head -1 | sed 's/.*postgres_\(.*\)\.sql\.gz/\1/')
    if [ -n "$LATEST" ]; then
        echo -e "${GREEN}가장 최근 타임스탬프: $LATEST${NC}"
    fi
}

# 최신 타임스탬프 가져오기
get_latest_timestamp() {
    ls -t "$BACKUP_DIR"/postgres_*.sql.gz 2>/dev/null | head -1 | sed 's/.*postgres_\(.*\)\.sql\.gz/\1/'
}

# PostgreSQL 복원
restore_postgres() {
    local timestamp=$1
    local backup_file="$BACKUP_DIR/postgres_${timestamp}.sql.gz"

    if [ ! -f "$backup_file" ]; then
        log_color "⚠️  PostgreSQL 백업 파일 없음: $backup_file" "$YELLOW"
        return 1
    fi

    log_color "\n[PostgreSQL 복원]" "$GREEN"
    log "백업 파일: $backup_file"

    # PostgreSQL 컨테이너 확인
    if ! docker ps | grep -q postgres; then
        log "PostgreSQL 컨테이너 시작 중..."
        docker compose up -d postgres
        sleep 10
    fi

    # 환경 변수 로드
    if [ -f "$PROJECT_DIR/.env" ]; then
        export $(grep -v '^#' "$PROJECT_DIR/.env" | xargs)
    fi

    POSTGRES_USER=${POSTGRES_USER:-appuser}
    POSTGRES_DB=${POSTGRES_DB:-maindb}

    log "데이터베이스 복원 중... (기존 데이터 덮어쓰기)"

    # 복원 실행
    if gunzip -c "$backup_file" | docker exec -i postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" > /dev/null 2>&1; then
        log_color "✓ PostgreSQL 복원 완료" "$GREEN"

        # 복원 확인
        log "복원된 테이블 확인:"
        docker exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\dt public.*" 2>/dev/null | head -15
    else
        log_color "⚠️  PostgreSQL 복원 중 일부 오류 (무시 가능할 수 있음)" "$YELLOW"
    fi
}

# 설정 파일 복원
restore_config() {
    local timestamp=$1
    local backup_file="$BACKUP_DIR/config_${timestamp}.tar.gz"

    if [ ! -f "$backup_file" ]; then
        log_color "⚠️  설정 파일 백업 없음: $backup_file" "$YELLOW"
        return 1
    fi

    log_color "\n[설정 파일 복원]" "$GREEN"
    log "백업 파일: $backup_file"

    # 기존 파일 백업
    RESTORE_BACKUP="$PROJECT_DIR/restore_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$RESTORE_BACKUP"

    # 기존 설정 파일 백업
    [ -f "$PROJECT_DIR/docker-compose.yml" ] && cp "$PROJECT_DIR/docker-compose.yml" "$RESTORE_BACKUP/"
    [ -d "$PROJECT_DIR/nginx" ] && cp -r "$PROJECT_DIR/nginx" "$RESTORE_BACKUP/"
    [ -d "$PROJECT_DIR/scripts" ] && cp -r "$PROJECT_DIR/scripts" "$RESTORE_BACKUP/"

    log "기존 설정 백업: $RESTORE_BACKUP"

    # 복원 (주의: .env는 덮어쓰지 않음)
    cd "$PROJECT_DIR"
    tar -xzf "$backup_file" --exclude=".env" 2>/dev/null || true

    log_color "✓ 설정 파일 복원 완료 (.env 제외)" "$GREEN"
    log "⚠️  .env 파일은 민감 정보로 별도 복원 필요"
}

# 프로젝트 파일 복원
restore_projects() {
    local timestamp=$1
    local backup_file="$BACKUP_DIR/projects_${timestamp}.tar.gz"

    if [ ! -f "$backup_file" ]; then
        log_color "⚠️  프로젝트 백업 없음: $backup_file" "$YELLOW"
        return 1
    fi

    log_color "\n[프로젝트 파일 복원]" "$GREEN"
    log "백업 파일: $backup_file"

    echo -e "${YELLOW}⚠️  경고: 프로젝트 파일 복원은 기존 파일을 덮어씁니다.${NC}"
    echo -e "${YELLOW}   Git 저장소에서 클론하는 것을 권장합니다.${NC}"
    read -p "계속하시겠습니까? (yes/no): " CONFIRM

    if [ "$CONFIRM" != "yes" ]; then
        log "프로젝트 복원 취소됨"
        return 0
    fi

    cd "$PROJECT_DIR"
    tar -xzf "$backup_file" 2>/dev/null || true

    log_color "✓ 프로젝트 파일 복원 완료" "$GREEN"
}

# Redis 복원
restore_redis() {
    local timestamp=$1
    local backup_file="$BACKUP_DIR/redis_${timestamp}.rdb"

    if [ ! -f "$backup_file" ]; then
        log_color "⚠️  Redis 백업 없음: $backup_file" "$YELLOW"
        return 1
    fi

    log_color "\n[Redis 복원]" "$GREEN"
    log "백업 파일: $backup_file"

    # Redis 컨테이너 중지
    docker compose stop redis 2>/dev/null || true

    # 볼륨에 복사
    docker run --rm -v deploy_redis_data:/data -v "$BACKUP_DIR":/backup \
        alpine cp "/backup/redis_${timestamp}.rdb" /data/dump.rdb

    # Redis 재시작
    docker compose up -d redis

    log_color "✓ Redis 복원 완료" "$GREEN"
}

#############################################################################
# 메인 로직
#############################################################################

# 인자 파싱
TIMESTAMP=""
DB_ONLY=false
CONFIG_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --list)
            list_backups
            exit 0
            ;;
        --latest)
            TIMESTAMP=$(get_latest_timestamp)
            if [ -z "$TIMESTAMP" ]; then
                error_exit "백업 파일을 찾을 수 없습니다"
            fi
            shift
            ;;
        --timestamp)
            TIMESTAMP="$2"
            shift 2
            ;;
        --db-only)
            DB_ONLY=true
            shift
            ;;
        --config-only)
            CONFIG_ONLY=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            TIMESTAMP="$1"
            shift
            ;;
    esac
done

# 타임스탬프 필수
if [ -z "$TIMESTAMP" ]; then
    usage
fi

log_color "========================================" "$BLUE"
log_color "복원 시작" "$BLUE"
log_color "타임스탬프: $TIMESTAMP" "$BLUE"
log_color "========================================" "$BLUE"

# 확인
echo ""
echo -e "${YELLOW}⚠️  주의: 이 작업은 현재 데이터를 덮어씁니다!${NC}"
echo ""
read -p "복원을 진행하시겠습니까? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    log "복원 취소됨"
    exit 0
fi

# 복원 실행
if [ "$DB_ONLY" = true ]; then
    restore_postgres "$TIMESTAMP"
elif [ "$CONFIG_ONLY" = true ]; then
    restore_config "$TIMESTAMP"
else
    restore_postgres "$TIMESTAMP"
    restore_config "$TIMESTAMP"
    restore_redis "$TIMESTAMP"

    echo ""
    echo -e "${YELLOW}프로젝트 파일도 복원하시겠습니까?${NC}"
    read -p "(Git 클론 권장, yes/no): " PROJ_CONFIRM
    if [ "$PROJ_CONFIRM" = "yes" ]; then
        restore_projects "$TIMESTAMP"
    fi
fi

log_color "\n========================================" "$BLUE"
log_color "복원 완료" "$GREEN"
log_color "========================================" "$BLUE"

echo ""
echo "다음 단계:"
echo "  1. 서비스 재시작: docker compose restart"
echo "  2. 헬스체크 확인: docker compose ps"
echo "  3. 민감 파일 복원: ./scripts/restore-sensitive-files.sh [backup.tar.gz]"
echo ""
