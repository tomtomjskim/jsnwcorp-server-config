# 멀티 프로젝트 웹서버 환경 사용 가이드

> Docker 기반 멀티 프로젝트 웹서버 환경 운영 가이드

**서버 IP**: 203.245.30.6
**도메인 (예정)**: jsnwcorp.com
**현재 단계**: Phase 1 - 포트 기반 라우팅

---

## 📑 목차

1. [빠른 시작](#빠른-시작)
2. [서비스 관리](#서비스-관리)
3. [새 프로젝트 추가 방법](#새-프로젝트-추가-방법)
4. [프록시 설정 추가](#프록시-설정-추가)
5. [도메인 설정 (Phase 2)](#도메인-설정-phase-2)
6. [주의사항](#주의사항)
7. [트러블슈팅](#트러블슈팅)

---

## 🚀 빠른 시작

### 현재 배포된 서비스

```bash
# 서비스 상태 확인
docker compose ps

# 모니터링
./scripts/monitor.sh
```

**접근 URL:**
- Dashboard: http://203.245.30.6
- Health Check: http://203.245.30.6/health

---

## 🔧 서비스 관리

### 기본 명령어

```bash
# 프로젝트 디렉토리로 이동
cd /home/deploy

# 전체 서비스 시작
docker compose up -d

# 전체 서비스 중지
docker compose down

# 전체 서비스 재시작
docker compose restart

# 특정 서비스만 재시작
docker compose restart dashboard

# 로그 확인
docker compose logs -f
docker compose logs -f dashboard
```

### 배포 스크립트 사용

```bash
# 전체 재배포
./scripts/deploy.sh

# 특정 서비스만 재배포
./scripts/deploy.sh dashboard
```

### 백업 및 복원

**자동 백업 (설정됨):**
- **실행 주기**: 매일 새벽 2시
- **백업 대상**: PostgreSQL, Redis, 설정 파일, 프로젝트 파일
- **백업 위치**: `/home/deploy/backups/`
- **보존 기간**: 60일
- **백업 로그**: `tail -f /home/deploy/logs/backup.log`

**백업 스크립트:**
```bash
# 수동 백업 실행
/home/deploy/scripts/backup.sh

# 백업 파일 확인
ls -lh /home/deploy/backups/

# 최근 백업 보기
ls -lt /home/deploy/backups/ | head -5
```

**복원 방법:**
```bash
# 전체 복원 스크립트 사용 (권장)
./scripts/restore.sh --list              # 백업 목록 확인
./scripts/restore.sh --latest            # 최신 백업으로 복원
./scripts/restore.sh --latest --db-only  # DB만 복원

# 민감 파일 복원 (.env 등)
./scripts/restore-sensitive-files.sh /home/deploy/backups/sensitive/sensitive_backup_XXXXXX.tar.gz

# 수동 복원 (개별)
gunzip < /home/deploy/backups/postgres_TIMESTAMP.sql.gz | \
  docker exec -i postgres psql -U appuser -d maindb
```

**서버 이전:**
```bash
# 서버 이전 가이드 참조
cat /home/deploy/docs/SERVER_MIGRATION_GUIDE.md

# 이전 전 민감 파일 백업
./scripts/backup-sensitive-files.sh

# 백업 파일 전송
scp -r /home/deploy/backups/* user@new-server:/home/deploy/backups/
```

---

## ➕ 새 프로젝트 추가 방법

### Step 1: 프로젝트 디렉토리 생성

```bash
# 예: service1 추가
mkdir -p /home/deploy/projects/service1
cd /home/deploy/projects/service1
```

### Step 2: 프로젝트 파일 준비

#### Node.js 프로젝트 예시

**package.json**
```json
{
  "name": "service1",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
```

**server.js**
```javascript
const express = require('express');
const app = express();
const PORT = process.env.PORT || 4000;

app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

app.get('/', (req, res) => {
  res.json({
    service: 'service1',
    status: 'running',
    timestamp: new Date().toISOString()
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Service1 running on port ${PORT}`);
});
```

**Dockerfile**
```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --only=production

COPY . .

RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
RUN chown -R nodejs:nodejs /app
USER nodejs

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD node -e "require('http').get('http://localhost:4000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

CMD ["node", "server.js"]
```

### Step 3: docker-compose.yml에 서비스 추가

`/home/deploy/docker-compose.yml` 파일을 열어 services 섹션에 추가:

```yaml
  service1:
    build:
      context: ./projects/service1
      dockerfile: Dockerfile
    container_name: service1
    restart: always
    environment:
      - NODE_ENV=production
      - PORT=4000
      - DB_HOST=postgres
      - REDIS_HOST=redis
    networks:
      webnet:
        ipv4_address: 172.20.0.11
    depends_on:
      - postgres
      - redis
    mem_limit: 192m
    cpus: 0.25
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:4000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s
```

**⚠️ 주의사항:**
- `ipv4_address`: 다른 서비스와 중복되지 않는 IP 사용 (172.20.0.11 ~ 172.20.0.254)
- `mem_limit`: 전체 메모리(1GB) 고려하여 할당
- `container_name`: 고유한 이름 사용

### Step 4: nginx 프록시 추가

프록시를 추가하는 방법은 [다음 섹션](#프록시-설정-추가)을 참조하세요.

### Step 5: 빌드 및 배포

```bash
cd /home/deploy

# 새 서비스만 빌드
docker compose build service1

# 새 서비스 시작
docker compose up -d service1

# 상태 확인
docker compose ps
docker compose logs -f service1
```

---

## 🌐 프록시 설정 추가

### Phase 1: 포트 기반 프록시 추가

`/home/deploy/nginx/conf.d/port-based.conf` 파일에 새 server 블록 추가:

```nginx
# Service 1 - Port 3001
server {
    listen 3001;
    server_name _;

    # 한국 IP 화이트리스트
    include /etc/nginx/conf.d/korean-ips.conf;

    location / {
        limit_req zone=api burst=20 nodelay;

        proxy_pass http://172.20.0.11:4000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 타임아웃 설정
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

**nginx 재시작:**
```bash
docker compose restart nginx
```

**접근 테스트:**
```bash
curl http://localhost:3001
# 또는
curl http://203.245.30.6:3001
```

### Phase 2: 서브도메인 프록시 (도메인 구매 후)

도메인 구매 후 `/home/deploy/nginx/conf.d/subdomain.conf` 생성:

```nginx
# Service 1 - service1.jsnwcorp.com
server {
    listen 443 ssl http2;
    server_name service1.jsnwcorp.com;

    ssl_certificate /etc/nginx/ssl/jsnwcorp.com.crt;
    ssl_certificate_key /etc/nginx/ssl/jsnwcorp.com.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    # 한국 IP 화이트리스트
    include /etc/nginx/conf.d/korean-ips.conf;

    location / {
        limit_req zone=api burst=20 nodelay;

        proxy_pass http://172.20.0.11:4000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# HTTP to HTTPS 리다이렉트
server {
    listen 80;
    server_name service1.jsnwcorp.com;
    return 301 https://$host$request_uri;
}
```

---

## 🌍 도메인 설정 (Phase 2)

### 1. 도메인 구매

**추천 등록 대행:**
- Namecheap
- GoDaddy
- Cafe24

**비용:** 연 $10-20

### 2. DNS 설정

도메인 관리 페이지에서 A 레코드 추가:

```
Type    Name        Value           TTL
A       @           203.245.30.6    3600
A       app         203.245.30.6    3600
A       service1    203.245.30.6    3600
A       service2    203.245.30.6    3600
A       *           203.245.30.6    3600
```

**DNS 전파 대기:** 24-48시간

### 3. SSL 인증서 발급

```bash
# Certbot 설치
sudo apt install certbot python3-certbot-nginx

# 인증서 발급
sudo certbot certonly --nginx \
  -d jsnwcorp.com \
  -d app.jsnwcorp.com \
  -d service1.jsnwcorp.com \
  -d service2.jsnwcorp.com \
  -d service3.jsnwcorp.com

# 인증서를 nginx 디렉토리로 복사
sudo cp /etc/letsencrypt/live/jsnwcorp.com/fullchain.pem \
    /home/deploy/nginx/ssl/jsnwcorp.com.crt

sudo cp /etc/letsencrypt/live/jsnwcorp.com/privkey.pem \
    /home/deploy/nginx/ssl/jsnwcorp.com.key

sudo chown -R root:root /home/deploy/nginx/ssl
sudo chmod 644 /home/deploy/nginx/ssl/*.crt
sudo chmod 600 /home/deploy/nginx/ssl/*.key
```

### 4. Nginx 설정 전환

```bash
cd /home/deploy/nginx/conf.d

# 포트 기반 비활성화
mv port-based.conf port-based.conf.disabled

# 서브도메인 활성화
mv subdomain.conf.disabled subdomain.conf

# Nginx 재시작
docker compose restart nginx

# 테스트
curl https://app.jsnwcorp.com
```

### 5. SSL 자동 갱신 설정

```bash
# Crontab 편집
sudo crontab -e

# 다음 라인 추가 (매월 1일 새벽 3시에 갱신)
0 3 1 * * certbot renew --quiet && cp /etc/letsencrypt/live/jsnwcorp.com/*.pem /home/deploy/nginx/ssl/ && docker compose -f /home/deploy/docker-compose.yml restart nginx
```

---

## ⚠️ 주의사항

### 1. 메모리 관리

**현재 할당:**
- nginx: 64MB
- dashboard: 128MB
- service1: 192MB (예정)
- service2: 128MB (예정)
- service3: 64MB (예정)
- postgres: 192MB
- redis: 96MB
- **합계**: ~864MB / 1GB

**새 서비스 추가 시:**
- 전체 메모리 사용량이 1GB를 넘지 않도록 주의
- 기존 서비스의 메모리 할당 조정 필요시 docker-compose.yml에서 `mem_limit` 수정
- 모니터링 스크립트로 정기 확인: `./scripts/monitor.sh`

### 2. 디스크 및 로그 관리

**현재 사용량:** 8.7GB / 26GB (37%)

**자동 로그 정리 (설정됨):**
- **실행 주기**: 매일 새벽 3시
- **보존 기간**: 30일
- **관리 대상**:
  - Nginx 로그 (`/home/deploy/nginx/logs/*.log`)
  - Docker 컨테이너 로그 (자동 로테이션: 10MB × 3개 파일)
  - 백업 파일 (60일 이상)
  - systemd journal 로그
- **로그 확인**: `tail -f /home/deploy/logs/cleanup.log`

**로그 관리 스크립트:**
```bash
# 수동 실행 (Dry-run - 삭제하지 않고 확인만)
/home/deploy/scripts/cleanup-logs.sh -n

# 수동 실행 (실제 삭제)
/home/deploy/scripts/cleanup-logs.sh

# 60일 보존으로 실행
/home/deploy/scripts/cleanup-logs.sh -d 60

# Cron 설정 확인
crontab -l

# Cron 설정 변경
crontab -e
```

**Docker 로그 로테이션 설정 (적용됨):**
- 각 컨테이너: 최대 10MB × 3개 파일 = 30MB
- 설정은 `docker-compose.yml`의 `logging` 섹션에서 관리

**정기 정리:**
```bash
# Docker 이미지 정리
docker image prune -af

# 사용하지 않는 볼륨 정리 (주의!)
docker volume prune -f

# 빌드 캐시 정리
docker builder prune -af
```

### 3. 보안

**환경 변수 관리:**
```bash
# .env 파일 권한 확인
ls -la /home/deploy/.env
# -rw------- (600) 이어야 함

# 권한 수정
chmod 600 /home/deploy/.env
```

**비밀번호 변경:**
- `.env` 파일의 모든 default 비밀번호를 운영 환경용으로 변경
- PostgreSQL: `POSTGRES_PASSWORD`
- Redis: `REDIS_PASSWORD`
- JWT: `JWT_SECRET`

### 4. IP 주소 충돌 방지

**사용 중인 IP:**
- 172.20.0.2: nginx-proxy
- 172.20.0.10: dashboard
- 172.20.0.20: postgres
- 172.20.0.21: redis

**새 서비스 IP:**
- 172.20.0.11 ~ 172.20.0.19: 애플리케이션 서비스
- 172.20.0.22 ~ 172.20.0.254: 추가 서비스

### 5. 포트 관리

**사용 중인 포트:**
- 80: Dashboard (포트 기반)
- 443: HTTPS (향후)
- 3001, 3002, 3003: 예약됨 (service1, 2, 3)

**docker-compose.yml의 nginx ports 섹션에 새 포트 추가 필요:**
```yaml
ports:
  - "80:80"
  - "443:443"
  - "3001:3001"
  - "3002:3002"
  - "3003:3003"
  - "3004:3004"  # 새 포트 추가 예시
```

### 6. 컨테이너 이름 고유성

각 서비스의 `container_name`은 서버 전체에서 고유해야 합니다:
```yaml
container_name: service1  # ✅ 좋음
container_name: my-app    # ✅ 좋음
container_name: nginx     # ❌ 나쁨 (nginx-proxy와 중복)
```

---

## 🔍 트러블슈팅

### 문제: 컨테이너가 시작하지 않음

```bash
# 1. 로그 확인
docker compose logs service1

# 2. 설정 검증
docker compose config

# 3. 강제 재생성
docker compose up -d --force-recreate service1
```

### 문제: 포트 충돌

```bash
# 1. 포트 사용 확인
netstat -tuln | grep :3001

# 2. 해당 프로세스 확인
lsof -i :3001

# 3. docker-compose.yml에서 다른 포트로 변경
```

### 문제: 메모리 부족

```bash
# 1. 현재 사용량 확인
docker stats

# 2. 불필요한 컨테이너 중지
docker compose stop service_name

# 3. 메모리 할당 조정
# docker-compose.yml에서 mem_limit 값 조정
```

### 문제: nginx 설정 오류

```bash
# 1. nginx 컨테이너 내부에서 설정 테스트
docker compose exec nginx nginx -t

# 2. 오류 로그 확인
docker compose logs nginx | grep error

# 3. 설정 파일 문법 확인
# nginx/conf.d/*.conf 파일 검토
```

### 문제: 한국 IP에서도 접근 불가

```bash
# 1. 현재 IP 확인
curl ifconfig.me

# 2. korean-ips.conf에 IP 대역 추가
# nginx/conf.d/korean-ips.conf 편집

# 3. nginx 재시작
docker compose restart nginx
```

---

## 📚 추가 참고 자료

**프로젝트 문서:**
- `/home/deploy/docs/SERVER_MIGRATION_GUIDE.md` - **서버 이전 가이드** (백업/복원 상세)
- `/home/deploy/docs/shared-database-architecture.md` - DB 아키텍처 설계
- `/home/deploy/docs/architecture.md` - 전체 아키텍처
- `/home/deploy/docs/quick-reference.md` - 명령어 치트시트
- `/home/deploy/docs/implementation-checklist.md` - 구현 체크리스트
- `/home/deploy/docs/server-history.md` - 작업 이력
- `/home/deploy/docs/project-summary.md` - 프로젝트 요약

**백업/복원 스크립트:**
- `/home/deploy/scripts/backup.sh` - 전체 백업 (DB, 설정, 프로젝트)
- `/home/deploy/scripts/restore.sh` - 전체 복원
- `/home/deploy/scripts/backup-sensitive-files.sh` - 민감 파일 백업 (.env)
- `/home/deploy/scripts/restore-sensitive-files.sh` - 민감 파일 복원

**문서 보기:**
```bash
# 특정 문서 읽기
cat /home/deploy/docs/architecture.md
cat /home/deploy/docs/quick-reference.md
cat /home/deploy/docs/implementation-checklist.md
cat /home/deploy/docs/server-history.md

# 또는 에디터로 열기
nano /home/deploy/docs/architecture.md
```

**공식 문서:**
- [Docker 공식 문서](https://docs.docker.com/)
- [nginx 설정 가이드](https://nginx.org/en/docs/)
- [Let's Encrypt](https://letsencrypt.org/)

---

## 🆘 도움말

문제가 발생하면:

1. **로그 확인**: `docker compose logs -f`
2. **모니터링**: `./scripts/monitor.sh`
3. **문서 참조**: 위의 트러블슈팅 섹션
4. **설정 검증**: `docker compose config`

---

**문서 버전**: 1.2
**최종 수정**: 2026-01-12
**관리자**: deploy
