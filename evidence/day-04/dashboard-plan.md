# Day 4 개인 Dashboard 설계

> 작성 2026-09-03 / Kibana 실행 전 설계 단계. 이 문서의 수치는 Dev Tools 집계로 미리 확인한 값이며,
> Dashboard 화면에서 같은 값이 나오는지 대조하는 기준으로 쓴다.

## 1. 사용자와 목적

- 내 주제: 26/27 시즌 프리미어리그 스카우팅 선수 검색
- 이 Dashboard를 볼 사람: **하위 리그·유스 자원 영입을 검토하는 스카우팅 리서처 1명**
  (구단 전체가 아니라, 다음 이적시장 후보 목록을 만드는 실무자 한 사람으로 좁힌다.)
- Dashboard를 보고 결정하거나 행동할 것:
  **다음 이적시장에 누구를 먼저 보러 갈지 정한다.** 구체적으로 세 가지를 판단한다.
  ① 어느 리그를 우선 훑을지 ② 어느 구단에 후보가 몰려 있는지 ③ 언제 계약이 풀리는 자원을 지금 봐 둬야 하는지
- 사용할 index / Data View: `scout-players-2627-v1` (alias `scout-players-2627`) / Data View 이름 `PL 스카우팅 선수`
- 문서 단위: 1건 = 선수 1명, 총 6,000건

## 2. 데이터 준비 경로

- [x] **A: 개인 데이터로 제작**
- [ ] B: 공통 products로 제작하며 개인 데이터 보강 규칙 작성
- [ ] C: 공통 Dashboard를 완성하고 개인 청사진에 집중

선택 이유:
`scout-players-2627`에 6,000건이 색인돼 있고 23 field 중 범주형(`league`, `club`, `detailed_position`,
`preferred_foot`, `trait`, `tags`), 수치형(`age`, `market_value_eur`, `minutes` 등), 상태형(`is_homegrown`),
날짜형(`contract_until`)이 모두 있다. Day 4가 요구하는 Metric·Bar·Table·Donut·Line을 전부 실제 field로 만들 수 있다.
다만 **사건 데이터가 없어 답할 수 없는 질문이 있으므로**(4절) 그 부분은 보강 규칙으로 남긴다.

## 3. 질문-데이터-차트 청사진

| 번호 | 분석 질문 | 필요한 field | 현재 존재? | mapping type | 계산·그룹 방식 | 차트 | filter/control | 확인 기준 |
|---|---|---|---|---|---|---|---|---|
| Q1 전체 규모 | 검토 대상 선수 풀은 몇 명인가? | — (문서 수) | O | — | Count of records | Metric | control 영향 받음 | **6,000** |
| Q2 그룹 비교 | 어느 리그에 후보가 몰려 있나? | `league` | O | `keyword` | Top values 8, Count | Bar | `league` control | Serie A **932** / La Liga **926** / Bundesliga **919** / EFL L1 **719** / EFL L2 **703** / Championship **691** / PL **612** / PL U21 **498** |
| Q3 분포/정확한 값 | 어느 구단에 몇 명이 있고 몸값 수준은 어떤가? | `club`, `market_value_eur` | O | `keyword`, `long` | Rows Top values 10 / Count + Average | Table | 정렬로 비교 | Harrowgate FC **638명 / 평균 45,294,954** |
| Q4 상태/시간 | 계약이 언제 풀리는가? | `contract_until` | O | `date` | Date histogram `1y`, Count | Bar | 시간 대신 값 기준 | 2027 **757** / 2028 **1,584** / 2029 **1,454** / 2030 **1,465** / 2031 **740** |
| Q5 상태 비율 | 주발 구성은 어떤가? (왼발 자원이 얼마나 희소한가) | `preferred_foot` | O | `keyword` | Slice by Top values 3 | Pie → Donut | control 영향 받음 | 오른발 **4,304** / 왼발 **1,472** / 양발 **224** |

- 다섯 질문이 서로 겹치지 않는다. 규모 / 그룹 비교 / 정확한 값 / 시간 / 비율로 역할이 다르다.
- Control: `league` **Options list**. 리서처가 가장 자주 바꾸는 조건이 "어느 리그를 볼지"다.
  대안으로 `is_homegrown`(true **2,035** / false **3,965**)도 후보지만, 홈그로운은 값이 둘뿐이라
  Control보다 filter가 어울린다.

### 해석 주의

`contract_until`은 **계약 만료 시점**이지 이적 시점이 아니다. 2028년이 1,584명으로 가장 많다는 것은
그해에 **협상 기회가 열리는 선수 수**를 뜻하며, 그해에 이적이 많이 일어난다는 뜻이 아니다.
공통 실습의 `created_at`을 판매 추이로 읽으면 안 되는 것과 같은 종류의 함정이다.

## 4. 데이터 부족 분석

- 현재 데이터로 답할 수 없는 질문:
  - "이적이 실제로 얼마나 성사됐나", "몸값이 시간에 따라 어떻게 변했나", "누가 최근 폼이 좋은가"
  - 문서 1건 = 선수 1명(현재 상태 스냅샷)이라 **시계열 추이를 만들 수 없다.**
    `contract_until` 하나로 Line을 그릴 수는 있지만 그것은 사건의 흐름이 아니라 만료일 분포다.
- 부족한 field: `transfer_date`, `fee_eur`, `from_club`, `to_club`, `season`, `observed_at`, `form_rating`
- 필요한 mapping type: `date`, `long`, `keyword`, `keyword`, `keyword`, `date`, `float`
- 필요한 값의 범위·범주·비율:
  - `fee_eur` 0 ~ 150,000,000 (자유계약 0 포함, 전체의 약 20%)
  - `from_club`/`to_club`는 기존 `clubs` 후보 10개에서 뽑되 **서로 달라야 한다**
  - `season`은 `2024/25` ~ `2026/27` 3개 범주
- 날짜가 필요하다면 기간과 단위: 2024-07-01 ~ 2027-06-30, **월 단위** 집계
- 한 문서가 의미할 사건 또는 대상: **이적 1건**. 선수 index와는 별개 index(`scout-transfers-2627`)여야 한다.
  한 선수가 여러 번 이적하므로 선수 문서에 배열로 넣으면 집계가 어긋난다.
- 생성 또는 수집 방법: 기존 생성기(`my-data-settings.ps1` 형식)로 별도 설정 파일을 만들어 생성한다.
  단 **현재 생성기는 field 간 종속을 표현하지 못해** `from_club ≠ to_club`을 보장할 수 없다.
  `FixedDocumentsFile`로 경계 사례를 고정하거나 생성 후 후처리가 필요하다.
- 데이터 수가 충분하다고 판단할 기준: 이적 3,000건 이상. 월 36개월 × 리그 8개로 나눠도
  버킷당 10건 이상이 남아 Line 차트가 끊기지 않는다.

### 현재 데이터의 알려진 정합성 문제

Dashboard 해석에 영향을 주므로 미리 적어 둔다.

| 문제 | 근거 | 영향 |
|---|---|---|
| `detailed_position`과 `trait`가 독립 난수 | Day 3에서 `왼발 측면 돌파` 169건 중 `GK` 14건·`CB` 22건 확인 | 포지션별 강점 집계를 신뢰할 수 없다 |
| `appearances`와 `goals`가 독립 난수 | `appearances: 4`인데 `goals: 26`인 문서 존재 | 출전 대비 생산성 지표를 만들 수 없다 |
| `league` 가중치가 주제와 반대 | PL U21 **498**로 최소, Serie A **932**로 최대 | "하위 리그·유스 자원"이 주제인데 정작 그 표본이 가장 얇다 |

셋 다 `my-data-settings.ps1`의 생성 규칙에서 비롯되며, 고치려면 재생성·재적재가 필요하고
`bulk_sha256`이 바뀐다. Day 4 범위에서는 **기록만 하고 고치지 않는다.**

## 5. 제작 순서

1. **Data View 만들기** — `scout-players-2627`, `Show advanced settings`에서
   **"I don't want to use the time filter"** 선택.
   `contract_until`이 2027~2031년이라 time field로 잡으면 기본 시간 범위에서 0건이 나온다.
2. **Discover에서 6,000건 확인** — `player_id`, `name`, `club`, `league`, `age`,
   `preferred_foot`, `contract_until` 7개 열 추가. 캡처 `p01-q04-personal-discover.png`.
3. **새 Dashboard 생성** — 공통 Dashboard는 건드리지 않는다. 제목 `D4 개인 미션 - PL 스카우팅 - 한성민`.
4. **패널 5개 제작** — Q1 Metric → Q2 Bar → Q3 Table → Q5 Donut → Q4 Bar 순서.
   각 패널마다 `Save and return` 후 패널 `Settings`에서 제목을 붙인다.
   만들 때마다 3절 표의 확인 기준값과 대조한다.
5. **배치** — Metric 작게 위쪽, Bar·Donut 중간, Table 넓게 아래. 읽는 순서대로 둔다.
6. **Control 추가** — `league` Options list, Label `리그 선택`, 검색 방식 `Contains`.
   한 리그를 고르면 **2개 이상 패널이 함께 바뀌는지** 확인하고 `Any`로 복구해 6,000으로 돌아오는지 본다.
7. **저장** — `More → Settings`에서 필요 시 시간 설정 확인 후 `Save`.
   목록에서 나갔다 다시 열어 패널과 값이 유지되는지 확인.
8. **교차 검증** — Dev Tools에서 `_count`와 `terms` 집계를 실행해 화면 값과 대조. 핵심값 3개 이상.
9. **캡처 3장** — 전체 화면, filter/control 적용 상태, 개선 전후.
10. **문서 작성** — `dashboard-review.md`와 `evidence/day-04-practice/period-06~08` 답안.

## 6. 완료 예상 화면

- Dashboard 제목: `D4 개인 미션 - PL 스카우팅 - 한성민`
- 필수 패널 수: **5개** (완료 기준은 4개 이상)
  1. 전체 선수 수 (Metric)
  2. 리그별 선수 수 (Bar)
  3. 구단별 선수 수와 평균 시장가치 (Table)
  4. 주발 비율 (Donut)
  5. 계약 만료 연도 분포 (Bar)
- 사용할 control/filter: `league` Options list 1개 (완료 기준은 1개 이상)
- 저장할 캡처 파일명:
  - `evidence/day-04/personal-dashboard.png`
  - `evidence/day-04/personal-dashboard-filtered.png`
  - `evidence/day-04/common-dashboard.png`
  - 선택 백업: `evidence/day-04/dashboard.ndjson`

## 7. 교차 검증용 요청

Dashboard 값과 대조할 때 Dev Tools에 붙여 쓴다.

```
GET /scout-players-2627/_count

POST /scout-players-2627/_search
{
  "size": 0,
  "aggs": {
    "by_league": { "terms": { "field": "league", "size": 10 } },
    "by_foot":   { "terms": { "field": "preferred_foot" } },
    "by_club":   { "terms": { "field": "club", "size": 10 },
                   "aggs": { "avg_value": { "avg": { "field": "market_value_eur" } } } },
    "by_year":   { "date_histogram": { "field": "contract_until", "calendar_interval": "year" } }
  }
}
```
