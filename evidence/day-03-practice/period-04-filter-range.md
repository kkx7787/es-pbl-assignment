# 4교시 실습 — 정확 조건과 경계

> **공통 문제**는 강사 배포 공통 index `products`(10,000건)에서 제공 코드 그대로 실행했다.
> `day-02/data/product-mapping.json`으로 index를 만들고 `products-10000.ndjson`을 `_bulk`로 적재했다
> (`green`, 3 primary + 1 replica, category 8종 × 1,250건).
> **개인 문제**는 자기 index `scout-players-2627`(6,000건)에서 실행했다.
> 실행 2026-09-02 / ES 9.5.0 3-node / 추측으로 채운 값은 없다.

## (공통) 문제 1 — 제공 코드로 세 filter 확인

```http
GET /products/_search
{
  "size": 10,
  "query": {
    "bool": {
      "filter": [
        { "term": { "category": "전자기기" } },
        { "term": { "in_stock": true } },
        { "range": { "price": { "gte": 50000, "lte": 200000 } } }
      ]
    }
  }
}
```

### 결과 입력

- `hits.total.value`: `380`
- 확인한 문서 ID 3개: `P-00025`, `P-00129`, `P-00185`
- 각 문서의 category / in_stock / price:

  | ID | name | category | in_stock | price |
  |---|---|---|---|---:|
  | `P-00025` | MobiCore 컴팩트 무선 이어폰 | 전자기기 | `true` | 59,400 |
  | `P-00129` | Auralis 스마트 무선 이어폰 | 전자기기 | `true` | 53,800 |
  | `P-00185` | MobiCore 스마트 블루투스 스피커 | 전자기기 | `true` | 161,600 |

- 조건을 위반한 문서가 있는가: **없다.** 세 건 모두 카테고리가 일치하고 재고가 있으며
  가격이 50,000~200,000 안이다.
  반환된 10건의 `_score`가 전부 `0.0`인 것도 근거다. `filter` 절은 관련도를 계산하지 않고
  조건 충족 여부만 판정하므로 점수가 매겨지지 않는다.

## (공통) 문제 2 — 경계 포함 범위 직접 구현

### API 전체 입력

```http
GET /products/_search
{
  "size": 10,
  "_source": ["product_id", "name", "category", "price"],
  "query": {
    "bool": {
      "filter": [
        { "term": { "category": "전자기기" } },
        { "term": { "in_stock": true } },
        { "range": { "price": { "gte": 50000, "lte": 200000 } } }
      ]
    }
  }
}
```

### 결과 입력

- `hits.total.value`: `380`
- 최소·최대 price: `stats` 집계로 확인 — **min `50,700` / max `199,500`**
- 50,000 또는 200,000 경계 문서 존재 여부와 ID: **둘 다 없다.**
  `terms` query로 두 경계값을 직접 조회한 결과 **`total: 0`**이었다.
  `price`가 100원 단위로 생성되지만 정확히 50,000원이거나 200,000원인 전자기기 재고 상품이
  이 데이터에는 존재하지 않는다. 실제 최소값이 50,700, 최대값이 199,500으로 경계 안쪽이다.

## (공통) 문제 3 — 경계 제외 범위 직접 구현

`gte/lte`를 `gt/lt`로 바꾼 것 외에는 문제 2와 완전히 동일하다.

### API 전체 입력

```http
GET /products/_search
{
  "size": 10,
  "_source": ["product_id", "name", "category", "price"],
  "query": {
    "bool": {
      "filter": [
        { "term": { "category": "전자기기" } },
        { "term": { "in_stock": true } },
        { "range": { "price": { "gt": 50000, "lt": 200000 } } }
      ]
    }
  }
}
```

### 비교 결과

- 문제 2 total / 문제 3 total: **`380` / `380` — 같다.**
- 빠진 경계 문서 ID: **없다.**
- 경계 문서가 없어 결과가 같다면 확인한 근거: **세 가지로 확인했다.**
  1. `terms` query로 `price`가 정확히 `50000` 또는 `200000`인 문서를 같은 filter 조건에서 조회 → **`total: 0`**
  2. `stats` 집계의 실제 min이 `50,700`, max가 `199,500`으로 **둘 다 경계 안쪽**
  3. 두 요청의 total이 `380`으로 동일

  즉 `gte`와 `gt`의 차이는 **경계값을 가진 문서가 있을 때만** 드러난다.
  결과가 같다고 해서 두 연산자가 같은 것이 아니라, 이 데이터에 경계 문서가 없었을 뿐이다.
  **결과가 같으면 "차이 없음"으로 결론짓지 말고 경계 문서의 존재 여부를 먼저 확인해야 한다.**
  경계 문서가 있는 사례는 개인 문제 5에서 `age`로 확인한다.

## (개인) 문제 4 — 자기 정확 조건 2개

### API와 결과 입력

```http
GET /scout-players-2627/_search
{
  "size": 5,
  "_source": ["player_id", "name", "preferred_foot", "detailed_position", "secondary_positions"],
  "query": {
    "bool": {
      "filter": [
        { "term": { "preferred_foot": "왼발" } },
        { "term": { "detailed_position": "LW" } }
      ]
    }
  }
}
```

- field·type·값 2개: `preferred_foot` / `keyword` / `왼발`, `detailed_position` / `keyword` / `LW`
  - 둘 다 값 집합이 닫혀 있어(주발 3종, 포지션 10종) 분석이 필요 없다. `keyword` + `term`이 맞는 짝이다.
  - 점수가 필요 없는 조건이므로 `must`가 아니라 `filter`에 넣었다.
- 실행 전 기대 ID / 제외 ID:
  - 기대: `P-0021` — 사전 조회로 `preferred_foot: 왼발`, `detailed_position: LW`임을 확인해 두었다.
  - 제외: `P-0001` — `preferred_foot: 오른발`, `detailed_position: CM`이라 두 조건 모두 불만족.
- 실제 결과와 판정: **통과.**
  - `hits.total.value`: `138`
  - 반환 5건: `P-0021`(Finley Moreau), `P-0030`(Marcus Lindqvist), `P-0120`(Rafael Moreau),
    `P-0130`(Lucas Doyle), `P-0151`(Lucas Doyle) — 전부 `preferred_foot: 왼발`, `detailed_position: LW`
  - 기대한 `P-0021`이 실제로 1위로 포함됐고, 제외 대상 `P-0001`은 결과에 없다.
  - `_score`가 모두 `0.0`이라 filter가 점수 없이 판정했음이 확인된다.

## (개인) 문제 5 — 자기 범위와 경계 실험

### 경계값 사전 확인

`age`(`short`)를 골랐다. `docs/data-model.md`의 Q2가 `age <= 22`를 쓰므로 업무적으로 의미 있는 경계다.
`terms` 집계로 실제 분포를 먼저 봤다.

| age | 문서 수 |
|---:|---:|
| 19 | 261 |
| 20 | 238 |
| 21 | 262 |
| 22 | 280 |
| 23 | 259 |

경계값 `20`과 `22` 모두 문서가 존재하므로 포함/제외 차이가 실제로 관측된다.

### API와 결과 입력

```http
# 포함 경계
GET /scout-players-2627/_search
{
  "size": 0,
  "query": { "range": { "age": { "gte": 20, "lte": 22 } } }
}

# 제외 경계 — range 연산자 외 나머지는 동일
GET /scout-players-2627/_search
{
  "size": 0,
  "query": { "range": { "age": { "gt": 20, "lt": 22 } } }
}
```

- field / type / 경계값: `age` / `short` / 하한 `20`, 상한 `22`
- 포함 요청 total / 제외 요청 total: **`780` / `262`**
- 달라진 문서 ID: 개별 ID가 아니라 **경계값을 가진 문서 전체 518건**이 빠졌다.
  `780 − 262 = 518 = 238(age 20) + 280(age 22)`로 집계값과 정확히 맞는다.
  남은 262건은 `age = 21`인 문서 수와 일치한다.
- 경계 판정: **통과.** `gte/lte`는 경계값을 포함하고 `gt/lt`는 제외한다는 것이
  집계 분포와 검색 건수로 교차 확인됐다.
  이 실험이 Q2에 중요한 이유는, Q2가 "22세 **이하**"이므로 반드시 `lte`여야 하고
  실수로 `lt`를 쓰면 **22세 280명이 통째로 사라지기** 때문이다.
  대표 문서 `P-0002`를 나이 정확히 22세로 설계해 둔 것도 이 경계를 검증하기 위해서다.
