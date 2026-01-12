# 서버 이전 가이드

**작성일**: 2026-01-12
**버전**: 1.0
**목적**: 현재 서버에서 새 서버로 전체 시스템 이전

---

## 1. 현재 서버 스펙

### 1.1 하드웨어/OS
| 항목 | 값 |
|------|-----|
| IP | 203.245.30.6 |
| OS | Ubuntu 22.04 LTS |
| RAM | 1GB |
| Disk | 30GB (사용: ~20GB) |
| Swap | 4GB |

### 1.2 Docker 컨테이너
| 컨테이너 | 이미지 | 포트 | 메모리 제한 |
|----------|--------|------|-------------|
| nginx-proxy | deploy-nginx | 80, 443, 3001-3005 | 64MB |
| dashboard | deploy-dashboard | 3000 (내부) | 128MB |
| lotto-service | deploy-lotto-service | 3000 (내부) | 256MB |
| today-fortune | deploy-today-fortune | 80 (내부) | 64MB |
| ai-chatbot | deploy-ai-chatbot | 8000 | 128MB |
| author-clock-api | deploy-author-clock-api | 3000 (내부) | 96MB |
| author-clock-frontend | deploy-author-clock-frontend | 80 (내부) | 64MB |
| postgres | postgres:15-alpine | 5432 | 192MB |
| redis | redis:7-alpine | 6379 | 96MB |

### 1.3 Docker 볼륨
| 볼륨 | 용도 |
|------|------|
| deploy_postgres_data | PostgreSQL 데이터 |
| deploy_redis_data | Redis 데이터 |
| deploy_geoip_data | GeoIP 데이터베이스 |

### 1.4 PostgreSQL 데이터베이스
- **버전**: PostgreSQL 15.14 (Alpine)
- **데이터베이스**: maindb
- **크기**: ~10MB

| 스키마 | 테이블 | 용도 |
|--------|--------|------|
| public | projects, analytics_events, api_logs, user_sessions 등 | 공통/대시보드 |
| lotto | draw_results, draws, generation_history 등 | 로또 서비스 |
| author_clock | quotes, daily_quotes, users, user_likes 등 | 명언 시계 |
| analytics | (집계용) | 통합 분석 |

### 1.5 외부 포트 매핑
| 포트 | 서비스 |
|------|--------|
| 80 | Dashboard (메인) |
| 3001 | Lotto Service |
| 3002 | Today Fortune |
| 3004 | Author Clock |
| 3005 | Blog Automation (정적) |

---

## 2. 백업 절차 (현재 서버에서 실행)

### 2.1 전체 백업 실행
```bash
# 1. 일반 백업 (DB, 설정, 프로젝트)
sudo /home/deploy/scripts/backup.sh

# 2. 민감 파일 백업 (.env, 인증 정보)
/home/deploy/scripts/backup-sensitive-files.sh

# 3. 백업 파일 확인
ls -lht /home/deploy/backups/
ls -lht /home/deploy/backups/sensitive/
```

### 2.2 Git 저장소 백업 (코드)
```bash
# 각 프로젝트 최신 커밋 확인 및 푸시
cd /home/deploy/projects
for dir in dashboard lotto-master today-fortune ai-chatbot author-clock; do
  echo "=== $dir ==="
  cd $dir && git status && git push origin $(git branch --show-current) && cd ..
done

# 서버 설정 저장소 푸시
cd /home/deploy
git add -A && git commit -m "backup: 서버 이전 전 최종 백업" && git push
```

### 2.3 수동 백업 파일 생성 (권장)
```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# PostgreSQL 전체 덤프 (모든 스키마)
docker exec postgres pg_dumpall -U appuser > /home/deploy/backups/full_db_${TIMESTAMP}.sql

# Docker 볼륨 백업
docker run --rm -v deploy_postgres_data:/data -v /home/deploy/backups:/backup \
  alpine tar czf /backup/postgres_volume_${TIMESTAMP}.tar.gz -C /data .

docker run --rm -v deploy_redis_data:/data -v /home/deploy/backups:/backup \
  alpine tar czf /backup/redis_volume_${TIMESTAMP}.tar.gz -C /data .

# nginx 정적 파일 백업 (blog-automation 등)
tar czf /home/deploy/backups/nginx_www_${TIMESTAMP}.tar.gz -C /home/deploy/nginx www/
```

### 2.4 백업 파일 전송
```bash
# 새 서버로 전송 (scp 사용)
scp -r /home/deploy/backups/* user@new-server:/home/deploy/backups/

# 또는 rsync 사용 (권장)
rsync -avz --progress /home/deploy/backups/ user@new-server:/home/deploy/backups/
```

---

## 3. 새 서버 준비

### 3.1 최소 요구사항
- Ubuntu 22.04 LTS
- RAM: 1GB 이상 (2GB 권장)
- Disk: 30GB 이상
- Swap: 4GB 설정 권장

### 3.2 기본 패키지 설치
```bash
# 시스템 업데이트
sudo apt update && sudo apt upgrade -y

# 필수 패키지
sudo apt install -y curl git vim htop

# Docker 설치
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Docker Compose 설치 (최신)
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 재로그인 후 확인
docker --version
docker compose version
```

### 3.3 deploy 사용자 설정
```bash
# deploy 사용자 생성 (없는 경우)
sudo adduser deploy
sudo usermod -aG docker deploy
sudo usermod -aG sudo deploy

# deploy 사용자로 전환
su - deploy
```

### 3.4 Swap 설정 (1GB RAM 서버)
```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## 4. 복원 절차 (새 서버에서 실행)

### 4.1 Git 저장소 클론
```bash
cd /home/deploy

# 서버 설정 저장소
git clone https://github.com/tomtomjskim/jsnwcorp-server-config.git .
# 또는 기존 저장소 URL 사용

# 프로젝트 저장소들
mkdir -p projects
cd projects
git clone https://github.com/[org]/dashboard.git
git clone https://github.com/[org]/lotto-master.git
git clone https://github.com/[org]/today-fortune.git
git clone https://github.com/[org]/ai-chatbot.git
git clone https://github.com/[org]/author-clock.git
```

### 4.2 민감 파일 복원
```bash
# 민감 파일 복원 스크립트 실행
/home/deploy/scripts/restore-sensitive-files.sh /home/deploy/backups/sensitive/sensitive_backup_XXXXXXXX.tar.gz

# .env 파일 권한 확인
chmod 600 /home/deploy/.env
chmod 600 /home/deploy/projects/*/.env
```

### 4.3 Docker 네트워크 및 볼륨 생성
```bash
cd /home/deploy

# Docker 네트워크 생성
docker network create --subnet=172.20.0.0/16 webnet

# 볼륨은 docker-compose up 시 자동 생성됨
```

### 4.4 PostgreSQL 복원
```bash
# 1. PostgreSQL 컨테이너만 먼저 시작
docker compose up -d postgres
sleep 10  # 초기화 대기

# 2. 데이터베이스 복원
gunzip < /home/deploy/backups/postgres_XXXXXXXX.sql.gz | \
  docker exec -i postgres psql -U appuser -d maindb

# 또는 전체 덤프 복원 (pg_dumpall 사용 시)
cat /home/deploy/backups/full_db_XXXXXXXX.sql | \
  docker exec -i postgres psql -U appuser

# 3. 복원 확인
docker exec postgres psql -U appuser -d maindb -c "\dt public.*"
docker exec postgres psql -U appuser -d maindb -c "\dt lotto.*"
docker exec postgres psql -U appuser -d maindb -c "\dt author_clock.*"
```

### 4.5 Redis 복원
```bash
# Redis 컨테이너 시작
docker compose up -d redis
sleep 5

# Redis 데이터 복원 (볼륨 백업 사용 시)
docker compose stop redis
docker run --rm -v deploy_redis_data:/data -v /home/deploy/backups:/backup \
  alpine tar xzf /backup/redis_volume_XXXXXXXX.tar.gz -C /data
docker compose up -d redis
```

### 4.6 전체 서비스 빌드 및 시작
```bash
cd /home/deploy

# 모든 이미지 빌드
docker compose build

# 서비스 시작
docker compose up -d

# 상태 확인
docker compose ps
```

### 4.7 nginx 정적 파일 복원
```bash
# blog-automation 등 정적 파일 복원
tar xzf /home/deploy/backups/nginx_www_XXXXXXXX.tar.gz -C /home/deploy/nginx/

# 권한 설정
chmod -R o+rX /home/deploy/nginx/www/
```

---

## 5. 검증 절차

### 5.1 서비스 헬스체크
```bash
# 모든 컨테이너 healthy 확인
docker compose ps

# 개별 서비스 확인
curl -s http://localhost/api/health        # Dashboard
curl -s http://localhost:3001/api/health   # Lotto
curl -s http://localhost:3002/             # Today Fortune
curl -s http://localhost:3004/api/health   # Author Clock
curl -s http://localhost:3005/             # Blog Automation
```

### 5.2 데이터베이스 검증
```bash
# 레코드 수 확인
docker exec postgres psql -U appuser -d maindb -c "
  SELECT 'projects' as table_name, COUNT(*) FROM public.projects
  UNION ALL
  SELECT 'lotto.draws', COUNT(*) FROM lotto.draws
  UNION ALL
  SELECT 'author_clock.quotes', COUNT(*) FROM author_clock.quotes;
"
```

### 5.3 외부 접근 테스트
```bash
# 새 서버 IP로 접근 테스트 (한국 IP에서)
curl -I http://NEW_SERVER_IP/
curl -I http://NEW_SERVER_IP:3001/
```

---

## 6. DNS/IP 전환

### 6.1 IP 변경 시
1. nginx 설정에서 IP 참조 업데이트 (있는 경우)
2. Dashboard의 프로젝트 URL 업데이트:
```sql
UPDATE public.projects
SET url = REPLACE(url, '203.245.30.6', 'NEW_IP')
WHERE url LIKE '%203.245.30.6%';
```

### 6.2 도메인 연결 시
1. DNS A 레코드를 새 서버 IP로 변경
2. SSL 인증서 발급 (Let's Encrypt)
3. nginx subdomain 설정 활성화

---

## 7. 롤백 계획

문제 발생 시 롤백 절차:

1. **새 서버 문제 시**: 기존 서버 계속 운영
2. **부분 데이터 손실**: 백업에서 특정 테이블만 복원
3. **전체 실패**: 기존 서버 백업에서 완전 복원

```bash
# 기존 서버 백업으로 롤백
gunzip < /path/to/old_backup.sql.gz | docker exec -i postgres psql -U appuser -d maindb
```

---

## 8. 체크리스트

### 이전 전
- [ ] 모든 프로젝트 git push 완료
- [ ] 전체 백업 실행 및 확인
- [ ] 민감 파일 백업 완료
- [ ] 백업 파일 새 서버로 전송

### 이전 후
- [ ] Docker 설치 및 설정
- [ ] Git 저장소 클론
- [ ] .env 파일 복원 및 권한 설정
- [ ] PostgreSQL 데이터 복원
- [ ] Redis 데이터 복원 (필요 시)
- [ ] 모든 서비스 빌드 및 시작
- [ ] 헬스체크 통과
- [ ] 외부 접근 테스트
- [ ] DNS/IP 전환
- [ ] 기존 서버 백업 보관

---

## 참고 문서

- `/home/deploy/docs/shared-database-architecture.md` - DB 아키텍처 상세
- `/home/deploy/docs/docker-resource-management.md` - Docker 리소스 관리
- `/home/deploy/scripts/backup.sh` - 백업 스크립트
- `/home/deploy/scripts/restore-sensitive-files.sh` - 민감 파일 복원
- `/home/deploy/CLAUDE.md` - 전체 시스템 가이드
