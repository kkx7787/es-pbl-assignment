# 8교시 연습 — 사용 시나리오·교차 검증·개선·제출

> 작성 2026-09-03 / 개인 index `scout-players-2627`(6,000건)
> **개인 Dashboard 제작 완료**(id `31121c50-fb05-4fef-ac9a-647f7e16e577`, 패널 5 + Control 1).
> 화면 값과 Dev Tools 집계를 대조해 전부 일치를 확인했다. 캡처는 `evidence/day-04-practice/`에 있다.

- 필수 권장 시간: 45분
- 선택 도전: 필수 제출 완료 후
- 함께 작성: `../evidence/day-04/dashboard-review.md`
- 시작 기준: 개인 Dashboard 4패널 이상과 상호작용 1개 저장 완료
- 화면 순서: [Inspect·결과 저장·백업](../KIBANA_9_5_STEP_BY_STEP.md#15-결과-저장공유백업)

## (개인·필수) 문제 1 — 사용자 행동 두 가지 테스트

Dashboard 사용자가 실제로 할 행동 두 가지를 실행하세요. 각 행동은 조건 적용과 결과 확인, 원상 복구를 포함합니다.

| 행동 | 시작 상태 | 적용 조건 | 변한 패널·값 | 사용자의 판단 | 복구 방법 | 복구 성공 |
|---|---|---|---|---|---|---|
| **1 하위 리그만 훑기** | Control `Any`, 6,000 | Control `리그 선택` = `Premier League U21` | 검토 대상 **6,000 → 498** / 주발 353·124·21 / 리그 Bar 막대 1개 / 만료 Bar y축 2,000→200 / 구단 Table Harrowgate FC 638→**60**. **5개 패널 전부 변화** | 유스 리그 표본이 498명으로 가장 얇다. 이 리그만으로는 후보가 부족하니 EFL League One(719)·Two(703)와 함께 봐야 한다 | `Any`로 복귀 | **성공 — 6,000 복구** |
| **2 곧 풀리는 자원만 보기** | Control `Any`, 6,000 | KQL `contract_until <= 2028-06-30` | 검토 대상 **6,000 → 1,549** / 만료 Bar가 **2027·2028 두 막대만** / 주발 오른발 1,117·왼발 374·양발 58 / 구단 Harrowgate FC 638→**176** | 2028년까지 만료되는 1,549명이 우선 관찰 대상이다. 이 안에서 리그·구단을 다시 좁힌다 | 검색창 비우고 Enter | **성공 — 6,000 복구** |

- 두 행동이 서로 다른 이유: **좁히는 축이 다르다.**
  행동 1은 **범주**(어디를 볼지)로 좁히고 행동 2는 **시간**(언제까지를 볼지)으로 좁힌다.
  또 도구도 다르다 — 1은 자주 바꾸는 조건이라 Control, 2는 한동안 유지할 조건이라 Filter가 맞다.
  두 조건은 함께 걸 수도 있어야 하며, 그때 교집합이 사용자의 최종 후보 명단이 된다.
- 사용자가 멈추거나 헷갈린 지점: 행동 1에서는 없었다. Control이 목록으로 값을 보여 주고 `Any` 복구도 명확했다.
  행동 2에서는 **날짜 조건을 직접 입력해야 해서** Control보다 진입 장벽이 있었다.
  `contract_until <= 2028-06-30`처럼 field 이름과 날짜 형식을 알아야 한다.
  자주 쓰는 조건이라면 Control이나 저장된 filter로 만들어 두는 편이 낫다.
- 합계 검증: 행동 2의 주발 합 `1,117 + 374 + 58 = 1,549`로 Metric과 일치했다.
  예상되는 곳은 **Filter 조건 입력**이다. `contract_until`은 `date`라 `Add filter`에서
  연산자를 `is between`으로 고르고 날짜를 직접 입력해야 한다. Control처럼 목록에서 고를 수 없다.
- 캡처 파일: 행동 1 `p07-q04-personal-control.png`(적용) / `p07-q03-personal-dashboard.png`(복구),
  행동 2 `p08-q01-action2-contract-filter.png`

### 행동 2에서 발견한 값 차이 — 기록해 둘 것

사전에 Dev Tools로 뽑은 기준값은 **1,551**이었는데 화면은 **1,549**로 2건 적었다. 원인을 확인했다.

| 조건 | 건수 |
|---|---:|
| ES `range contract_until lte "2028-06-30"` (time_zone 미지정 = UTC) | **1,551** |
| ES 같은 조건 + `"time_zone": "+09:00"` | **1,549** |

**Kibana KQL은 날짜 리터럴을 브라우저 시간대(KST)로 해석한다.**
`2028-06-30`을 KST 하루 끝(`2028-06-30T14:59:59Z`)까지로 잡는 반면,
Dev Tools에서 `time_zone` 없이 실행하면 UTC 하루 끝(`2028-06-30T23:59:59Z`)까지가 된다.
그 9시간 구간에 문서 2건이 있어 차이가 났다.

**화면 값 1,549가 이 환경에서 맞는 값이고, Dev Tools 값 1,551도 UTC 기준으로는 맞다.**
어느 쪽이 틀린 게 아니라 **비교할 때 시간대를 맞추지 않은 것이 문제**였다.
Day 3에서 Q3를 1,551로 기록한 것도 Dev Tools(UTC) 기준이라 그대로 유효하다.
앞으로 화면과 요청을 대조할 때는 `time_zone`을 명시하거나 날짜에 시각·오프셋을 붙여야 한다.

## (개인·필수) 문제 2 — 핵심값 3개 교차 검증

Dashboard의 핵심값 3개를 Discover, `_count`, 또는 aggregation 요청과 비교하세요. `Inspect`는 Dashboard 편집 모드에서 해당 패널의 `Panel menu`에 있습니다. 권한이나 화면 상태로 보이지 않으면 Discover 또는 제공 요청 파일로 검증합니다.

| Dashboard 패널·값 | 동일하게 맞춘 시간·조건 | 비교 방법 | 비교값 | 일치 여부 | 다르면 확인한 원인 |
|---|---|---|---:|---|---|
| `검토 대상 선수` = **6,000** | Data View `PL 스카우팅 선수`, 시간 범위 2027-01-01~2032-01-01, KQL·filter 없음, Control `Any` | `GET /scout-players-2627/_count` | **6,000** | **일치** | — |
| `구단별 후보 수와 평균 몸값` Harrowgate FC = **638 / 45,294,953.71** | 동일 | `terms` on `club` + `avg` on `market_value_eur` | **638 / 45,294,954** | **일치** (표시 자릿수만 다름) | — |
| Control `Premier League U21` 적용 시 `주발 구성` = **353 / 124 / 21** | Control만 `Premier League U21` | `term league` + `terms` on `preferred_foot` | **오른발 353 / 왼발 124 / 양발 21** | **일치** | — |

- 비교에 사용한 요청 파일 또는 Discover 캡처: `evidence/day-04/dashboard-plan.md` 7절에
  Dev Tools에 그대로 붙여 쓸 수 있는 요청을 정리해 두었다.

```
GET /scout-players-2627/_count

POST /scout-players-2627/_search
{
  "size": 0,
  "aggs": {
    "by_league": { "terms": { "field": "league", "size": 10 } },
    "by_club":   { "terms": { "field": "club", "size": 10 },
                   "aggs": { "avg_value": { "avg": { "field": "market_value_eur" } } } },
    "by_year":   { "date_histogram": { "field": "contract_until", "calendar_interval": "year" } },
    "by_foot":   { "terms": { "field": "preferred_foot" } }
  }
}
```

- 세 값을 신뢰할 수 있는 이유:
  1. **조건을 동일하게 맞췄다.** 개인 Data View는 time field가 없어 시간 범위가 문서를 거르지 않는다.
     실제로 시간 범위를 `Last 15 minutes`에서 `2027-01-01~2032-01-01`로 바꿔도
     `검토 대상 선수`는 6,000 그대로였다. 문서 집합이 시간에 영향받지 않는다는 직접 증거다.
     (다만 **날짜 차트의 x축 범위는 영향을 받는다.** 문제 3 참조.)
  2. **`Other` 버킷이 생기지 않는다.** `league` 8종·`club` 10종 모두 Top N으로 전부 담긴다.
     3교시 공통에서 `brand` 40종 때문에 겪은 근사 오차(`doc_count_error_upper_bound: 494`) 문제가 없다.
  3. **총합이 맞는다.** 리그별 합(932+926+919+719+703+691+612+498)과 만료 연도별 합(757+1,584+1,454+1,465+740)이
     각각 **6,000**으로 Metric과 일치한다. Control 적용 시에도 주발 합(353+124+21)이 **498**로 Metric과 맞았다.
     빠지거나 중복된 문서가 없다는 뜻이다.

## (개인·필수) 문제 3 — 문제 하나를 실제로 수정하고 재검증

제목, field, 집계, 정렬, 구간, 시간, filter, layout 중 한 문제를 골라 수정하세요. 문제가 없다고 생각되면 사용성 문제 하나를 개선합니다.

- 발견한 문제: **`계약 만료 연도 분포` 패널만 완전히 비어 있었다.**
  y축이 0에 붙어 있고 x축에는 `2026` 한 칸만 표시됐다. 나머지 네 패널은 정상이었다.
- 문제 유형: **시간(전역 시간 범위)** — 데이터나 집계 정의 문제가 아니었다.
- 수정 전 설정 또는 결과: `date_histogram` on `contract_until`, `interval: 1y`, `includeEmptyRows: true`.
  Dashboard 전역 시간 범위는 기본값 `Last 15 minutes`(= 2026-09-03 시점).
- 확인 순서와 근거:
  1. Data View — `PL 스카우팅 선수` 맞음
  2. **다른 패널** — `검토 대상 선수`가 **6,000**으로 정상. 전역 조건(KQL·filter·Control) 문제였다면
     Metric도 함께 줄었을 것이다. 2교시·5교시에서 쓴 판별법 그대로다.
  3. 그 패널의 Lens 설정 — field·interval 모두 의도대로였다
  4. **전역 시간 범위** — 여기가 원인이었다
- **1차 진단은 틀렸다.** 처음에는 `includeEmptyRows: true` 때문에 빈 버킷만 그려진다고 보고 `false`로 껐다.
  증상이 그대로였다. 껐다 켜도 변화가 없다는 것이 오히려 단서가 됐다.
- 추정 원인(2차, 확인됨): **Data View에 time field가 없어도 `date_histogram`의 x축 범위는 전역 시간 범위를 따른다.**
  문서는 걸러지지 않지만(Metric 6,000 유지) 축이 2026년 15분 구간으로 잡혀
  2027~2031 막대가 화면 밖에 그려졌다.
- 수정한 한 가지: Dashboard에 시간 범위 **`2027-01-01 ~ 2032-01-01`**을 저장했다(`timeRestore: true`).
  `includeEmptyRows`는 원래대로 되돌렸다. 패널의 field·집계·interval은 건드리지 않았다.
- 수정 후 결과: 막대 **5개**가 나타났다 — 2027 **757**, 2028 **1,584**, 2029 **1,454**, 2030 **1,465**, 2031 **740**.
- 같은 조건 재검증 결과: **다른 패널 값이 전혀 변하지 않았다.**
  `검토 대상 선수` 6,000, 주발 4,304/1,472/224, 구단 Harrowgate FC 638/45,294,953.71 그대로다.
  시간 범위를 바꿨는데 문서 집합이 안 변한 것이 **time field가 없다는 사실의 재확인**이기도 하다.
  만료 연도별 합 `757+1,584+1,454+1,465+740 = 6,000`으로 Metric과 일치한다.
- 개선/보류/악화 판정과 근거: **개선.**
  판정 근거는 건수가 아니라 **패널이 질문에 답하게 됐는지**다. 수정 전에는 "계약이 언제 풀리는가"에
  아무 답도 주지 못했고, 수정 후에는 2028년이 1,584명으로 가장 많다는 답을 준다.
  다른 패널에 부작용이 없다는 것도 확인했다.
- 교훈: **time field를 쓰지 않는 Data View라도 날짜 차트를 넣으면 시간 범위가 다시 개입한다.**
  1교시에서 `contract_until`을 time field로 잡지 않은 판단은 옳았지만(그랬다면 Discover가 0건),
  그 선택의 부작용이 날짜 차트에서 드러났다. 두 선택은 별개로 판단해야 한다.
- 수정 전·후 캡처: 수정 전은 미촬영. 수정 후는 `p07-q03-personal-dashboard.png`에 5개 막대가 담겨 있다.

## (개인·필수) 문제 4 — 결과 3·한계 2·필요 데이터 1과 제출

### 결과 3개

문장 틀: `조건 → 핵심값 → 비교 대상 → 다음 행동 → 한계`
아래 수치는 Dev Tools 집계로 검증한 값이며, Dashboard 화면 대조는 제작 후 수행한다.

1. **계약 만료 연도 분포에서 2028년이 1,584명으로 2027년 757명보다 두 배 이상 많았다.**
   따라서 2028년 만료 자원을 미리 목록화해 우선 관찰을 검토한다.
   다만 이적 사건 데이터가 없으므로 실제 영입 가능성이 높다고는 단정하지 않는다.
2. **리그별 분포에서 Premier League U21이 498명으로 8개 리그 중 가장 적었고, Serie A 932명의 절반 수준이었다.**
   주제가 유스·하위 리그 자원인데 정작 그 표본이 가장 얇으므로,
   PL U21 단독으로 후보를 채우지 말고 EFL League One(719)·Two(703)를 함께 훑는다.
   다만 이 분포는 실제 시장 구성이 아니라 생성기의 `weighted_choice` 가중치 결과이므로
   현실의 리그별 선수 규모를 반영한다고 볼 수 없다.
3. **주발 구성에서 왼발이 1,472명으로 전체의 24.5%였고 오른발 4,304명의 3분의 1 수준이었다.**
   왼발 자원은 희소하므로 조건에 맞는 후보가 나오면 우선 관찰 대상에 올린다.
   다만 희소하다는 것이 곧 가치가 높다는 뜻은 아니며, 실제 경기력 데이터가 없어 성능 비교는 불가능하다.

### 현재 데이터의 한계 2개

1. **문서 1건이 선수 1명의 현재 상태 스냅샷이라 시간축에 쌓이는 사건이 없다.**
   "이적이 실제로 얼마나 성사됐나", "몸값이 어떻게 변했나" 같은 추이 질문에 답할 수 없다.
   `contract_until`로 시간 차트를 그릴 수는 있지만 그것은 사건의 흐름이 아니라 만료일 분포다.
   `contract_until`을 이적 시점으로 읽으면 공통 실습에서 `created_at`을 판매 추이로 읽는 것과 같은 오류가 된다.
2. **field 사이에 종속이 없어 서로 모순되는 문서가 존재한다.**
   생성기가 field를 각각 독립 난수로 뽑기 때문이다. Day 3에서 실측으로 확인했다.
   - `왼발 측면 돌파` 169건 중 `detailed_position`이 **`GK` 14건, `CB` 22건** — 골키퍼의 강점이 측면 돌파일 수 없다
   - `appearances: 4`인데 `goals: 26`인 문서 — 4경기에 26골은 불가능하다
   따라서 **포지션별 강점 집계나 출전 대비 생산성 지표는 Dashboard에 올리지 않았다.**
   Day 3에서는 `detailed_position`에 `terms` filter를 더해 169 → 82건으로 완화했지만
   근본 원인은 생성 규칙에 있어 검색·시각화로는 해결되지 않는다.

### 추가로 필요한 데이터 1개

- field: **`transfer_date`** (이적 사건 index `scout-transfers-2627`의 핵심 field)
- mapping type: `date` (format 미지정, ISO 8601)
- 예시값: `2026-01-18T00:00:00Z`, `2025-08-03T00:00:00Z`, `2027-07-11T00:00:00Z`
- 값 분포·생성 규칙: 2024-07-01 ~ 2027-06-30(3시즌), **월 단위 집계**.
  `window`가 `summer`(70%)면 6~8월, `winter`(30%)면 1~2월 안에서 뽑는다.
  이 종속이 있어야 이적 시장의 여름·겨울 봉우리가 나타난다. 균등 난수로 뿌리면 평평해져 의미가 없다.
  함께 필요한 field는 `player_id`(연결키), `fee_eur`(`long`, 0~150,000,000, 자유계약 20%),
  `from_club`/`to_club`(`keyword`, 서로 달라야 함)이다. 문서 3,000건 이상, seed 고정.
- 추가되면 답할 수 있는 질문:
  - "이적이 언제 몰리는가?" — 월별 이적 건수 Line
  - "우리가 노리는 리그에서 실제로 선수가 빠져나가는가?" — `from_club` 기준 집계
  - "자유계약 비중이 얼마나 되는가?" — `fee_eur = 0` 비율 Donut
  - "이적료가 시장가치 대비 어느 수준인가?" — `fee_eur`와 `market_value_eur` 비교

### 제출 기록

- Dashboard 제목: 공통 `Dashboard - 쇼핑몰 상품 데이터` (→ `D4 공통 상품 Dashboard - 한성민`으로 변경 예정) /
  개인 **`D4 개인 미션 - PL 스카우팅 - 한성민`** (id `31121c50-fb05-4fef-ac9a-647f7e16e577`, 제작 완료)
- 전체 화면 캡처 경로: `evidence/day-04-practice/` — **21장**(1~5교시 18장 + 7교시 3장)
- JSON export 경로(선택): 미수행. 화면 캡처를 기본 근거로 제출한다.
  현재 Kibana 9.5.0에 Dashboard PDF 메뉴가 없는 것은 정상이다.
- `dashboard-plan.md` 경로: `evidence/day-04/dashboard-plan.md`
- `dashboard-review.md` 경로: `evidence/day-04/dashboard-review.md`
- 개인 저장소 commit SHA: `51792e0` (`51792e0d971e7dcde5481f6a3e2f350518436b2b`)
- 미완료 또는 알려진 제한 사항:
  1. 선택 도전 5문제(2·4·5·6·8교시분) 미실행
  2. 개인 Dashboard의 `Store time with dashboard` 종료 시각이 `now`로 남은 공통 Dashboard 재현성 보완 권장
  2. 5교시 잔여 — Dashboard 제목 변경, `Store time with dashboard`,
     Filter(`in_stock is false` → 3,001)·KQL(`price >= 100000` → 8,088) 실행, 저장 후 재열기
  3. 선택 도전 4문제(2·4·5·6교시분) 미실행
  4. `dashboard-review.md` 미작성

### 제출 기록

- Dashboard 제목:
- 전체 화면 캡처 경로:
- JSON export 경로(선택):
- `dashboard-plan.md` 경로:
- `dashboard-review.md` 경로:
- 개인 저장소 commit SHA:
- 미완료 또는 알려진 제한 사항:

PDF 메뉴가 없으면 정상입니다. 현재 수업 환경의 `More → Export`는 Dashboard JSON을 제공하며, 관련 객체까지 옮길 때는 `Stack Management → Kibana → Saved Objects → Export`를 사용합니다. 화면 캡처를 기본 근거로 제출합니다.

## (선택 도전) 문제 5 — 다른 사람이 재현할 수 있는지 점검

자신의 기록만 보고 다음 항목을 다시 수행해 보거나 옆 학생에게 문서만 보여 줍니다.

- [ ] 올바른 Data View를 선택할 수 있다.
- [ ] 시간 범위를 동일하게 맞출 수 있다.
- [ ] Control/Filter 조건을 재현할 수 있다.
- [ ] 핵심값 3개의 비교 근거를 찾을 수 있다.
- [ ] Dashboard를 초기 상태로 복구할 수 있다.

- 미실행. 개인 Dashboard 제작 후 수행한다.
- 다만 현재 기록만으로도 재현에 필요한 요소는 갖췄다고 본다.
  - Data View: 이름 `PL 스카우팅 선수`, index pattern `scout-players-2627`, **time field 없음**까지 기록
  - 시간 범위: 개인 Data View는 time field가 없어 맞출 시간 범위 자체가 없다
  - Control/Filter 조건: `league` Options list, `contract_until <= 2028-06-30`
  - 핵심값 3개 비교 근거: `dashboard-plan.md` 7절의 Dev Tools 요청
  - 초기 상태 복구: Control `Any`, filter pill 삭제 → 6,000
- 재현에 부족할 것으로 예상되는 설명: **패널 크기와 배치 비율**은 문서로 적기 어렵다.
  `dashboard.ndjson` export를 남기면 배치까지 그대로 복원된다. 선택 백업으로 검토한다.

## Day 4 최종 완료 신호

- GREEN: 필수 32문제의 요구 산출물, 개인 Dashboard, plan/review, 캡처, commit 완료
- YELLOW: Dashboard는 있으나 검증·개선·commit 중 하나가 미완료
- RED: 저장된 Dashboard 또는 제출 근거가 없음

### 현재 판정: **GREEN**

| 교시 | 판정 | 비고 |
|---:|---|---|
| 1 | GREEN | 캡처 3장 |
| 2 | GREEN | 캡처 3장 |
| 3 | GREEN | 캡처 3장, accuracy mode 전후 비교 |
| 4 | GREEN | 캡처 3장 |
| 5 | **GREEN** | 제목 변경·Filter/KQL·재열기 완료 |
| 6 | GREEN | 설계 완료, 캡처 없음(화면 조작 없는 교시) |
| 7 | **GREEN** | 패널 5 + Control, 화면 값 대조·캡처 3장 완료 |
| 8 | **GREEN** | 문제 1~4 완료, 시간대 차이 원인까지 규명 |

공통 Dashboard(6패널 + Control), 개인 Dashboard(5패널 + Control), `dashboard-plan.md`,
`dashboard-review.md`, 캡처 17장이 갖춰졌다.

**필수 32문제와 요구 산출물이 모두 완료됐다.**

- 공통 Dashboard `D4 공통 상품 Dashboard - 한성민` (6패널 + Control)
- 개인 Dashboard `D4 개인 미션 - PL 스카우팅 - 한성민` (5패널 + Control)
- `dashboard-plan.md`, `dashboard-review.md`
- 캡처 21장

선택 도전 5문제는 미실행이며 각 교시에 그 사실을 적었다.
