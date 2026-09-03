# 1교시 연습 — Data View·Discover·KQL·데이터 준비 상태

> 실행 2026-09-03 / Kibana 9.5.0 / Elasticsearch 9.5.0 3-node
> 공통은 `products`(20,000건), 개인은 `scout-players-2627`(6,000건)
> 캡처 3장은 `evidence/day-04-practice/`에 저장했다.

- 필수 권장 시간: 38분
- 선택 도전: 7분
- 제출 상태 확인: 5분
- 시작 기준: Kibana 접속 가능
- 화면 순서: [Data View·Discover 상세 가이드](../KIBANA_9_5_STEP_BY_STEP.md#1-data-view-만들기-또는-기존-data-view-확인하기)

## (공통·필수) 문제 1 — Dashboard를 만들 수 있는 데이터인지 확인

강사가 지정한 `products` Data View를 선택하고 다음 항목을 확인하세요.

- index pattern: `products`
- time field: `created_at`
- 실제 field: `product_id`, `name`, `category`, `brand`, `price`, `in_stock`, `created_at`
- Discover 전체 문서 수: 20,000

### 결과 입력

- 선택한 Data View 이름: `쇼핑몰 상품 데이터`
- index pattern: `products`
- time field: `created_at`
- 확인한 7개 field: `product_id`, `name`, `category`, `brand`, `price`, `in_stock`, `created_at`
  — 7개 모두 Discover 표의 열로 추가했고 `Columns 7`로 표시됐다.
  Data View 상세 화면 기준 Fields는 18개(실제 field 13 + meta field 5)다.
- 사용한 절대 시간 범위: **`2025-08-27 00:00:00.000` ~ `2026-08-28 00:00:00.000`** (Absolute)
- Discover 실제 문서 수: **20,000**
- 정상/보류/오류: **정상**
- 판정 근거: 기준값 20,000과 일치했다. `_count` API 결과도 20,000으로 같다.
  데이터 최대 `created_at`이 `2026-08-26T23:59:46Z`라 종료 시각을 8/28로 넉넉히 잡아 마지막 문서가 빠지지 않았다.
  주소창에는 `from:'2025-08-26T15:00:00.000Z'`로 보이는데, 화면은 KST·URL은 UTC라 9시간 차이가 나는 정상 동작이다.
- 캡처 파일: `p01-q01-discover-20000.png`

## (공통·필수) 문제 2 — KQL 적용 전후를 비교

Discover의 전체 20,000건 상태에서 다음 KQL을 실행하세요.

```text
in_stock : false
```

결과를 기록한 뒤 KQL을 지우고 전체 상태로 복구하세요.

### 비교 결과

| 확인 항목 | 적용 전 | 적용 후 | KQL 제거 후 |
|---|---:|---:|---:|
| 문서 수 | 20,000 | **3,001** | **20,000** |

- 적용 후 대표 문서 ID 2개: **`P-03985`**(MobiCore 컴팩트 노이즈 캔슬링 헤드폰), **`P-14019`**(UrbanStep 실속형 러닝화)
- `in_stock` 값 확인: 두 건 모두 `false`. 화면에 표시된 3,001건의 표본을 확인했다.
- 복구 성공 여부: **성공.** 검색창을 비우고 다시 실행하니 20,000으로 돌아왔다.
- 캡처 파일: `p01-q02-kql-before-after.png`
- KQL이 데이터를 삭제한 것인가? 이유: **아니다.**
  삭제였다면 조건을 지워도 3,001건이어야 하는데 20,000으로 그대로 복구됐다.
  KQL은 색인된 문서를 건드리지 않고 **현재 화면에 보여줄 문서만 걸러내는 표시 조건**이다.
  실제 삭제는 `DELETE` 요청이나 `_delete_by_query`처럼 색인을 바꾸는 별개 동작이다.

## (진단·필수) 문제 3 — 0건 또는 일부 데이터만 보이는 상황 복구

다음 상황을 가정합니다.

> Discover에서 데이터가 0건이거나 예상보다 적게 보인다. index가 지워졌다고 단정하지 않고 원인을 확인한다.

아래 순서로 현재 화면을 점검하세요.

1. 시간 범위
2. 선택한 Data View
3. KQL 입력
4. filter pill
5. field가 실제 mapping에 존재하는지

실제 화면에서 조건 하나를 일부러 적용해 건수를 줄였다가 다시 복구해도 됩니다.

### 진단 기록

- 재현한 증상: `in_stock : false` KQL을 적용해 **20,000 → 3,001**로 줄어든 상태를 만들었다.
  화면만 보면 "데이터가 6분의 1로 줄었다"로 보인다.
- 마지막 정상 상태: Data View `쇼핑몰 상품 데이터`, 절대 시간 범위 `2025-08-27 ~ 2026-08-28`,
  KQL 없음, filter pill 없음 → 20,000건
- 확인한 항목과 순서:
  1. **시간 범위** — Absolute `2025-08-27 00:00 ~ 2026-08-28 00:00` 그대로. 이상 없음.
  2. **Data View** — `쇼핑몰 상품 데이터`(index pattern `products`) 그대로. 이상 없음.
  3. **KQL 입력** — `in_stock : false`가 남아 있었다. **여기서 원인 발견.**
  4. filter pill — 없음
  5. field 존재 여부 — `in_stock`은 Data View의 `boolean` field로 실재한다. 오타가 아니다.
- 발견한 원인: **KQL 조건이 남아 있어 표시 대상이 좁혀진 것.** index나 데이터 문제가 아니다.
- 수정한 내용: 검색창을 비우고 Enter. 다른 설정은 건드리지 않았다.
- 수정 후 문서 수: **20,000**
- 다음부터 먼저 확인할 항목: **시간 범위 → Data View → KQL → filter pill → field 순서.**
  0건일 때는 대부분 시간 범위가 원인이고(기본값 `Last 15 minutes`면 `created_at`이 2025~2026년이라 아무것도 안 잡힌다),
  "줄어들었다"일 때는 대부분 KQL이나 filter pill이 원인이다.
  index가 지워졌는지는 `GET /_cat/indices/products?v`로 마지막에 확인하면 되고, 그전에 화면 상태부터 본다.
- 캡처 파일: `p01-q02-kql-before-after.png` (KQL 적용 상태가 그대로 담겨 있어 진단 근거로 함께 사용)

## (개인·필수) 문제 4 — 내 데이터 준비 상태 카드

자기 index 또는 준비 중인 데이터에서 Dashboard 질문 하나를 정하고 필요한 field를 점검하세요. 개인 Data View가 아직 없다면 mapping·샘플 문서로 판단합니다.

### 개인 답안

- 내 주제: 26/27 시즌 프리미어리그 스카우팅 선수 검색
- 한 문서가 의미하는 대상 또는 사건: **선수 1명의 현재 상태 스냅샷.** 사건이 아니라 대상이다.
- Dashboard 사용자: 하위 리그·유스 자원 영입을 검토하는 **스카우팅 리서처 1명**
- 사용자가 내릴 판단: **다음 이적시장에 누구를 먼저 보러 갈지.**
  어느 리그를 우선 훑을지, 어느 구단에 후보가 몰려 있는지, 언제 계약이 풀리는 자원을 지금 봐 둬야 하는지.
- 첫 분석 질문: **"검토 대상 선수가 어느 리그에 몰려 있는가?"**
- 필요한 field: `league`, `player_id`(건수 계산 대상), 보조로 `club`, `age`, `preferred_foot`, `contract_until`
- 각 field의 mapping type:

  | field | type | 역할 |
  |---|---|---|
  | `league` | `keyword` | 그룹 축 |
  | `player_id` | `keyword` | 식별자 |
  | `club` | `keyword` (+`.text`) | 그룹 축 |
  | `age` | `short` | 범위·정렬 |
  | `preferred_foot` | `keyword` | 비율 |
  | `contract_until` | `date` (format 미지정) | 시간 축 |
  | `market_value_eur` | `long` | 평균 계산 |

- 실제 존재 여부: **전부 존재한다.** Data View `PL 스카우팅 선수`에서 Available fields **23개**로 인식됐고,
  Discover 표에 `player_id`·`name`·`club`·`league`·`age`·`preferred_foot`·`contract_until` 7개 열을 실제로 띄웠다.
- 데이터 문서 수: **6,000건** (Discover `Documents (6,000)`, `_count`도 6,000)
- A / B / C 중 선택: **A — 개인 데이터 사용**
- 선택 이유: 범주형(`league`, `club`, `preferred_foot`), 수치형(`age`, `market_value_eur`),
  상태형(`is_homegrown`), 날짜형(`contract_until`)이 모두 있어 Metric·Bar·Table·Donut·Line을
  전부 실제 field로 만들 수 있다. 공통 `products`를 흉내 낼 필요가 없다.
- 부족한 데이터와 다음 행동: **이적 사건 데이터가 없다.**
  문서 1건이 선수 1명의 스냅샷이라 "이적이 실제로 얼마나 성사됐나", "몸값이 어떻게 변했나" 같은
  시계열 질문에 답할 수 없다. `transfer_date`·`fee_eur`·`from_club`·`to_club`을 가진
  별도 index(`scout-transfers-2627`)가 필요하며, 설계는 `evidence/day-04/dashboard-plan.md` 4절에 적었다.
  Day 4 범위에서는 **현재 데이터로 답할 수 있는 질문만 Dashboard로 만들고**, 부족한 부분은 설계로 남긴다.

- 개인 Data View 생성 기록: 이름 `PL 스카우팅 선수`, index pattern `scout-players-2627`,
  **time field 없음**(`I don't want to use the time filter`).
  `contract_until`이 2027~2031년이라 이를 time field로 잡으면 기본 시간 범위에서 0건이 나온다.
  시간 필터를 쓰지 않으니 Discover 상단 시간 선택기 자체가 표시되지 않는다.
- 캡처 파일: `p01-q04-personal-discover.png`

## (선택 도전) 문제 5 — 서로 다른 KQL 3개 설계

`products`에서 category, price, in_stock 중 서로 다른 field를 사용한 KQL 3개를 만들고, 한 번에 한 조건만 실행하세요.

| KQL | 질문 | 결과 수 | 대표 문서 | 조건 제거 후 20,000 복구 |
|---|---|---:|---|---|
| `category : "전자기기"` | 전자기기 상품은 몇 개인가? | (미실행) | | |
| `price >= 200000` | 20만원 이상 고가 상품은 몇 개인가? | (미실행) | | |
| `in_stock : true` | 재고가 있는 상품은 몇 개인가? | (미실행) | | |

> 선택 도전이라 아직 Discover에서 실행하지 않았다. 세 KQL은 `category`(keyword)·`price`(integer)·
> `in_stock`(boolean)으로 서로 다른 type의 field를 쓰도록 설계했다.
> 실행하면 각각 **2,500 / 2,893 / 16,999**가 나올 것으로 예상한다(ES 집계로 미리 확인한 값).
> 화면에서 확인한 뒤 실제 값과 대표 문서를 채운다.

## 교시 완료 신호

- GREEN: 필수 1~4 완료, 마지막 상태 20,000, KQL/filter 없음
- YELLOW: 결과는 있으나 수치·시간·field 중 하나가 다름
- RED: Data View 또는 Discover에서 데이터를 확인할 수 없음

### 현재 판정: **GREEN**

필수 문제 1~4의 실행·수치·근거가 모두 갖춰졌다.
마지막 상태는 KQL 없음, filter pill 없음이며 공통 `products` 기준 20,000건으로 복구돼 있다.

| 캡처 | 담긴 화면 |
|---|---|
| `p01-q01-discover-20000.png` | 공통 20,000건, 열 7개, 절대 시간 범위 `Aug 27, 2025 @ 00:00 → Aug 28, 2026 @ 00:00`, KQL 비어 있음 |
| `p01-q02-kql-before-after.png` | 같은 조건에 KQL `in_stock : false` 적용, 3,001건, 표의 `in_stock`이 전부 `false` |
| `p01-q04-personal-discover.png` | 개인 `PL 스카우팅 선수` 6,000건, 열 7개, time field가 없어 시간 선택기 자체가 표시되지 않음 |

선택 도전 문제 5는 미실행으로 남겨 두었다.
