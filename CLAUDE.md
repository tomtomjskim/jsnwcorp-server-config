# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Multi-project Docker-based web server environment running on Ubuntu 22.04 with limited resources (1GB RAM, 30GB disk). The system hosts multiple isolated services using Docker Compose with nginx as a reverse proxy.

**Server**: 203.245.30.6
**User Context**: Running as `deploy` user
**Working Directory**: `/home/deploy`
**Domain (future)**: jsnwcorp.com

## Active Services

- **nginx-proxy** (172.20.0.2): Reverse proxy with Korean IP whitelist
- **dashboard** (172.20.0.10): Express.js service on port 80, PostgreSQL-based dynamic project management
- **lotto-service** (172.20.0.11): Next.js 15 lottery service on port 3001
- **today-fortune** (172.20.0.12): Vite-based fortune telling service on port 3002
- **ai-chatbot** (172.20.0.14): Python/FastAPI RAG chatbot with Groq API integration on port 8000
- **author-clock** (172.20.0.15-16): Vite+React+Express fullstack quote & clock service on port 3004
- **postgres** (172.20.0.20): PostgreSQL 15 shared database (projects, analytics, lotto, author_clock schemas)
- **redis** (172.20.0.21): Redis 7 cache
- **ollama** (172.20.0.13): Local LLM service (현재 미사용, unhealthy 상태)

## Project Structure

```
/home/deploy/
├── docker-compose.yml      # All service definitions
├── .env                    # Environment variables (secured, chmod 600)
├── nginx/
│   ├── nginx.conf
│   └── conf.d/
│       ├── port-based.conf    # Current routing (Phase 1)
│       ├── korean-ips.conf    # IP whitelist include
│       └── subdomain.conf     # Future domain-based routing
├── projects/
│   ├── dashboard/             # Express.js simple dashboard
│   ├── lotto-master/          # Next.js 15 lottery service
│   ├── ai-chatbot/            # Python/FastAPI RAG chatbot
│   ├── today-fortune/         # Vite-based fortune service
│   ├── author-clock/          # Vite+React+Express quote & clock service
│   └── service1-2/            # Reserved slots
├── scripts/
│   ├── deploy.sh              # Service deployment
│   ├── backup.sh              # Automated backups
│   ├── monitor.sh             # Resource monitoring
│   └── cleanup-logs.sh        # Log rotation
├── docs/                      # Extensive documentation
├── backups/                   # Automated daily backups (2am)
└── logs/                      # Operation logs
```

## Architecture

### Resource Allocation (1GB RAM Total)

| Service       | Memory | CPU  | Port      | Notes                    |
|---------------|--------|------|-----------|--------------------------|
| nginx         | 64MB   | 0.1  | 80,443,3001-3004 | Alpine image   |
| dashboard     | 128MB  | 0.2  | 3000      | Express.js               |
| lotto-service | 256MB  | 1.0  | 3000      | Next.js standalone       |
| ai-chatbot    | 128MB  | 0.2  | 8000      | FastAPI, BM25, Groq API  |
| author-clock-api | 96MB | 0.15 | 3000      | Express.js, Redis cache  |
| author-clock-frontend | 64MB | 0.1 | 80   | Vite+React SPA           |
| postgres      | 192MB  | 0.2  | 5432      | Shared DB, tuned for 1GB |
| redis         | 96MB   | 0.1  | 6379      | 64MB maxmemory           |

### Network Configuration

Docker network `webnet` (172.20.0.0/16) with static IPs. All services communicate internally via Docker networking. External access via nginx proxy with Korean IP whitelist.

### Database Architecture

**Shared PostgreSQL**: All services use the same `maindb` database but separate schemas:
- `public` schema: Shared infrastructure
  - `projects` table: Dynamic project registry (Dashboard loads from here)
  - `analytics_events` table: Cross-project event tracking (partitioned monthly)
  - `api_logs` table: API request logs (partitioned monthly)
  - `developers` table: Developer/team information
- `lotto` schema: Lotto service tables
  - `draw_results`, `generation_history`, etc.
- `author_clock` schema: Author Clock service tables
  - `quotes`, `daily_quotes`, `users`, `user_likes`, `view_logs`, `translations`

**Dynamic Project Management**: Dashboard queries `public.projects` table on every request, eliminating hardcoded project arrays. New projects appear automatically after SQL INSERT.

The lotto service uses direct `pg` connections (not Prisma) with connection pooling configured in `src/lib/db.ts`.

## Common Commands

### Service Management

```bash
# View all services status
docker compose ps

# View logs
docker compose logs -f [service]
docker compose logs lotto-service --tail 50

# Restart service
docker compose restart [service]

# Check resource usage
docker stats
```

### Build & Deploy

**IMPORTANT**: Always follow the deployment policy in `/home/deploy/docs/deployment-policy.md`

```bash
# Build specific service (does NOT deploy)
docker compose build lotto-service

# Deploy service (requires explicit user approval)
docker compose up -d lotto-service

# Full deployment script
./scripts/deploy.sh [service]
```

**Deployment Policy**: Never deploy without explicit user request containing "deploy", "배포", or similar keywords. Building and deploying are separate steps.

### Database Operations

```bash
# Connect to PostgreSQL
docker exec -it postgres psql -U appuser -d maindb

# Run migrations for lotto service
docker exec lotto-service npm run migrate

# Fetch lottery data (manual)
docker exec lotto-service npm run fetch-data-db -- --latest

# Note: Lottery data is automatically collected via cron
# Schedule: Sun 00:00, 09:00 / Mon,Tue 00:00
# Script: /home/deploy/projects/lotto-master/scripts/lotto-cron-smart.sh
# Logs: /var/log/lotto-cron.log

# View database from lotto service
docker exec -it lotto-service sh
# Then inside container:
psql postgresql://lotto_user:password@postgres:5432/maindb
\c maindb
SET search_path TO lotto,public;
\dt
```

### Monitoring & Debugging

```bash
# Resource monitoring script
./scripts/monitor.sh

# Check nginx config
docker compose exec nginx nginx -t

# View nginx access logs
tail -f /home/deploy/nginx/logs/access.log

# Container health checks
docker compose ps
# Look for (healthy) status
```

### Backup & Restore

```bash
# Manual backup (auto runs daily at 2am)
/home/deploy/scripts/backup.sh

# List backups
ls -lht /home/deploy/backups/ | head -5

# Restore database
gunzip < /home/deploy/backups/postgres_TIMESTAMP.sql.gz | \
  docker exec -i postgres psql -U appuser -d maindb
```

## LottoMaster Service Details

Next.js 15 application with the following key characteristics:

- **Framework**: Next.js 15.5.5 with App Router
- **Database**: Direct PostgreSQL connection via `pg` library (no Prisma)
- **Schema**: Uses `lotto` schema in shared `maindb` database
- **Environment Variables**: Configured in docker-compose.yml from `.env`
  - `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`
  - `POSTGRES_USER=lotto_user`, `POSTGRES_PASSWORD`
  - `POSTGRES_SCHEMA=lotto`
- **Analytics**: Shared analytics system with PROJECT_ID tracking
- **Build**: Standalone output mode for minimal Docker image size

### Key Files

- `src/lib/db.ts`: PostgreSQL connection pool (20 max connections)
- `src/lib/analytics.ts`: Server-side analytics tracking
- `scripts/fetch-lotto-data-db.ts`: PostgreSQL lottery data fetcher (current)
- `scripts/fetch-lotto-data.ts`: Legacy JSON-based fetcher
- `scripts/lotto-cron-smart.sh`: Automated data collection cron script
- API routes in `src/app/api/`:
  - `/api/health`: Health check
  - `/api/lotto/generate`: Number generation
  - `/api/lotto/history`: Historical data
  - `/api/stats/dashboard`: Statistics

### Automated Data Collection

Lottery data is automatically collected via cron job:
- **Schedule**:
  - Sunday 00:00, 09:00 (after draw day)
  - Monday, Tuesday 00:00 (retry for delayed announcements)
- **Script**: `/home/deploy/projects/lotto-master/scripts/lotto-cron-smart.sh`
- **Features**:
  - Smart retry logic with weekly deduplication flag
  - PostgreSQL connection test before execution
  - Logs all activities to `/var/log/lotto-cron.log`
  - Automatic cleanup of old flag files (7 days)
- **Manual trigger**: `docker exec lotto-service npm run fetch-data-db -- --latest`
- **View logs**: `tail -f /var/log/lotto-cron.log`

## Critical Constraints

### Memory Management

Total RAM: 1GB. Current usage ~736MB. Always check before adding services:

```bash
docker stats --no-stream
free -h
```

### Disk Management

30GB total, ~39% used. Automated cleanup runs daily at 3am via cron:
- Docker logs: 10MB × 3 files per container
- Nginx logs: 30 days retention
- Backups: 60 days retention

### Security

- Korean IP whitelist enforced on all services (see `nginx/conf.d/korean-ips.conf`)
- `.env` file must be chmod 600
- No default passwords in production

## Development Workflow

### Adding a New Service

**IMPORTANT**: This system uses **PostgreSQL-based dynamic project management**. New projects are added via database INSERT, not code changes.

#### Step 1: Docker Infrastructure Setup

1. Create project directory in `/home/deploy/projects/[service-name]`
2. Add Dockerfile with Alpine base image (memory efficiency)
3. Update `docker-compose.yml`:
   - Assign unique IP (172.20.0.x, check existing: .2, .10, .11, .12, .20, .21)
   - Set memory limits and CPU reservations
   - Add healthcheck
   - Configure logging (json-file, 10m max-size, 3 max-file)
4. Update nginx config in `nginx/conf.d/port-based.conf`
5. Build: `docker compose build [service]`
6. Get user approval for deployment
7. Deploy: `docker compose up -d [service]`

#### Step 2: Register Project in PostgreSQL

**NO CODE CHANGES NEEDED** - Dashboard automatically loads projects from database.

```sql
-- Register new project (Dashboard will auto-display it)
INSERT INTO public.projects (
  id, name, display_name, emoji, description,
  category, status, version, url, internal_url, port,
  health_check_endpoint, tags, developer
) VALUES (
  'my-project',           -- Unique ID (lowercase, hyphens allowed)
  'MyProject',            -- Code name
  '나의 프로젝트',        -- Display name (Korean OK)
  '🚀',                   -- Icon emoji
  'Project description',  -- Description
  'full-stack',           -- Category: frontend/backend/full-stack/ai-application
  'active',               -- Status: active/development/maintenance/archived
  '1.0.0',                -- Version
  'http://203.245.30.6:3004',      -- External URL
  'http://172.20.0.13:3000',       -- Internal Docker URL
  3004,                   -- External port (check available: 3004+)
  '/health',              -- Health check endpoint (optional)
  ARRAY['React', 'Node.js'],       -- Tech tags
  'team-a'                -- Developer/team
);
```

#### Step 3: Verify Auto-Registration

```bash
# Check PostgreSQL registration
docker exec -it postgres psql -U appuser -d maindb -c \
  "SELECT id, display_name, status, url FROM public.projects ORDER BY id;"

# Verify Dashboard API (should show new project automatically)
curl -s http://localhost/api/projects | grep "my-project"

# Check Dashboard UI (no rebuild needed!)
# Visit http://203.245.30.6 - project card appears automatically
```

**Key Benefits**:
- ✅ NO Dashboard code changes required
- ✅ NO Dashboard rebuild/redeploy needed
- ✅ Project appears in Dashboard immediately after SQL INSERT
- ✅ Analytics automatically tracks new project
- ✅ Easy to maintain as projects scale

**Detailed Guide**: See `/home/deploy/docs/adding-new-project.md`

### Modifying Existing Services

1. Make code changes in `/home/deploy/projects/[service]`
2. Build new image: `docker compose build [service]`
3. Request deployment approval from user
4. Deploy: `docker compose up -d [service]` (rolling update, no downtime)
5. Monitor: `docker compose logs -f [service]`
6. Rollback if needed: Use previous image or restore from backup

### Testing Changes

```bash
# For Next.js services (like lotto-master)
cd /home/deploy/projects/lotto-master
npm run build  # Test build locally first

# For Docker changes
docker compose config  # Validate docker-compose.yml
docker compose build [service]  # Build without deploying
```

## Important Notes

- **Deployment requires explicit approval**: See `/home/deploy/docs/deployment-policy.md`
- **Resource limits are strict**: Monitor memory usage constantly
- **All services share PostgreSQL/Redis**: Coordinate schema changes
- **Backups run automatically**: Daily at 2am, 60-day retention
- **Logs auto-rotate**: 3am daily, 30-day retention
- **Korean IP whitelist**: Cannot be bypassed without user request
- **No Prisma in lotto-service**: Uses direct `pg` connections with schema-specific search paths

## Documentation

Extensive documentation available in `/home/deploy/docs/`:
- `architecture.md`: Complete system architecture
- `deployment-policy.md`: Deployment rules and approval process
- `project-summary.md`: Project overview and integration strategy
- `quick-reference.md`: Command cheat sheet
- `troubleshooting-history.md`: Common issues and solutions
- `adding-new-project.md`: **Step-by-step guide for adding new projects** (PostgreSQL-based, no code changes)
- `analytics-scalable-architecture.md`: Analytics system architecture and scalability design
- `README.md`: User-facing guide (Korean)

## Phase Planning

**Current**: Phase 1 - Port-based routing (http://203.245.30.6:3001)
**Future**: Phase 2 - Subdomain routing (https://lotto.jsnwcorp.com)

Configuration files for both phases exist in `nginx/conf.d/`. Phase 2 requires domain purchase and SSL certificate setup.
- 각 프로젝트 개발 구현 진행 후 빌드, docker 배포는 자동으로 진행하지 말것. 별도의 사용자 컨펌을 받거나 명시하는 경우만 진행. 서버 사양이 낮기에 빌드 배포가 오래걸림.