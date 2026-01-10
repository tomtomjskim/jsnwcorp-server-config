# 블로그 자동화 서비스 - 기획/설계 문서

> 프로젝트명: BlogAuto (가칭)
> 작성일: 2026-01-07
> 상태: 기획 단계

---

## 프로젝트 개요

LLM API를 활용하여 네이버 블로그 게시글을 자동으로 생성하고 포스팅하는 웹 서비스

### 핵심 기능
- 다양한 LLM API 연동 (OpenAI, Claude, Gemini, Groq 등)
- 스타일별 블로그 글 자동 생성
- AI 이미지 생성 (Stability AI, DALL-E)
- 네이버 블로그 자동 포스팅

### 기술 스택 (권장)
- **Frontend**: Vanilla JS + Tailwind CSS (CDN)
- **Storage**: localStorage (암호화)
- **CORS Proxy**: 기존 nginx 활용
- **빌드**: 불필요 (정적 파일)

---

## 문서 목록

| # | 문서 | 설명 |
|---|------|------|
| 00 | [인덱스](./00-index.md) | 현재 문서 |
| 01 | [디자인 가이드라인](./01-design-guide.md) | 컬러, 타이포, 간격, 애니메이션 |
| 02 | [UI 컴포넌트](./02-ui-components.md) | 버튼, 입력, 카드, 모달 등 |
| 03 | [화면 구성 및 플로우](./03-screens-flow.md) | 전체 화면 설계, 사용자 플로우 |
| 04 | [LLM API 아키텍처](./04-llm-api-architecture.md) | Provider 연동, 프롬프트, 에러 처리 |
| 05 | [기술 설계 명세서](./05-technical-spec.md) | 파일 구조, 핵심 모듈, API 설계 |
| 06 | [고급 기능 설계](./06-advanced-features.md) | 키보드 단축키, 스트리밍, 대량생성 등 |
| 07 | [Phase 2-3 구현 계획](./07-phase2-implementation-plan.md) | 미구현 기능 상세 구현 계획 (예약포스팅, 대량생성, SEO, 통계, PWA) |
| 08 | [고도화 및 편의성 개선](./08-enhancement-features.md) | 이미지 업로드, 템플릿, 마크다운 미리보기, 시리즈 관리 등 |
| 09 | [트러블슈팅 가이드](./09-troubleshooting.md) | 403 에러, GeoIP 차단, 배포 체크리스트 |
| 10 | [UI/UX 개선 전략](./10-ui-ux-improvements.md) | 레이아웃 개선, LLM 설정 분리, 모바일 네비게이션, 보안 UX |

---

## 빠른 참조

### 컬러

```css
--primary: #0066FF;
--gray-900: #191F28;  /* 제목 */
--gray-700: #333D4B;  /* 본문 */
--gray-500: #6B7684;  /* 보조 */
```

### 지원 LLM (기본: Claude)

| Provider | 무료 | 권장 모델 | 비고 |
|----------|------|-----------|------|
| **Anthropic** | ❌ | claude-sonnet-4 | ⭐ **기본** |
| **Anthropic** | ❌ | claude-opus-4-5 | Premium, Extended Thinking |
| Groq | ✅ 14,400 req/day | llama-3.1-70b | 무료 대안 |
| Google | ✅ 60 req/min | gemini-1.5-flash | 무료 대안 |
| OpenAI | ❌ | gpt-4o-mini | 고품질 |

### 구현 단계

```
Phase 1: MVP
├── 정적 HTML/CSS/JS
├── LLM 글 생성
└── 수동 복사

Phase 2: 자동화
├── nginx CORS 프록시
├── 네이버 블로그 API
└── 자동 포스팅

Phase 3: 이미지
├── Stability AI 연동
├── 프롬프트 자동 생성
└── 이미지 첨부
```

---

## 파일 구조 (예정)

```
/home/deploy/projects/blog-automation/
├── index.html
├── css/
│   ├── variables.css
│   └── style.css
├── js/
│   ├── app.js
│   ├── crypto.js
│   ├── storage.js
│   ├── providers/
│   │   ├── base.js
│   │   ├── openai.js
│   │   ├── anthropic.js
│   │   ├── google.js
│   │   ├── groq.js
│   │   └── stability.js
│   ├── blog/
│   │   ├── generator.js
│   │   └── naver-api.js
│   └── ui/
│       ├── components.js
│       └── toast.js
└── README.md
```

---

## 다음 단계

1. [x] 디스크 정리 완료 (86% → 62%)
2. [x] Phase 1 MVP 구현 완료
3. [ ] 네이버 API 키 발급 테스트
4. [x] Phase 2 핵심 기능 구현 (07-phase2-implementation-plan.md 참조)
   - [x] 예약 포스팅 (scheduler.js, notification.js, schedule.js)
   - [x] 대량 생성 (batch-generator.js, batch.js)
   - [x] SEO 분석 고도화 (seo-analyzer.js)
   - [x] 사용량 통계 대시보드 (usage-tracker.js, stats.js)
5. [x] 고도화 기능 구현 (08-enhancement-features.md 참조)
   - [x] 이미지 업로드 (image-uploader.js, image-upload-zone.js)
   - [x] 템플릿 시스템 (template-manager.js)
   - [x] 콘텐츠 이미지 삽입 (content-image-manager.js)
6. [ ] Phase 3 부가 기능
   - [ ] PWA 오프라인 모드
   - [ ] 시리즈 관리

---

## 참고 링크

- [Naver Blog XMLRPC API](https://github.com/yousung/naver-blog-xmlrpc)
- [Naver Open API](https://naver.github.io/naver-openapi-guide/apilist.html)
- [Groq API](https://console.groq.com)
- [OpenAI API](https://platform.openai.com)
- [Anthropic API](https://console.anthropic.com)
- [Stability AI](https://platform.stability.ai)

---

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-01-07 | 초안 작성, 전체 문서 구조화 |
| 2026-01-07 | 디스크 상태 업데이트 (62%), Claude Opus 4.5 추가, 06-advanced-features.md 문서 추가 |
| 2026-01-09 | 07-phase2-implementation-plan.md 추가 (미구현 기능 상세 계획) |
| 2026-01-09 | 08-enhancement-features.md 추가 (고도화 및 편의성 개선 설계) |
| 2026-01-09 | 문서 검수 및 수정: notification.js 모듈 추가, 에디터 인터페이스 정의, 유틸리티 함수 추가, nginx 프록시 대안, EXIF 처리 명시 |
| 2026-01-10 | Phase 2 구현 완료: 예약 포스팅, 대량 생성, SEO 분석 고도화, 사용량 통계 대시보드 |
| 2026-01-10 | 고도화 기능 구현 완료: 이미지 업로드, 템플릿 시스템, 콘텐츠 이미지 삽입 |
| 2026-01-10 | 09-troubleshooting.md 추가: 403 에러 해결 (파일 권한 문제), 배포 체크리스트 |
| 2026-01-10 | 10-ui-ux-improvements.md 추가: 레이아웃 개선, LLM 설정 분리, 모바일 네비게이션, 보안 UX |
