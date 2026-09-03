# 2교시 연습 — Metric·Bar·Top values

> 실행 2026-09-03 / Kibana 9.5.0 / Data View `쇼핑몰 상품 데이터`(index `products`, 20,000건)
> 시간 범위 `Aug 27, 2025 @ 00:00 → Aug 28, 2026 @ 00:00`, KQL·filter·control 없음

- 필수 권장 시간: 40분
- 선택 도전: 5분
- 제출 상태 확인: 5분
- 시작 기준: Discover 20,000건, KQL/filter 없음
- 화면 순서: [Metric](../KIBANA_9_5_STEP_BY_STEP.md#5-패널-1--전체-상품-수-metric), [category Bar](../KIBANA_9_5_STEP_BY_STEP.md#6-패널-2--카테고리별-상품-수-bar)

## (공통·필수) 문제 1 — 전체 상품 수 Metric 제작

빈 Dashboard에 Lens Metric을 추가하세요.

- Data View: 공통 `products`
- 계산: Records 또는 Count of records
- 제목: `전체 상품 수`
- 정상 기준: 20,000

### 결과 입력

- Dashboard 이름: `Editing New Dashboard` (편집 중, 5교시에서 `D4 공통 상품 Dashboard - 한성민`으로 저장 예정)
- 사용한 계산: 왼쪽 field 목록의 `Records`를 Primary metric에 추가 → **`Count of records`**
  숫자 field를 고르거나 함수를 따로 지정하지 않았다. Records는 문서 자체를 세는 항목이다.
- 실제 Metric 값: **20,000**
- 시간 범위: `Aug 27, 2025 @ 00:00 → Aug 28, 2026 @ 00:00` (절대 범위)
- KQL/filter/control 상태: 셋 다 없음. 검색창 비어 있고 filter pill 없으며 Control은 아직 추가 전이다.
- 정상/보류/오류와 이유: **정상.**
  공통 기준값 20,000과 일치했고 1교시 Discover의 20,000, `GET /products/_count`의 20,000과도 같다.
  세 경로에서 같은 수가 나왔으므로 Data View·시간 범위·집계가 모두 같은 문서 집합을 보고 있다.
- 캡처 파일: `p02-q01-metric-bar.png` (Metric과 Bar 두 패널이 함께 보인다)

## (공통·필수) 문제 2 — category Bar 제작

같은 Dashboard에 category별 상품 수 Bar를 만드세요.

- 그룹 field: `category`
- 그룹 방식: Top values
- Number of values: 8
- 값: Count of records
- 제목: `카테고리별 상품 수`

### 설정·결과 입력

- Bar 방향: **Horizontal** (최종). 문제 3에서 Vertical과 비교한 뒤 Horizontal로 확정했다.
- x축 또는 category 차원: Horizontal axis → **Top values of `category`**
- y축 또는 Metric: Vertical axis → **`Count of records`**
  처음에 세로축을 비워 두면 `Requires field` 경고가 뜬다. `Records`를 넣어야 집계가 완성된다.
- Number of values: **8**
- 표시된 category 수: **8개** — 도서, 반려동물, 뷰티, 생활, 스포츠, 식품, 전자기기, 패션
- 각 category 값이 공통 기준과 일치하는가: **일치한다. 8종 모두 2,500이다.**
  y축 최대가 2,500이고 막대 8개 높이가 전부 같다. 툴팁으로 `생활 / Count of records 2,500`을 확인했다.
  `2,500 × 8 = 20,000`으로 Metric 패널 값과도 맞는다.
  균등한 이유는 생성기가 문서 순번을 8개 category에 돌아가며 배정하기 때문이며(`(n-1) % 8`),
  난수가 아니라 결정적 배분이라 정확히 나뉜다. 들쭉날쭉하게 나오는 쪽이 오히려 이상 신호다.
- 캡처 파일: `p02-q01-metric-bar.png`

## (변형·필수) 문제 3 — Bar 방향 한 가지만 바꿔 비교

동일한 category·Count·Top 8을 유지하고 Bar 방향만 vertical과 horizontal로 바꿔 보세요.

방향은 `Style → Appearance → Bar orientation`에서 바꿉니다. 축 label 방향과 혼동하지 않습니다.

| 비교 | vertical | horizontal |
|---|---|---|
| category 이름 가독성 | 아래축에 가로로 표시. 이름이 2~4글자라 8개가 모두 온전히 보인다 | 왼쪽축에 세로로 나열. 역시 모두 온전히 보인다. 이 데이터에서는 **차이가 거의 없다** |
| 값 비교 속도 | 높이로 비교. 8개가 전부 동률이라 위쪽 끝선이 일직선으로 보여 "같다"가 바로 읽힌다 | 길이로 비교. 오른쪽 끝선이 일직선. 판단 속도는 비슷하다 |
| 잘림·겹침 | 없음 | 없음 |

- 최종 선택: **horizontal**
- 선택 이유: 두 방향 모두 읽는 데 문제가 없었지만 horizontal을 택했다.
  이 category 이름은 최대 4글자라 vertical에서도 겹치지 않아 **가독성 차이는 크지 않다.**
  다만 Dashboard에서 이 패널을 가로로 넓게 배치했을 때 horizontal이 공간을 덜 낭비하고,
  항목이 늘거나 이름이 길어져도 같은 배치를 유지할 수 있다.
  **이 데이터만 놓고 보면 어느 쪽이든 무방하며, 선택 근거는 가독성보다 배치 확장성이다.**
- 다른 설정을 동시에 바꾸지 않았는가: **바꾸지 않았다.**
  `Top values of category` / `Number of values 8` / `Count of records`를 그대로 두고
  `Style → Appearance → Bar orientation` 하나만 전환했다.
  근거로 **두 방향 모두 8종 각 2,500으로 집계 결과가 동일**했다. 표현만 바뀌고 데이터는 바뀌지 않는다.
- 캡처 파일: `p02-q03-bar-orientation.png` (horizontal 적용 상태와 Style 패널이 함께 보인다)

## (진단·필수) 문제 4 — 막대가 하나만 남은 상황 복구

Bar에 `스포츠` 등 하나의 category만 보인다고 가정합니다. Dashboard에서 다음을 확인하고 원래 8개 category로 복구하세요.

1. category Control 선택값
2. 상단 filter pill
3. KQL
4. 시간 범위
5. Lens의 Top values 설정

### 진단 기록

문제지는 `스포츠` 하나만 보이는 상황을 가정하지만, 실제로 재현해 보기 위해
Lens의 `Number of values`를 `8` → `1`로 바꿔 같은 증상을 만들었다.

- 보이던 category: **`도서` 1개.** 다만 막대는 2개였다 — `도서` **2,500**과 **`Other` 17,500**이다.
  Lens의 Top values는 상위 N개를 뺀 나머지를 `Other` 버킷으로 묶는다.
  즉 category 7종이 사라진 게 아니라 한 덩어리로 합쳐졌다.
  `2,500 + 17,500 = 20,000`으로 **총합이 그대로**라는 점이 문서가 유실되지 않았다는 직접 증거다.
- 발견한 제한 조건: **Lens 집계의 `Number of values`가 `1`.**
  문제지가 제시한 1~4번(Control 선택값 / filter pill / KQL / 시간 범위)에는 원인이 없었다.
  - Control: 아직 추가하지 않았다
  - filter pill: 없음
  - KQL: 비어 있음
  - 시간 범위: `Aug 27, 2025 → Aug 28, 2026` 그대로
  Metric 패널이 계속 **20,000**을 유지한 것이 결정적이었다.
  조건이 걸렸다면 Dashboard 전체에 적용돼 Metric도 함께 줄었을 텐데 그렇지 않았다.
  **한 패널만 이상하면 그 패널의 Lens 설정을 봐야 한다.**
- 제거 또는 초기화한 항목: `Number of values`를 다시 **`8`**로 되돌렸다. 다른 설정은 건드리지 않았다.
- 복구 후 막대 수: **8개** (`Other` 사라짐), 각 **2,500**
- 복구 후 Metric 값: **20,000** (처음부터 변하지 않았다)
- 원인이 없었다면 추가로 확인한 Lens 설정: 이번에는 Top N이 원인이었지만, 아니었다면 다음을 순서대로 본다.
  ① Lens 편집기 왼쪽 위 **Data View**가 다른 것으로 잡혔는지
  ② 가로축 field가 의도한 `category`인지
  ③ `Rank by`·`Rank direction`이 바뀌어 다른 상위 N이 뽑혔는지
  ④ 패널 자체에 붙은 filter가 있는지
- 재발 방지: "데이터가 적게 보인다"는 증상은 원인이 세 갈래다.
  **Dashboard 전체 조건(KQL·filter·control·시간)** / **패널별 Lens 설정(Top N·field)** / **데이터 자체**.
  Metric 같은 전체 규모 패널을 하나 두면 어느 쪽인지 바로 갈린다.
  화면에 `Other`가 보이면 두 번째를 먼저 의심한다.
- 캡처 파일: `p02-q04-bar-recovery.png` (`도서` + `Other` 상태와 `Number of values: 1` 설정이 함께 보인다)

## (개인·선택 도전) 문제 5 — 내 범주 field로 Metric+Bar 설계

자기 데이터의 전체 규모 Metric과 범주별 Bar를 설계하거나 만드세요. 범주 field가 없으면 필요한 field를 설계합니다.

- 개인 index/Data View: `scout-players-2627` / `PL 스카우팅 선수` (6,000건, time field 없음)
- 전체 규모가 의미하는 것: **검토 대상 선수 풀의 크기.** 문서 1건 = 선수 1명이므로 6,000명이다.
- 범주 field: **`league`** (`keyword`)
- 실제 고유값 수: **8개** — Serie A, La Liga, Bundesliga, EFL League One, EFL League Two,
  EFL Championship, Premier League, Premier League U21
- Top N 선택값과 이유: **8.** 고유값이 정확히 8개라 `Other` 버킷이 생기지 않는다.
  7로 두면 문제 4에서 본 것처럼 하나가 `Other`로 묶여 리그별 비교가 깨진다.
- 예상 사용자 판단: 스카우팅 리서처가 **어느 리그를 우선 훑을지** 정한다.
- 실제 제작 여부: **아직 만들지 않았다.** 7교시(개인 Dashboard 제작)에서 만든다.
  설계는 `evidence/day-04/dashboard-plan.md` 3절에 Q1(Metric)·Q2(Bar)로 정리해 두었다.
- 부족한 경우 필요한 field와 예시값: 범주 field는 충분하다.
  다만 **공통 `products`와 다른 점**이 있다. `products`의 category는 8종 각 2,500으로 균등한데,
  `league`는 Serie A 932 ~ Premier League U21 498로 **기울어 있다**(`weighted_choice` 규칙 때문).
  주제가 "하위 리그·유스 자원"인데 정작 PL U21 표본이 가장 얇아, Dashboard에서 그 부분이 빈약해 보인다.
  이 한계는 `dashboard-plan.md` 4절에 기록했다.
- 캡처 또는 설계 문서 경로: `evidence/day-04/dashboard-plan.md`

## 교시 완료 신호

- GREEN: Metric 20,000, category Bar 8개, 제목 2개, 비교·복구 기록 완료
- YELLOW: 패널은 있으나 값·Top N·제목 중 하나가 다름
- RED: Lens 저장 또는 Dashboard 복귀 불가

### 현재 판정: **GREEN**

- [x] Metric **20,000**
- [x] category Bar **8개 각 2,500**
- [x] 패널 제목 2개(`전체 상품 수`, `카테고리 별 상품 수`)
- [x] 방향 비교(vertical ↔ horizontal, 한 요소만 변경)와 Top N 복구 진단 기록
- [x] 캡처 3장 저장

선택 도전 문제 5는 설계만 하고 제작은 7교시로 미뤘다.
Dashboard는 6패널을 다 만든 뒤 5교시에서 저장한다.
