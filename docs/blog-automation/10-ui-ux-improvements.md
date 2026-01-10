# Blog Automation - UI/UX 개선 전략

> 작성일: 2026-01-10
> 상태: 기획 중

---

## 목차

1. [현재 문제점 분석](#1-현재-문제점-분석)
2. [개선 전략](#2-개선-전략)
3. [구현 우선순위](#3-구현-우선순위)
4. [상세 설계](#4-상세-설계)

---

## 1. 현재 문제점 분석

### 1.1 LLM 선택 섹션 문제

**현재 상태:**
- 메인 폼에 LLM Provider/Model 선택 UI가 항상 노출
- 화면 공간 낭비
- 자주 변경하지 않는 설정이 매번 표시됨

**문제점:**
- 핵심 기능(주제 입력, 키워드)에 집중도 저하
- 모바일에서 스크롤 증가
- 사용자 경험 복잡성 증가

### 1.2 Collapsible Header 스타일 문제

**현재 상태:**
```css
.collapsible-header {
  /* display: flex 없음 */
}
```

**문제점:**
- 화살표 아이콘과 제목이 수직 분리
- 클릭 영역 불명확
- 시각적 일관성 부족

**예시:**
```
현재:
┌─────────────┐
│ ▼           │  ← 화살표 따로
│ 추가 정보   │  ← 제목 따로
└─────────────┘

기대:
┌─────────────┐
│ ▼ 추가 정보 │  ← 한 줄에 정렬
└─────────────┘
```

### 1.3 보안 설정 UX 부재

**현재 상태:**
- 설정 페이지에 "보안 잠금" 기능 존재
- 최초 비밀번호 설정 UI 없음
- 사용자가 기능 사용법을 모름

**문제점:**
- 기능 발견 어려움
- 온보딩 경험 부재
- 보안 기능 활용도 저하

### 1.4 레이아웃/네비게이션 구조 문제

**현재 상태:**
```
┌─────────────────────────┐
│ page-header (타이틀만)  │
├─────────────────────────┤
│                         │
│   container (콘텐츠)    │
│                         │
└─────────────────────────┘
```

**문제점:**
1. **햄버거 메뉴 없음**: 페이지 간 이동 어려움
2. **모바일 바텀 네비 없음**: 엄지 접근성 저하
3. **컨테이너 구조 단순**: 모던 앱 느낌 부족
4. **Ctrl+K 의존**: 퀵 액션을 알아야만 이동 가능

---

## 2. 개선 전략

### 2.1 LLM 설정 분리

**방안 A: 사이드 패널 (Drawer)**
```
┌────┬──────────────────┐
│    │  메인 콘텐츠     │
│ LLM│                  │
│설정│  (글 생성 폼)    │
│    │                  │
└────┴──────────────────┘
```

- 우측 또는 좌측 슬라이드 패널
- 아이콘 클릭으로 토글
- 모바일: 풀스크린 오버레이

**방안 B: 설정 모달**
```
┌─────────────────────────┐
│ 메인 콘텐츠             │
│         ┌─────────┐     │
│         │ LLM 설정│     │
│         │ 모달    │     │
│         └─────────┘     │
└─────────────────────────┘
```

- 헤더의 설정 아이콘 클릭
- 모달로 LLM 선택
- 선택 후 자동 닫힘

**방안 C: 플로팅 버튼 + 바텀시트**
```
┌─────────────────────────┐
│ 메인 콘텐츠             │
│                     ⚙️  │ ← 플로팅 버튼
├─────────────────────────┤
│ LLM 설정 바텀시트       │
└─────────────────────────┘
```

- 모바일 친화적
- iOS/Android 앱 패턴

**권장**: 방안 B (설정 모달) - 구현 용이, 기존 modal 컴포넌트 활용

### 2.2 Collapsible Header 수정

**CSS 수정:**
```css
.collapsible-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3);
  cursor: pointer;
  padding: var(--space-3) var(--space-4);
  user-select: none;
}

.collapsible-header .collapse-icon {
  transition: transform 0.2s ease;
  flex-shrink: 0;
}

.collapsible-header.collapsed .collapse-icon {
  transform: rotate(-90deg);
}

.collapsible-header:hover {
  background: var(--bg-tertiary);
  border-radius: var(--radius-md);
}
```

### 2.3 보안 설정 온보딩

**최초 접근 시 플로우:**
```
1. 설정 페이지 → 보안 탭 클릭
2. 비밀번호 미설정 감지
3. 온보딩 모달 표시:
   ┌─────────────────────────┐
   │ 🔐 API 키 보호하기      │
   │                         │
   │ 마스터 비밀번호를 설정  │
   │ 하면 API 키가 암호화   │
   │ 되어 안전하게 보관됩니다│
   │                         │
   │ [비밀번호 입력]         │
   │ [비밀번호 확인]         │
   │                         │
   │ [나중에] [설정하기]     │
   └─────────────────────────┘
```

**설정 후 잠금/해제 UI:**
```
┌─────────────────────────┐
│ 🔒 API 키 잠금됨        │
│                         │
│ [비밀번호 입력    ] 🔓  │
│                         │
│ 비밀번호를 입력하면     │
│ API 키가 복호화됩니다   │
└─────────────────────────┘
```

### 2.4 모던 레이아웃 구조

**2.4.1 헤더 개선**

```
PC:
┌─────────────────────────────────────┐
│ ☰  Blog Auto    [홈][생성][통계] ⚙️│
└─────────────────────────────────────┘

Mobile:
┌─────────────────────────────────────┐
│ ☰  Blog Auto                    ⚙️ │
└─────────────────────────────────────┘
```

- 좌측: 햄버거 메뉴 (사이드바 토글)
- 중앙: 로고/앱명
- 우측: 주요 액션 버튼

**2.4.2 사이드바 (Drawer)**

```
┌──────────────┐
│ 📝 새 글     │ ← 주요 기능
│ 📦 대량 생성 │
│ 📅 예약      │
│ 📊 통계      │
├──────────────┤
│ 📚 히스토리  │ ← 데이터
│ 🖼️ 이미지    │
├──────────────┤
│ ⚙️ 설정      │ ← 시스템
│ ❓ 도움말    │
└──────────────┘
```

**2.4.3 모바일 바텀 네비게이션**

```
┌─────────────────────────────────────┐
│                                     │
│           콘텐츠 영역               │
│                                     │
├─────────────────────────────────────┤
│  🏠    📝    ➕    📊    ⚙️        │
│  홈   생성  새글  통계  설정       │
└─────────────────────────────────────┘
```

- 5개 주요 메뉴
- 중앙 FAB 스타일 "새 글" 버튼
- iOS/Android 표준 패턴

**2.4.4 컨테이너 구조 개선**

```
현재:
<div class="container container-md">
  <!-- 단순 래퍼 -->
</div>

개선:
<div class="app-layout">
  <aside class="app-sidebar">...</aside>
  <main class="app-main">
    <header class="app-header">...</header>
    <div class="app-content">...</div>
  </main>
  <nav class="app-bottom-nav">...</nav>
</div>
```

---

## 3. 구현 우선순위

### Phase 1: 즉시 수정 (CSS 버그 수정)

| 작업 | 난이도 | 효과 |
|------|--------|------|
| Collapsible header flex 수정 | ⭐ | 높음 |
| 버튼/카드 hover 효과 개선 | ⭐ | 중간 |

### Phase 2: 단기 개선 (1-2일)

| 작업 | 난이도 | 효과 |
|------|--------|------|
| LLM 설정 모달 분리 | ⭐⭐ | 높음 |
| 보안 설정 온보딩 UI | ⭐⭐ | 중간 |
| 페이지 헤더 개선 | ⭐⭐ | 높음 |

### Phase 3: 중기 개선 (3-5일)

| 작업 | 난이도 | 효과 |
|------|--------|------|
| 사이드바 네비게이션 | ⭐⭐⭐ | 높음 |
| 모바일 바텀 네비 | ⭐⭐⭐ | 높음 |
| 레이아웃 구조 개편 | ⭐⭐⭐⭐ | 매우 높음 |

---

## 4. 상세 설계

### 4.1 LLM 설정 모달 컴포넌트

**파일**: `js/ui/llm-settings-modal.js`

```javascript
export function showLLMSettingsModal(onSave) {
  const content = `
    <div class="llm-settings-modal">
      <div class="provider-selector">
        <label>Provider</label>
        <select id="modal-provider">...</select>
      </div>
      <div class="model-selector">
        <label>Model</label>
        <select id="modal-model">...</select>
      </div>
      <div class="advanced-options">
        <label>Temperature</label>
        <input type="range" ... />
      </div>
    </div>
  `;

  modal.open({
    title: 'LLM 설정',
    content,
    size: 'sm',
    buttons: [
      { text: '취소', action: 'close' },
      { text: '저장', action: onSave, primary: true }
    ]
  });
}
```

**홈 페이지 UI 변경:**
```html
<!-- Before -->
<div class="llm-section">
  <select>...</select>
  <select>...</select>
</div>

<!-- After -->
<div class="llm-indicator">
  <span class="current-model">Claude Sonnet 4</span>
  <button class="btn-icon" onclick="showLLMSettingsModal()">⚙️</button>
</div>
```

### 4.2 앱 레이아웃 구조

**파일**: `css/layout.css`

```css
/* App Shell */
.app-layout {
  display: flex;
  min-height: 100vh;
  min-height: 100dvh; /* 모바일 safe area */
}

/* Sidebar */
.app-sidebar {
  width: 260px;
  background: var(--bg-secondary);
  border-right: 1px solid var(--border-light);
  display: flex;
  flex-direction: column;
  position: fixed;
  height: 100vh;
  z-index: 100;
  transform: translateX(-100%);
  transition: transform 0.3s ease;
}

.app-sidebar.open {
  transform: translateX(0);
}

/* Main Content */
.app-main {
  flex: 1;
  margin-left: 0;
  display: flex;
  flex-direction: column;
}

/* Header */
.app-header {
  height: 60px;
  background: var(--bg-primary);
  border-bottom: 1px solid var(--border-light);
  display: flex;
  align-items: center;
  padding: 0 var(--space-4);
  position: sticky;
  top: 0;
  z-index: 50;
}

.app-header .menu-toggle {
  padding: var(--space-2);
  margin-right: var(--space-3);
}

.app-header .logo {
  font-weight: 700;
  font-size: var(--text-lg);
}

.app-header .nav-links {
  display: flex;
  gap: var(--space-2);
  margin-left: auto;
}

/* Content */
.app-content {
  flex: 1;
  padding: var(--space-6);
  padding-bottom: calc(var(--space-6) + 70px); /* 바텀 네비 공간 */
}

/* Bottom Navigation (Mobile) */
.app-bottom-nav {
  display: none;
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  height: 70px;
  background: var(--bg-primary);
  border-top: 1px solid var(--border-light);
  padding-bottom: env(safe-area-inset-bottom);
  z-index: 100;
}

/* Mobile Styles */
@media (max-width: 768px) {
  .app-header .nav-links {
    display: none;
  }

  .app-bottom-nav {
    display: flex;
    justify-content: space-around;
    align-items: center;
  }

  .app-content {
    padding: var(--space-4);
  }
}

/* Desktop with Sidebar */
@media (min-width: 1024px) {
  .app-sidebar {
    transform: translateX(0);
  }

  .app-main {
    margin-left: 260px;
  }

  .app-header .menu-toggle {
    display: none;
  }
}
```

### 4.3 바텀 네비게이션 컴포넌트

**파일**: `js/ui/bottom-nav.js`

```javascript
export function renderBottomNav() {
  const nav = document.createElement('nav');
  nav.className = 'app-bottom-nav';

  const items = [
    { icon: '🏠', label: '홈', route: 'home' },
    { icon: '📦', label: '대량', route: 'batch' },
    { icon: '➕', label: '새 글', route: 'home', primary: true },
    { icon: '📊', label: '통계', route: 'stats' },
    { icon: '⚙️', label: '설정', route: 'settings' }
  ];

  nav.innerHTML = items.map(item => `
    <a href="#${item.route}"
       class="bottom-nav-item ${item.primary ? 'primary' : ''}">
      <span class="icon">${item.icon}</span>
      <span class="label">${item.label}</span>
    </a>
  `).join('');

  document.body.appendChild(nav);
}
```

**CSS:**
```css
.bottom-nav-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  padding: var(--space-2);
  color: var(--text-tertiary);
  text-decoration: none;
  font-size: var(--text-xs);
  transition: color 0.15s;
}

.bottom-nav-item.active {
  color: var(--primary);
}

.bottom-nav-item .icon {
  font-size: 24px;
}

.bottom-nav-item.primary {
  position: relative;
  top: -15px;
}

.bottom-nav-item.primary .icon {
  width: 56px;
  height: 56px;
  background: var(--primary);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 12px rgba(0, 102, 255, 0.3);
}
```

---

## 5. 참고 디자인

### 모던 SPA 레이아웃 예시

- **Notion**: 사이드바 + 콘텐츠, 깔끔한 구조
- **Linear**: 다크 모드, 키보드 중심 UX
- **Figma**: 플로팅 툴바, 컨텍스트 메뉴
- **Toss**: 바텀 네비, 카드 기반 UI

### 참고 라이브러리

- **Radix UI**: 접근성 좋은 컴포넌트
- **Headless UI**: 스타일 없는 컴포넌트
- **Framer Motion**: 애니메이션

---

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-01-10 | 초기 작성: 문제점 분석, 개선 전략, 상세 설계 |
