# Blog Automation - 트러블슈팅 가이드

> 작성일: 2026-01-10
> 최종 수정: 2026-01-10

---

## 목차

1. [403 Forbidden 에러](#1-403-forbidden-에러)
2. [빈 화면 (JavaScript 에러)](#2-빈-화면-javascript-에러)
3. [GeoIP 차단 관련](#3-geoip-차단-관련)
4. [nginx 설정 문제](#4-nginx-설정-문제)
5. [배포 체크리스트](#5-배포-체크리스트)

---

## 1. 403 Forbidden 에러

### 1.1 파일 권한 문제 (가장 흔한 원인)

**증상:**
- 브라우저에서 403 Forbidden 에러
- Health check (`/health`)는 정상 (200)
- 한국 IP에서도 접근 불가

**원인:**
정적 파일(index.html, js, css 등)의 권한이 `600`으로 설정되어 nginx 프로세스가 읽을 수 없음.

**진단:**
```bash
# 컨테이너 내부에서 파일 권한 확인
docker compose exec nginx ls -la /var/www/blog-automation/

# 문제 있는 경우 출력 예시:
# -rw-------    1 1000     1000         14178 Jan  7 07:57 index.html
# ↑ 다른 사용자 읽기 권한 없음
```

**해결:**
```bash
# 호스트에서 권한 수정
chmod -R o+r /home/deploy/nginx/www/blog-automation/
chmod o+x /home/deploy/nginx/www/blog-automation/

# 소스 디렉토리도 수정 (향후 배포 시 문제 방지)
chmod -R o+r /home/deploy/projects/blog-automation/
```

**예방:**
배포 스크립트에 권한 설정 추가:
```bash
rsync -av --delete /home/deploy/projects/blog-automation/ /home/deploy/nginx/www/blog-automation/
chmod -R o+r /home/deploy/nginx/www/blog-automation/
```

---

### 1.2 Rate Limiting 초과

**증상:**
- 간헐적 503 Service Temporarily Unavailable
- 빠른 새로고침 시 차단

**원인:**
nginx rate limiting 설정 (`limit_req zone=general rate=10r/s burst=10`)

**진단:**
```bash
# nginx 에러 로그 확인
docker compose exec nginx tail -50 /var/log/nginx/error.log | grep "limiting"
```

**해결:**
일시적으로 발생하는 경우 정상. 지속적이면 rate limit 조정 필요.

---

## 2. 빈 화면 (JavaScript 에러)

### 2.1 Duplicate export 에러

**증상:**
- 페이지 로드 시 빈 화면 (스플래시 후 아무것도 안 보임)
- 콘솔에 `SyntaxError: Duplicate export of 'XXX'` 에러

**원인:**
ES 모듈에서 같은 함수/변수를 두 번 export함.

예시:
```javascript
// 라인 13
export function renderStatsPage(container) { ... }

// 라인 399 - 중복!
export { renderStatsPage };
```

**해결:**
중복된 export 구문 중 하나를 제거.

```bash
# 중복 export 찾기
grep -n "export.*함수명" js/pages/*.js
```

### 2.2 모듈 로딩 실패

**증상:**
- 빈 화면
- 콘솔에 `Failed to load module script` 또는 `404` 에러

**원인:**
1. 파일 경로 오타
2. 파일 권한 문제 (위 1.1 참조)
3. 파일이 배포되지 않음

**진단:**
```bash
# 브라우저 개발자 도구 (F12) → Network 탭
# 빨간색으로 표시된 요청 확인

# 또는 서버에서 직접 확인
curl -s -o /dev/null -w "%{http_code}" http://203.245.30.6:3005/js/파일명.js
```

### 2.3 브라우저 캐시 문제

**증상:**
- 수정 후에도 이전 버전이 로드됨
- 에러가 수정되지 않은 것처럼 보임

**해결:**
```
강력 새로고침: Ctrl + Shift + R (Mac: Cmd + Shift + R)
또는 시크릿/프라이빗 모드로 접속
```

---

## 3. GeoIP 차단 관련

### 3.1 한국 IP인데 차단되는 경우

**증상:**
- 한국에서 접속하는데 403 에러
- 로그에 `country=KR`로 표시되지만 차단

**원인:**
1. GeoIP 데이터베이스 outdated
2. 파일 권한 문제 (위 1.1 참조)
3. VPN/프록시 사용 중

**진단:**
```bash
# nginx 접근 로그에서 country 코드 확인
docker compose exec nginx tail -50 /var/log/nginx/access.log | grep "3005"

# 출력 예시:
# 58.238.165.94 - - [...] "GET / HTTP/1.1" 403 555 ... country=KR
# ↑ country=KR인데 403이면 파일 권한 문제
```

**GeoIP 설정 확인:**
```bash
# nginx.conf에서 설정 확인
docker compose exec nginx cat /etc/nginx/nginx.conf | grep -A10 "geoip2"
```

현재 설정:
```nginx
map $geoip2_data_country_code $allowed_country {
    default no;
    KR yes;      # 한국 허용
    "" yes;      # GeoIP 실패 시 허용 (로컬호스트 등)
}
```

### 3.2 로컬호스트/내부 테스트 시 차단

**증상:**
- 서버 내부에서 curl 테스트 시 403
- `country=-` 또는 빈 값으로 표시

**원인:**
로컬 IP(127.0.0.1, 172.x.x.x)는 GeoIP 데이터베이스에 없음

**해결:**
현재 설정에서 `"" yes;`로 빈 country 허용됨. 그래도 403이면 파일 권한 문제.

---

## 4. nginx 설정 문제

### 4.1 설정 문법 오류

**진단:**
```bash
# nginx 설정 테스트
docker compose exec nginx nginx -t
```

**해결:**
```bash
# 설정 수정 후 리로드
docker compose exec nginx nginx -s reload
```

### 4.2 try_files 실패

**증상:**
- SPA 라우팅 실패
- 직접 URL 접근 시 404

**원인:**
`try_files $uri $uri/ /index.html;` 설정에서 index.html을 찾지 못함

**진단:**
```bash
# 파일 존재 여부 확인
docker compose exec nginx ls -la /var/www/blog-automation/index.html
```

---

## 5. 배포 체크리스트

### 배포 전 확인사항

```bash
# 1. 소스 파일 동기화
rsync -av --delete \
  --exclude='.git' \
  --exclude='DEV_README.md' \
  --exclude='nginx' \
  /home/deploy/projects/blog-automation/ \
  /home/deploy/nginx/www/blog-automation/

# 2. 파일 권한 설정 (필수!)
chmod -R o+r /home/deploy/nginx/www/blog-automation/

# 3. nginx 설정 테스트
docker compose exec nginx nginx -t

# 4. nginx 리로드
docker compose exec nginx nginx -s reload

# 5. 서비스 확인
curl -s -o /dev/null -w "%{http_code}\n" http://203.245.30.6:3005/
curl -s -o /dev/null -w "%{http_code}\n" http://203.245.30.6:3005/health
curl -s -o /dev/null -w "%{http_code}\n" http://203.245.30.6:3005/js/app.js
```

### 예상 결과

| 엔드포인트 | 정상 | 문제 시 |
|-----------|------|--------|
| `/` | 200 | 403 (권한), 404 (파일 없음) |
| `/health` | 200 | - |
| `/js/app.js` | 200 | 403 (권한), 404 (파일 없음) |

---

## 문제 해결 순서

1. **로그 확인**: `docker compose exec nginx tail -100 /var/log/nginx/access.log`
2. **파일 권한 확인**: `docker compose exec nginx ls -la /var/www/blog-automation/`
3. **파일 권한 수정**: `chmod -R o+r /home/deploy/nginx/www/blog-automation/`
4. **설정 테스트**: `docker compose exec nginx nginx -t`
5. **서비스 테스트**: `curl http://203.245.30.6:3005/`

---

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-01-10 | 초기 작성: 403 에러 원인 및 해결 방법 문서화 |
| 2026-01-10 | 빈 화면 문제 추가: Duplicate export 에러, 모듈 로딩 실패, 캐시 문제 |
