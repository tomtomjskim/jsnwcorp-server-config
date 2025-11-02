# 로또 최신 회차 심층 통계 분석 기능 설계서

**작성일**: 2025-11-02
**버전**: 1.0
**상태**: 설계 완료
**프로젝트**: LottoMaster v0.4.0

---

## 📋 목차

1. [개요](#개요)
2. [현재 시스템 분석](#현재-시스템-분석)
3. [신규 기능 요구사항](#신규-기능-요구사항)
4. [통계 분석 항목](#통계-분석-항목)
5. [기술 설계](#기술-설계)
6. [데이터베이스 설계](#데이터베이스-설계)
7. [API 설계](#api-설계)
8. [UI/UX 설계](#uiux-설계)
9. [구현 우선순위](#구현-우선순위)
10. [예상 결과물](#예상-결과물)

---

## 개요

### 목적
최신 추첨 회차의 당첨 번호를 전체 역사적 데이터와 비교하여, 통계적 관점에서 얼마나 "정상적"이거나 "특이한" 회차였는지 심층 분석하는 기능을 제공합니다.

### 핵심 가치
- **통계적 근거 제공**: 단순 당첨 번호 나열이 아닌, 통계적 의미 부여
- **사용자 교육**: 로또의 무작위성과 확률 이론 이해 증진
- **재미 요소**: "이번 회차가 얼마나 특별했는가?" 호기심 충족
- **데이터 인사이트**: 패턴, 편향, 이상치 발견

### 타겟 사용자
- 로또 구매자 (호기심 충족)
- 통계 애호가 (데이터 분석)
- 연구자 (확률 이론 검증)

---

## 현재 시스템 분석

### 기존 통계 기능
1. **번호별 출현 빈도**: 전체 회차 기준 각 번호의 총 출현 횟수
2. **홀짝 비율**: 전체 당첨 번호 중 홀수/짝수 비율
3. **고저 비율**: 1-22(저) vs 23-45(고) 비율
4. **구간별 분포**: 1-10, 11-20, 21-30, 31-40, 41-45 구간별 출현 횟수
5. **빈출/저빈출 번호**: TOP 10 / BOTTOM 10
6. **콜드 넘버**: 최근 미출현 번호
7. **핫 넘버**: 최근 출현 번호

### 데이터 소스
- **PostgreSQL**: `lotto.draws` 테이블 (1,196회차 데이터)
- **컬럼**: `draw_no`, `draw_date`, `num1-num6`, `bonus_num`, `first_win_amount`, `first_win_count`
- **전체 평균값**:
  - 평균 당첨 번호: **23.0**
  - 평균 홀수 비율: **51.2%**

### 현재 시스템의 한계
❌ **최신 회차에 대한 심층 분석 부재**
- 최신 회차 번호 표시만 있을 뿐, 해당 회차가 통계적으로 어떤 의미를 갖는지 분석 없음
- 이론적 기대값과의 비교 없음
- 이전 회차들과의 패턴 비교 없음
- 확률적 희귀도 계산 없음

---

## 신규 기능 요구사항

### 기능 개요
**"최신 회차 당첨번호 심층 분석 대시보드"**

사용자가 최신 추첨 결과를 보고 다음 질문에 대한 답을 얻을 수 있어야 함:
1. ✅ 이번 회차 번호들은 평균적으로 높은 편인가, 낮은 편인가?
2. ✅ 홀짝 비율이 균형있는가, 아니면 편향되었는가?
3. ✅ 고저 분포가 이론값에 근접한가?
4. ✅ 구간별 분포가 골고루 분산되었는가, 한쪽으로 몰렸는가?
5. ✅ 연속 번호가 있는가? (예: 12, 13, 14)
6. ✅ 이 회차 번호 조합이 역대 몇 번째로 "희귀"한가?
7. ✅ 각 번호가 전체 출현 빈도 기준 "빈출"인가 "저빈출"인가?
8. ✅ 이전 회차와 겹치는 번호가 몇 개인가? (반복성 분석)
9. ✅ 보너스 번호의 통계적 의미는?
10. ✅ 이 조합의 "이론적 출현 확률"은 얼마인가?

### 비기능 요구사항
- **성능**: API 응답 시간 < 500ms
- **캐싱**: 최신 회차는 자주 조회되므로 5분 캐시
- **확장성**: 향후 과거 회차 분석으로 확장 가능한 구조
- **접근성**: 통계 비전문가도 이해 가능한 설명 제공

---

## 통계 분석 항목

### 1. 기본 통계 (Basic Statistics)

#### 1.1 번호 평균 (Average Number)
```typescript
const avg = (num1 + num2 + num3 + num4 + num5 + num6) / 6
```
- **기대값**: 23.0 (1~45의 중앙값)
- **정상 범위**: 20~26 (±3 표준편차 내)
- **해석**:
  - `avg < 20`: 저번호 집중
  - `20 ≤ avg ≤ 26`: 정상 분포
  - `avg > 26`: 고번호 집중

#### 1.2 번호 합계 (Sum of Numbers)
```typescript
const sum = num1 + num2 + num3 + num4 + num5 + num6
```
- **기대값**: 138 (23 × 6)
- **정상 범위**: 120~156
- **해석**: 합계가 클수록 큰 번호들이 많이 선택됨

#### 1.3 표준편차 (Standard Deviation)
```typescript
const stdDev = Math.sqrt(
  numbers.reduce((sum, n) => sum + Math.pow(n - avg, 2), 0) / numbers.length
)
```
- **기대값**: 약 13~15
- **해석**:
  - 낮은 표준편차: 번호들이 밀집 (예: 20,21,22,23,24,25)
  - 높은 표준편차: 번호들이 분산 (예: 1,10,20,30,40,45)

#### 1.4 범위 (Range)
```typescript
const range = Math.max(...numbers) - Math.min(...numbers)
```
- **최대 범위**: 44 (1~45)
- **정상 범위**: 25~40
- **해석**: 범위가 클수록 번호 분산도가 높음

---

### 2. 분포 분석 (Distribution Analysis)

#### 2.1 홀짝 비율 (Odd/Even Ratio)
```typescript
const oddCount = numbers.filter(n => n % 2 === 1).length
const evenCount = 6 - oddCount
```
- **이론적 확률**: 50% / 50%
- **실제 기대값**: 3:3 (51.2% : 48.8% 역대 평균)
- **분포**:
  - `6:0` 또는 `0:6`: 극히 드묾 (0.8% 확률)
  - `5:1` 또는 `1:5`: 드묾 (9.4% 확률)
  - `4:2` 또는 `2:4`: 보통 (46.9% 확률)
  - `3:3`: 가장 흔함 (42.9% 확률)

#### 2.2 고저 비율 (High/Low Ratio)
- **저번호**: 1~22 (22개)
- **고번호**: 23~45 (23개)
- **이론적 확률**: 약 49% / 51%
- **정상 분포**: 2~4개 저번호, 2~4개 고번호

#### 2.3 구간별 분포 (Range Distribution)
```typescript
const ranges = {
  '1-10': numbers.filter(n => n >= 1 && n <= 10).length,
  '11-20': numbers.filter(n => n >= 11 && n <= 20).length,
  '21-30': numbers.filter(n => n >= 21 && n <= 30).length,
  '31-40': numbers.filter(n => n >= 31 && n <= 40).length,
  '41-45': numbers.filter(n => n >= 41 && n <= 45).length,
}
```
- **이론적 기대값** (각 구간 포함 확률):
  - 1-10: 1.33개 (10/45 × 6)
  - 11-20: 1.33개
  - 21-30: 1.33개
  - 31-40: 1.33개
  - 41-45: 0.67개 (5/45 × 6)
- **정상 범위**: 각 구간 0~3개
- **이상치**: 한 구간에 4개 이상 집중

---

### 3. 패턴 분석 (Pattern Analysis)

#### 3.1 연속 번호 (Consecutive Numbers)
```typescript
function findConsecutive(numbers: number[]): number[][] {
  const sorted = [...numbers].sort((a, b) => a - b)
  const consecutive = []
  let current = [sorted[0]]

  for (let i = 1; i < sorted.length; i++) {
    if (sorted[i] === sorted[i-1] + 1) {
      current.push(sorted[i])
    } else {
      if (current.length >= 2) consecutive.push([...current])
      current = [sorted[i]]
    }
  }

  if (current.length >= 2) consecutive.push(current)
  return consecutive
}
```
- **역대 통계**:
  - 연속 번호 없음: 30%
  - 2개 연속: 50%
  - 3개 연속: 18%
  - 4개 이상 연속: 2% (희귀)

#### 3.2 등차수열 패턴 (Arithmetic Sequence)
```typescript
// 예: 5, 10, 15, 20, 25, 30 (공차 5)
function findArithmeticSequence(numbers: number[]): { found: boolean, diff: number } {
  const sorted = [...numbers].sort((a, b) => a - b)
  const diffs = []
  for (let i = 1; i < sorted.length; i++) {
    diffs.push(sorted[i] - sorted[i-1])
  }
  const allSame = diffs.every(d => d === diffs[0])
  return { found: allSame, diff: allSame ? diffs[0] : 0 }
}
```
- **의미**: 극히 희귀한 패턴 (0.001% 미만)

#### 3.3 배수 패턴 (Multiple Pattern)
```typescript
// 특정 숫자의 배수만 나온 경우
function checkMultiplePattern(numbers: number[], base: number): boolean {
  return numbers.every(n => n % base === 0)
}
```
- **예시**: 모두 3의 배수 (3, 6, 9, 12, 15, 18)
- **확률**: 매우 낮음

---

### 4. 비교 분석 (Comparative Analysis)

#### 4.1 역대 빈도 기준 분류
```typescript
const stats = await calculateNumberStats() // 전체 역대 통계
const classification = numbers.map(num => {
  const stat = stats.find(s => s.number === num)
  const avgCount = totalDraws * 6 / 45 // 기대 출현 횟수
  const deviation = ((stat.totalCount - avgCount) / avgCount) * 100

  return {
    number: num,
    totalCount: stat.totalCount,
    rank: getRank(stat.totalCount, stats), // 1~45 순위
    category: deviation > 10 ? '빈출' : deviation < -10 ? '저빈출' : '평균',
    deviation: deviation.toFixed(1) + '%'
  }
})
```

#### 4.2 이전 회차와의 반복성
```typescript
const prevDraw = await getDrawByNumber(latestDrawNo - 1)
const repeatedNumbers = numbers.filter(n => prevDraw.numbers.includes(n))
const repeatCount = repeatedNumbers.length
```
- **역대 평균**: 1.2개 반복
- **정상 범위**: 0~3개
- **해석**:
  - 0개 반복: 완전 새로운 조합 (20%)
  - 1~2개 반복: 정상 (60%)
  - 3개 이상 반복: 높은 반복성 (20%)

#### 4.3 최근 10회차 트렌드 비교
```typescript
const recent10 = await getRecentDraws(10)
const recent10Stats = {
  avgSum: recent10.reduce((sum, d) => sum + d.numbers.reduce((a,b) => a+b, 0), 0) / 10,
  avgOddCount: recent10.reduce((sum, d) => sum + d.numbers.filter(n => n % 2 === 1).length, 0) / 10,
  // ... 기타 통계
}

const currentVsRecent = {
  sumDiff: currentSum - recent10Stats.avgSum,
  oddCountDiff: currentOddCount - recent10Stats.avgOddCount,
  // ...
}
```

---

### 5. 희귀도 분석 (Rarity Analysis)

#### 5.1 조합 희귀도 점수 (Rarity Score)
다음 요소들을 종합하여 0~100점 산출:

```typescript
function calculateRarityScore(draw: Draw, historicalStats: Stats): number {
  let score = 50 // 기본 점수 (보통)

  // 1. 번호 평균 편차 (±10점)
  const avgDeviation = Math.abs(draw.avg - 23) / 23 * 100
  score += avgDeviation > 15 ? 10 : avgDeviation > 10 ? 5 : 0

  // 2. 홀짝 비율 극단성 (±10점)
  if (draw.oddCount === 6 || draw.oddCount === 0) score += 15
  else if (draw.oddCount === 5 || draw.oddCount === 1) score += 10
  else if (draw.oddCount === 3) score -= 5

  // 3. 연속 번호 (±15점)
  const maxConsecutive = findMaxConsecutiveLength(draw.numbers)
  if (maxConsecutive >= 4) score += 15
  else if (maxConsecutive === 3) score += 10
  else if (maxConsecutive === 2) score += 3

  // 4. 등차수열 패턴 (±20점)
  if (isArithmeticSequence(draw.numbers)) score += 20

  // 5. 표준편차 (±10점)
  const stdDevDeviation = Math.abs(draw.stdDev - 14) / 14 * 100
  score += stdDevDeviation > 30 ? 10 : stdDevDeviation > 20 ? 5 : 0

  // 6. 빈출 번호 집중도 (±10점)
  const topFrequentNumbers = getTopFrequent(historicalStats, 10)
  const topFreqCount = draw.numbers.filter(n => topFrequentNumbers.includes(n)).length
  if (topFreqCount >= 5) score += 10
  else if (topFreqCount <= 1) score += 10

  return Math.max(0, Math.min(100, score))
}
```

**희귀도 등급**:
- `0-30`: 매우 평범 (Very Common)
- `31-50`: 평범 (Common)
- `51-70`: 특이함 (Unusual)
- `71-85`: 희귀 (Rare)
- `86-100`: 극히 희귀 (Very Rare)

#### 5.2 역대 유사 회차 찾기
```typescript
function findSimilarDraws(targetDraw: Draw, allDraws: Draw[], limit: number = 5) {
  return allDraws
    .map(draw => ({
      drawNo: draw.drawNo,
      similarity: calculateSimilarity(targetDraw, draw),
      matchingNumbers: targetDraw.numbers.filter(n => draw.numbers.includes(n)).length
    }))
    .sort((a, b) => b.similarity - a.similarity)
    .slice(0, limit)
}

function calculateSimilarity(draw1: Draw, draw2: Draw): number {
  const factors = {
    avgDiff: 1 - Math.abs(draw1.avg - draw2.avg) / 45,
    sumDiff: 1 - Math.abs(draw1.sum - draw2.sum) / 270,
    oddCountSame: draw1.oddCount === draw2.oddCount ? 1 : 0,
    matchingNumbers: draw1.numbers.filter(n => draw2.numbers.includes(n)).length / 6,
  }

  return (factors.avgDiff * 0.2 + factors.sumDiff * 0.2 +
          factors.oddCountSame * 0.3 + factors.matchingNumbers * 0.3) * 100
}
```

---

### 6. 확률 이론 (Probability Theory)

#### 6.1 조합 출현 확률
```typescript
// 특정 6개 번호 조합이 나올 확률
const totalCombinations = combination(45, 6) // 8,145,060
const singleCombinationProb = 1 / totalCombinations // 0.0000001228

// 퍼센트 표기
const probPercent = (singleCombinationProb * 100).toExponential(2)
// "1.23e-5%" (약 0.0000123%)
```

#### 6.2 특정 패턴 출현 확률
```typescript
// 예: 홀수 6개가 나올 확률
const oddNumbers = 23 // 1~45 중 홀수 개수
const evenNumbers = 22
const allOddProb = combination(oddNumbers, 6) / combination(45, 6)
// 약 0.8%

// 예: 3연속 번호가 포함될 확률
const consecutiveTripletProb = estimateConsecutiveProbability()
// 약 18%
```

#### 6.3 기대값 대비 편차
```typescript
const expectedOddCount = 6 * (23 / 45) // 약 3.07개
const actualOddCount = draw.oddCount
const deviation = actualOddCount - expectedOddCount
const zScore = deviation / Math.sqrt(6 * (23/45) * (22/45)) // 표준정규분포 변환
```

---

## 기술 설계

### 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                    Frontend (Next.js)                    │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Latest Draw Analysis Page                         │ │
│  │  /statistics/latest                                │ │
│  │  - 최신 회차 번호 표시                              │ │
│  │  - 통계 카드 (평균, 합계, 홀짝 등)                │ │
│  │  - 희귀도 점수 게이지                              │ │
│  │  - 패턴 분석 시각화                                │ │
│  │  - 유사 회차 목록                                   │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                          ↓ API Call
┌─────────────────────────────────────────────────────────┐
│              API Route (Next.js Server)                  │
│  ┌────────────────────────────────────────────────────┐ │
│  │  /api/stats/latest-draw-analysis                   │ │
│  │  GET: 최신 회차 심층 분석 데이터 반환             │ │
│  └────────────────────────────────────────────────────┘ │
│                          ↓                               │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Analysis Service                                  │ │
│  │  - calculateBasicStats()                           │ │
│  │  - calculateDistribution()                         │ │
│  │  │  - calculatePatterns()                            │ │
│  │  - calculateRarityScore()                          │ │
│  │  - findSimilarDraws()                              │ │
│  │  - compareWithHistory()                            │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                          ↓ Query
┌─────────────────────────────────────────────────────────┐
│                  PostgreSQL Database                     │
│  ┌────────────────────────────────────────────────────┐ │
│  │  lotto.draws                                       │ │
│  │  - 최신 회차 데이터 조회                          │ │
│  │  - 전체 역대 통계 계산                            │ │
│  │  - 유사 회차 검색                                  │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### 기술 스택
- **Frontend**: React, TypeScript, Recharts, TailwindCSS
- **Backend**: Next.js API Routes, TypeScript
- **Database**: PostgreSQL 15
- **Cache**: Next.js Revalidate (5분)
- **Deployment**: Docker

---

## 데이터베이스 설계

### 기존 테이블 활용
```sql
-- lotto.draws (이미 존재)
-- draw_no, draw_date, num1~num6, bonus_num, first_win_amount, first_win_count
```

### 신규 뷰 생성 (선택사항)
```sql
-- 회차별 기본 통계 미리 계산 (성능 최적화)
CREATE MATERIALIZED VIEW lotto.draw_statistics AS
SELECT
  draw_no,
  draw_date,
  (num1 + num2 + num3 + num4 + num5 + num6) / 6.0 AS avg_number,
  (num1 + num2 + num3 + num4 + num5 + num6) AS sum_number,
  GREATEST(num1, num2, num3, num4, num5, num6) - LEAST(num1, num2, num3, num4, num5, num6) AS range_number,
  (CASE WHEN num1 % 2 = 1 THEN 1 ELSE 0 END +
   CASE WHEN num2 % 2 = 1 THEN 1 ELSE 0 END +
   CASE WHEN num3 % 2 = 1 THEN 1 ELSE 0 END +
   CASE WHEN num4 % 2 = 1 THEN 1 ELSE 0 END +
   CASE WHEN num5 % 2 = 1 THEN 1 ELSE 0 END +
   CASE WHEN num6 % 2 = 1 THEN 1 ELSE 0 END) AS odd_count,
  (CASE WHEN num1 <= 22 THEN 1 ELSE 0 END +
   CASE WHEN num2 <= 22 THEN 1 ELSE 0 END +
   CASE WHEN num3 <= 22 THEN 1 ELSE 0 END +
   CASE WHEN num4 <= 22 THEN 1 ELSE 0 END +
   CASE WHEN num5 <= 22 THEN 1 ELSE 0 END +
   CASE WHEN num6 <= 22 THEN 1 ELSE 0 END) AS low_count,
  created_at
FROM lotto.draws
ORDER BY draw_no DESC;

CREATE INDEX idx_draw_statistics_draw_no ON lotto.draw_statistics(draw_no);

-- 매일 새벽 3시 30분에 자동 갱신 (크론 작업과 연동)
-- Refresh after new data collection
```

### 신규 분석 캐시 테이블 (선택사항)
```sql
CREATE TABLE IF NOT EXISTS lotto.draw_analysis_cache (
  draw_no INTEGER PRIMARY KEY REFERENCES lotto.draws(draw_no),
  analysis_data JSONB NOT NULL, -- 전체 분석 결과 JSON
  rarity_score DECIMAL(5,2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_draw_analysis_rarity ON lotto.draw_analysis_cache(rarity_score DESC);
```

---

## API 설계

### 엔드포인트: `GET /api/stats/latest-draw-analysis`

#### Request
```
GET /api/stats/latest-draw-analysis
```

#### Response
```json
{
  "success": true,
  "data": {
    "drawInfo": {
      "drawNo": 1196,
      "drawDate": "2025-11-01",
      "numbers": [8, 12, 15, 29, 40, 45],
      "bonusNum": 14,
      "firstWinAmount": 2345678900,
      "firstWinCount": 12
    },
    "basicStats": {
      "average": 24.83,
      "sum": 149,
      "range": 37,
      "median": 22,
      "standardDeviation": 14.52,
      "variance": 210.97
    },
    "distribution": {
      "oddEven": {
        "odd": 4,
        "even": 2,
        "ratio": "67:33",
        "expected": "51:49",
        "deviation": "+16%"
      },
      "highLow": {
        "low": 3,
        "high": 3,
        "ratio": "50:50",
        "expected": "49:51",
        "deviation": "+1%"
      },
      "ranges": {
        "1-10": 1,
        "11-20": 2,
        "21-30": 1,
        "31-40": 1,
        "41-45": 1
      }
    },
    "patterns": {
      "consecutive": {
        "found": true,
        "sequences": [[12]],
        "maxLength": 1,
        "message": "연속 번호 없음"
      },
      "arithmeticSequence": {
        "found": false,
        "difference": null
      },
      "repeatedFromPrev": {
        "count": 2,
        "numbers": [15, 29],
        "prevDrawNo": 1195
      }
    },
    "frequencyAnalysis": {
      "numbers": [
        {
          "number": 8,
          "totalCount": 245,
          "rank": 12,
          "category": "평균",
          "percentile": 73,
          "deviation": "+2.1%",
          "lastDrawNo": 1196,
          "gapDraws": 0
        },
        // ... 나머지 5개 번호
      ],
      "summary": {
        "topFrequentCount": 2,
        "leastFrequentCount": 1,
        "averageCount": 3
      }
    },
    "rarityAnalysis": {
      "score": 58,
      "grade": "특이함",
      "rank": 342,
      "percentile": 71.4,
      "message": "이번 회차는 역대 1,196회차 중 상위 28.6%에 해당하는 특이한 조합입니다.",
      "factors": [
        {
          "factor": "홀짝 비율",
          "impact": "+10",
          "reason": "홀수 4개로 이론값(3개)보다 많음"
        },
        {
          "factor": "고번호 집중",
          "impact": "+8",
          "reason": "40, 45 등 고번호가 2개 포함"
        },
        {
          "factor": "이전 회차 반복",
          "impact": "+5",
          "reason": "2개 번호 반복 (평균 1.2개)"
        }
      ]
    },
    "similarDraws": [
      {
        "drawNo": 1023,
        "drawDate": "2023-05-13",
        "numbers": [7, 14, 18, 31, 38, 44],
        "similarity": 87.5,
        "matchingNumbers": 0,
        "reasons": ["유사한 평균값", "유사한 홀짝 비율", "유사한 분산도"]
      },
      // ... 4개 더
    ],
    "comparison": {
      "vsTheoretical": {
        "average": {
          "theoretical": 23.0,
          "actual": 24.83,
          "deviation": "+7.9%"
        },
        "oddCount": {
          "theoretical": 3.07,
          "actual": 4,
          "deviation": "+30.3%"
        }
      },
      "vsHistorical": {
        "avgOfAllDraws": 23.0,
        "thisDrawDiff": "+1.83",
        "percentile": 68.2
      },
      "vsRecent10": {
        "avgOfRecent10": 22.5,
        "thisDrawDiff": "+2.33",
        "trend": "상승"
      }
    },
    "probability": {
      "exactCombination": "0.0000123%",
      "exactCombinationOdds": "1 in 8,145,060",
      "oddEvenPattern": "23.4%",
      "highLowPattern": "31.2%",
      "estimatedOverallRarity": "0.05%"
    },
    "insights": [
      "✨ 이번 회차는 홀수가 4개로, 이론적 기대값(3개)보다 많습니다.",
      "📊 평균 번호(24.83)가 전체 평균(23.0)보다 높아 고번호 쪽으로 약간 치우쳤습니다.",
      "🔁 이전 회차와 2개 번호가 겹쳐 평균(1.2개)보다 반복성이 높습니다.",
      "🎯 희귀도 점수 58점으로 '특이함' 등급이며, 역대 상위 28.6%에 해당합니다."
    ]
  },
  "meta": {
    "totalDraws": 1196,
    "calculationTime": "245ms",
    "cachedUntil": "2025-11-02T10:05:00Z"
  }
}
```

---

## UI/UX 설계

### 페이지 구조: `/statistics/latest`

#### 1. Hero Section - 최신 회차 당첨 번호
```
┌─────────────────────────────────────────────────────────┐
│  🎰 최신 회차 심층 분석                                 │
│                                                          │
│  제 1196회 │ 2025-11-01 추첨                            │
│                                                          │
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐    보너스 ┌──┐         │
│  │08│ │12│ │15│ │29│ │40│ │45│           │14│         │
│  └──┘ └──┘ └──┘ └──┘ └──┘ └──┘           └──┘         │
│                                                          │
│  희귀도 점수: 58/100 ⭐⭐⭐ (특이함)                    │
│  [====================58%===========---------]          │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

#### 2. Stats Cards - 기본 통계
```
┌──────────────┬──────────────┬──────────────┬─────────────┐
│  평균 번호   │   번호 합계   │   표준편차   │   범위      │
│              │              │              │             │
│    24.83     │     149      │    14.52     │    37       │
│   (기대: 23) │  (기대: 138) │  (기대: 14)  │ (1~45 차)   │
│              │              │              │             │
│   ▲ +7.9%    │   ▲ +8.0%    │   ▲ +3.7%    │   정상      │
└──────────────┴──────────────┴──────────────┴─────────────┘
```

#### 3. Distribution Analysis - 분포 분석
```
┌─────────────────────────────────────────────────────────┐
│  📊 분포 분석                                            │
│                                                          │
│  ┌─ 홀짝 비율 ─────────────────────────────────────┐   │
│  │  홀수: 4개 (67%)  ████████████████░░░░░░░        │   │
│  │  짝수: 2개 (33%)  ████████░░░░░░░░░░░░░░░░        │   │
│  │  기대값: 3:3 (51:49)                              │   │
│  │  편차: +16% ⚠️ (평균보다 홀수 많음)               │   │
│  └───────────────────────────────────────────────────┘   │
│                                                          │
│  ┌─ 고저 비율 ─────────────────────────────────────┐   │
│  │  저번호(1-22): 3개 (50%)  ████████████           │   │
│  │  고번호(23-45): 3개 (50%)  ████████████          │   │
│  │  기대값: 2.9:3.1 (49:51)                         │   │
│  │  편차: +1% ✅ (거의 이론값에 근접)               │   │
│  └───────────────────────────────────────────────────┘   │
│                                                          │
│  ┌─ 구간별 분포 ──────────────────────────────────┐   │
│  │  1-10:   1개 │██                               │   │
│  │  11-20:  2개 │████                             │   │
│  │  21-30:  1개 │██                               │   │
│  │  31-40:  1개 │██                               │   │
│  │  41-45:  1개 │██                               │   │
│  │  ✅ 골고루 분산됨                                │   │
│  └───────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

#### 4. Pattern Analysis - 패턴 분석
```
┌─────────────────────────────────────────────────────────┐
│  🔍 패턴 분석                                            │
│                                                          │
│  ⛓️ 연속 번호:  없음                                     │
│     정상 (70%의 회차에서 연속 번호 없음)                │
│                                                          │
│  🔁 이전 회차 반복: 2개 (15, 29)                        │
│     평균보다 높음 (평균: 1.2개)                         │
│                                                          │
│  📐 등차수열: 없음                                       │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

#### 5. Frequency Breakdown - 번호별 빈도 분석
```
┌─────────────────────────────────────────────────────────┐
│  🎯 번호별 출현 빈도 분석                                │
│                                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │  08 │ 245회 │ 순위 12위 │ 평균 │ 상위 73%      │   │
│  │     빈도 역대 평균에 근접                        │   │
│  ├─────────────────────────────────────────────────┤   │
│  │  12 │ 198회 │ 순위 38위 │ 저빈출 │ 하위 15%   │   │
│  │     🧊 콜드 넘버 - 출현 빈도 낮음                │   │
│  ├─────────────────────────────────────────────────┤   │
│  │  15 │ 272회 │ 순위 3위 │ 빈출 │ 상위 93%      │   │
│  │     🔥 핫 넘버 - 역대 최다 출현                  │   │
│  ├─────────────────────────────────────────────────┤   │
│  │  ...                                            │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│  요약: 빈출 2개, 평균 3개, 저빈출 1개                   │
└─────────────────────────────────────────────────────────┘
```

#### 6. Rarity Analysis - 희귀도 분석
```
┌─────────────────────────────────────────────────────────┐
│  ⭐ 희귀도 분석                                           │
│                                                          │
│  종합 점수: 58/100 (특이함)                              │
│  [====================58%===========---------]          │
│                                                          │
│  역대 순위: 342위 / 1,196회차 (상위 28.6%)               │
│                                                          │
│  점수 구성 요소:                                         │
│  ┌───────────────────────────────────────────────┐     │
│  │ ✓ 홀짝 비율 편향        +10점                 │     │
│  │   (홀수 4개, 이론값 3개)                       │     │
│  ├───────────────────────────────────────────────┤     │
│  │ ✓ 고번호 집중           +8점                  │     │
│  │   (40, 45 포함)                               │     │
│  ├───────────────────────────────────────────────┤     │
│  │ ✓ 이전 회차 높은 반복   +5점                  │     │
│  │   (2개 반복, 평균 1.2개)                       │     │
│  └───────────────────────────────────────────────┘     │
│                                                          │
│  💬 "이번 회차는 평균적인 조합보다 특이한 패턴을         │
│      보이는 회차입니다. 홀수가 많고, 고번호 쪽으로       │
│      약간 치우쳤으며, 이전 회차와의 반복성도 높습니다."  │
└─────────────────────────────────────────────────────────┘
```

#### 7. Similar Draws - 유사 회차
```
┌─────────────────────────────────────────────────────────┐
│  🔗 역대 유사 회차 TOP 5                                 │
│                                                          │
│  1. 제1023회 (2023-05-13)  유사도 87.5%                  │
│     07 14 18 31 38 44                                    │
│     ▸ 유사한 평균값, 홀짝 비율                           │
│                                                          │
│  2. 제897회 (2020-10-24)  유사도 82.3%                   │
│     10 13 19 27 39 42                                    │
│     ▸ 유사한 구간 분포, 표준편차                         │
│                                                          │
│  ...                                                     │
└─────────────────────────────────────────────────────────┘
```

#### 8. Insights - AI 인사이트
```
┌─────────────────────────────────────────────────────────┐
│  💡 주요 인사이트                                         │
│                                                          │
│  ✨ 이번 회차는 홀수가 4개로, 이론적 기대값(3개)보다     │
│     많습니다.                                            │
│                                                          │
│  📊 평균 번호(24.83)가 전체 평균(23.0)보다 높아 고번호   │
│     쪽으로 약간 치우쳤습니다.                            │
│                                                          │
│  🔁 이전 회차와 2개 번호가 겹쳐 평균(1.2개)보다 반복성이 │
│     높습니다.                                            │
│                                                          │
│  🎯 희귀도 점수 58점으로 '특이함' 등급이며, 역대 상위    │
│     28.6%에 해당합니다.                                  │
│                                                          │
│  📈 최근 10회차 평균(22.5)보다 2.33 높아 상승 트렌드를   │
│     보이고 있습니다.                                     │
└─────────────────────────────────────────────────────────┘
```

---

## 구현 우선순위

### Phase 1: 핵심 분석 (1주)
**목표**: MVP 완성

1. ✅ **기본 통계 계산**
   - 평균, 합계, 범위, 표준편차
   - API 엔드포인트 `/api/stats/latest-draw-analysis`
   - 예상 작업: 3시간

2. ✅ **분포 분석**
   - 홀짝 비율, 고저 비율, 구간별 분포
   - 이론값 대비 편차 계산
   - 예상 작업: 2시간

3. ✅ **패턴 분석**
   - 연속 번호, 이전 회차 반복
   - 예상 작업: 2시간

4. ✅ **빈도 분석**
   - 각 번호의 역대 출현 빈도
   - 빈출/저빈출 분류
   - 예상 작업: 2시간

5. ✅ **UI 구현**
   - 페이지 레이아웃
   - Stats Cards, Distribution Charts
   - 예상 작업: 4시간

**총 예상**: 13시간 (약 2일)

---

### Phase 2: 고급 분석 (1주)
**목표**: 희귀도 및 비교 기능

1. ✅ **희귀도 점수 계산**
   - 다차원 점수 알고리즘
   - 점수 구성 요소 분해
   - 예상 작업: 4시간

2. ✅ **유사 회차 검색**
   - 유사도 알고리즘
   - TOP 5 유사 회차
   - 예상 작업: 3시간

3. ✅ **비교 분석**
   - 이론값 대비, 역대 평균 대비, 최근 10회차 대비
   - 예상 작업: 3시간

4. ✅ **UI 강화**
   - 희귀도 게이지, 유사 회차 카드
   - 예상 작업: 3시간

**총 예상**: 13시간 (약 2일)

---

### Phase 3: 심화 기능 (선택)
**목표**: 확률 이론 및 AI 인사이트

1. ⭐ **확률 계산**
   - 조합 확률, 패턴별 확률
   - 예상 작업: 3시간

2. ⭐ **AI 인사이트 생성**
   - 룰 기반 인사이트 생성
   - 자연어 설명 템플릿
   - 예상 작업: 4시간

3. ⭐ **Materialized View 최적화**
   - DB 성능 개선
   - 예상 작업: 2시간

4. ⭐ **Export 기능**
   - PDF/이미지로 분석 결과 다운로드
   - 예상 작업: 3시간

**총 예상**: 12시간 (약 2일)

---

## 예상 결과물

### 사용자 가치
1. ✅ **교육적 가치**: 로또가 완전 무작위임을 통계적으로 학습
2. ✅ **재미 요소**: "내가 산 번호가 얼마나 희귀한지" 확인
3. ✅ **데이터 인사이트**: 패턴, 트렌드 발견
4. ✅ **신뢰성 향상**: 과학적 근거 기반 서비스

### 기술적 가치
1. ✅ **재사용 가능한 분석 엔진**: 과거 회차 분석으로 확장 가능
2. ✅ **성능 최적화**: Materialized View, 캐싱
3. ✅ **확장성**: 새로운 분석 지표 추가 용이
4. ✅ **코드 품질**: TypeScript, 모듈화, 테스트

### 비즈니스 가치
1. ✅ **차별화**: 타 로또 서비스 대비 심층 분석 제공
2. ✅ **체류 시간 증가**: 흥미로운 통계로 재방문 유도
3. ✅ **공유 가능성**: SNS 공유 기능 추가 시 바이럴 가능성
4. ✅ **프리미엄 기능**: 향후 유료화 가능 (과거 회차 분석, AI 예측 등)

---

## 참고 자료

### 통계 이론
- [Lottery Statistics Theory](https://en.wikipedia.org/wiki/Lottery_mathematics)
- [Combinatorics](https://en.wikipedia.org/wiki/Combination)
- [Chi-squared test](https://en.wikipedia.org/wiki/Chi-squared_test)

### 유사 서비스 벤치마킹
- Lotto.net (해외)
- 로또 당첨 번호 통계 분석 사이트 (국내)

---

## 부록: 샘플 계산

### 예시 회차: 1196회 (2025-11-01)
**당첨 번호**: 8, 12, 15, 29, 40, 45
**보너스 번호**: 14

#### 기본 통계
- 평균: (8+12+15+29+40+45) / 6 = **24.83**
- 합계: **149**
- 범위: 45 - 8 = **37**
- 중앙값: (15 + 29) / 2 = **22**
- 표준편차: **14.52**

#### 분포
- 홀수: 15, 29, 45 (3개) → **50%**
- 짝수: 8, 12, 40 (3개) → **50%**
- 저번호: 8, 12, 15 (3개)
- 고번호: 29, 40, 45 (3개)

#### 구간
- 1-10: 1개 (8)
- 11-20: 2개 (12, 15)
- 21-30: 1개 (29)
- 31-40: 1개 (40)
- 41-45: 1개 (45)

#### 패턴
- 연속 번호: 없음
- 이전 회차 반복: 가정 2개 (15, 29)

#### 희귀도 점수 (가정)
- 기본: 50
- 홀짝 균형: +0 (3:3 이상적)
- 고번호 집중(40, 45): +8
- 반복성: +5
- **총점: 63** (특이함)

---

**문서 버전**: 1.0
**최종 수정**: 2025-11-02
**작성자**: Claude Code (AI Assistant)
**승인 대기중**: 사용자 검토 필요

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
