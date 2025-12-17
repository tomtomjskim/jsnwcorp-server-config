# 로또 최신회차 분석 버그픽스 (2025-12-17)

## 개요

로또 서비스의 "상세분석보기" 기능에서 최신회차가 아닌 과거 회차(1196회)를 분석하는 문제 수정.

## 문제 원인

### 1. 테이블 불일치 버그 (핵심 문제)

| 구분 | 사용 테이블 | 최신 회차 |
|------|------------|----------|
| Cron 수집 스크립트 (`fetch-lotto-data-db.ts`) | `lotto.draws` | 1202회 |
| 분석 API (`latest-draw-analysis/route.ts`) | `lotto.draw_results` | 1196회 |

- Cron은 정상적으로 `lotto.draws` 테이블에 데이터를 수집 중이었음
- 분석 API는 `lotto.draw_results` 테이블을 조회하여 6주 전 데이터를 "최신"으로 분석

### 2. 테이블 컬럼명 불일치

```
lotto.draws:        num1~num6, bonus_num
lotto.draw_results: number1~number6, bonus_number
```

### 3. 분석 로직 개선 필요 사항

- **빈도 분석 summary**: 동률 처리 로직 없음 (알파벳 순서로 잘못된 카테고리 선택)
- **희귀도 등급**: 기본 점수 50점이 "특이함"으로 분류되는 비논리적 설계

## 수정 내용

### 1. 테이블 통합 (lotto.draws 사용)

**수정 파일:**
- `src/app/api/stats/latest-draw-analysis/route.ts`
- `src/lib/analysis/latestDrawAnalysis.ts`

**변경 내용:**
- `lotto.draw_results` → `lotto.draws` 테이블로 변경
- 컬럼명 매핑: `number1~6` → `num1~6`, `bonus_number` → `bonus_num`
- 모든 관련 쿼리 업데이트 (패턴 분석, 빈도 분석, 희귀도, 유사 회차, 비교 분석)

### 2. 빈도 분석 summary 개선

**수정 전:**
```typescript
const dominantCategory = Object.entries(categoryCounts).reduce((a, b) => a[1] > b[1] ? a : b)[0];
const summary = `전체적으로 ${dominantCategory} 번호가 많이 포함되어 있습니다.`;
```

**수정 후:**
```typescript
const highFreqCount = categoryCounts['매우 높음'] + categoryCounts['높음'];
const lowFreqCount = categoryCounts['매우 낮음'] + categoryCounts['낮음'];
const normalCount = categoryCounts['보통'];

let summary: string;
if (highFreqCount >= 4) {
  summary = `역대 빈출 번호가 ${highFreqCount}개로, 자주 나온 번호 위주로 구성되어 있습니다.`;
} else if (lowFreqCount >= 4) {
  summary = `역대 저빈출 번호가 ${lowFreqCount}개로, 드물게 나온 번호 위주로 구성되어 있습니다.`;
} else if (highFreqCount === lowFreqCount && highFreqCount >= 2) {
  summary = `빈출 번호(${highFreqCount}개)와 저빈출 번호(${lowFreqCount}개)가 균형있게 분포되어 있습니다.`;
} else if (normalCount >= 3) {
  summary = `보통 빈도의 번호가 ${normalCount}개로, 평균적인 빈도의 번호 위주입니다.`;
} else {
  summary = `다양한 빈도의 번호가 골고루 포함되어 있습니다.`;
}
```

### 3. 희귀도 등급 기준 조정

**수정 전:**
| 점수 | 등급 |
|------|------|
| 0-29 | 매우 평범 |
| 30-49 | 평범 |
| 50-69 | 특이함 |
| 70-84 | 희귀 |
| 85+ | 극히 희귀 |

**수정 후:**
| 점수 | 등급 |
|------|------|
| 0-24 | 매우 평범 |
| 25-54 | 평범 (기본 점수 50점 포함) |
| 55-74 | 특이함 |
| 75-89 | 희귀 |
| 90+ | 극히 희귀 |

## 수정 결과

### API 응답 비교

| 항목 | 수정 전 | 수정 후 |
|------|---------|---------|
| 최신 회차 | 1196회 (2025-11-01) | **1202회 (2025-12-13)** |
| dataSource | `lotto.draw_results` | `lotto.draws` |
| 빈도 summary | "전체적으로 낮음 번호가..." | "역대 빈출 번호가 4개로..." |
| 희귀도 factors | `[]` | 2개 요인 표시 |

### 1202회차 분석 결과 예시
```json
{
  "drawNo": 1202,
  "drawDate": "2025-12-13",
  "numbers": [5, 12, 21, 33, 37, 40],
  "bonusNumber": 7,
  "rarity": {
    "score": 58,
    "grade": "특이함",
    "factors": [
      {"factor": "홀짝 비율 약간 편향", "impact": 3, "reason": "홀수 4개로 이론값(3개)보다 많음"},
      {"factor": "이전 회차 완전 새로운 조합", "impact": 5, "reason": "이전 회차와 겹치는 번호 없음 (20%)"}
    ]
  },
  "frequency": {
    "summary": "역대 빈출 번호가 4개로, 자주 나온 번호 위주로 구성되어 있습니다."
  }
}
```

## 배포 정보

- **배포 일시**: 2025-12-17 09:24 UTC
- **배포 방법**: `docker compose build lotto-service && docker compose up -d --force-recreate lotto-service`
- **서비스 상태**: healthy

## 참고 사항

### nginx 캐시
- API 응답이 5분간 nginx에 캐시됨
- 브라우저에서 강력 새로고침(Ctrl+Shift+R) 또는 5분 대기 후 최신 데이터 표시
- `Cache-Control: no-cache` 헤더로 캐시 우회 가능

### 테이블 구조 참고
```sql
-- lotto.draws (Cron 수집 대상, 분석 API 사용)
CREATE TABLE lotto.draws (
  draw_no INTEGER PRIMARY KEY,
  draw_date DATE NOT NULL,
  num1~num6 INTEGER NOT NULL,
  bonus_num INTEGER NOT NULL,
  first_win_amount BIGINT,
  first_win_count INTEGER
);

-- lotto.draw_results (레거시, 사용 중단 권장)
CREATE TABLE lotto.draw_results (
  draw_no INTEGER PRIMARY KEY,
  draw_date DATE NOT NULL,
  number1~number6 INTEGER NOT NULL,
  bonus_number INTEGER NOT NULL,
  ...
);
```

### 향후 권장 작업
1. `lotto.draw_results` 테이블 사용처 확인 및 `lotto.draws`로 통합
2. 레거시 테이블 정리 또는 뷰(View)로 대체
3. 테이블 명명 규칙 통일 문서화

## 관련 파일

- `/home/deploy/projects/lotto-master/src/app/api/stats/latest-draw-analysis/route.ts`
- `/home/deploy/projects/lotto-master/src/lib/analysis/latestDrawAnalysis.ts`
- `/home/deploy/projects/lotto-master/scripts/fetch-lotto-data-db.ts`
