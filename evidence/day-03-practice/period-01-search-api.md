# 1교시 실습 — Search API 기본

> **공통 문제**는 강사 배포 공통 index `products`(10,000건)에서 제공 코드 그대로 실행했다.
> `day-02/data/product-mapping.json`으로 index를 만들고 `products-10000.ndjson`을 `_bulk`로 적재했다
> (`green`, 3 primary + 1 replica, category 8종 × 1,250건).
> **개인 문제**는 자기 index `scout-players-2627`(6,000건)에서 실행했다.
> 실행 2026-09-02 / ES 9.5.0 3-node / 추측으로 채운 값은 없다.
>
> **[2026-09-03 추가]** Day 4가 `products` **20,000건**을 기준으로 해서 같은 생성기·같은 seed로
> `-Count 20000` 재생성분 중 `P-10001`~`P-20000` 10,000건을 추가 적재했다(`docs.deleted: 0`, 순수 추가).
> **아래 공통 문제의 수치는 적재 전 10,000건 시점의 실제 실행 결과이며 고치지 않는다.**
> 지금 같은 요청을 실행하면 전체 20,000건 기준으로 값이 달라진다(예: category 1,250 → 2,500).

## (공통) 문제 1 — 제공 코드 실행·응답 읽기

```http
GET /products/_search
{
  "size": 5,
  "query": { "match_all": {} }
}
```

### 결과 입력

- HTTP 성공 여부: 성공 (`200`)
- `hits.total.value`: `10000` (`relation: "eq"`)
- `hits.hits`에 반환된 문서 수: `5`
- 첫 번째 문서의 `_id`: `P-00003`
- 첫 번째 문서의 `_source` field 3개: `product_id: "P-00003"`, `name: "Morrow 실속형 오버핏 후드"`, `category: "패션"`
  (문서 전체는 12 field다 — `product_id`, `name`, `description`, `category`, `brand`, `price`, `rating`, `review_count`, `in_stock`, `tags`, `created_at`, `updated_at`)
- `hits.total.value`와 반환 문서 수가 다를 수 있는 이유:
  `hits.total.value`는 query 조건에 **일치한 전체 문서 수**이고 `hits.hits`는 그중 실제로 **가져온 페이지**다.
  `size`가 반환 개수를 5로 제한하므로 10,000건이 일치해도 5건만 돌아온다.
  `total`은 "몇 건이 맞았나", `hits` 길이는 "몇 건을 받았나"로 서로 다른 질문에 답한다.
  `relation`이 `"eq"`면 정확한 수, `"gte"`면 `track_total_hits` 기본 상한(10,000)에서 잘린 하한값이다.
  이번엔 `"eq"`라 10,000이 정확한 값이다. 문서가 딱 10,000건이라 상한과 같지만 잘린 것이 아니다.

## (공통) 문제 2 — 반환 개수와 field 직접 구현

### API 전체 입력

```http
GET /products/_search
{
  "size": 3,
  "_source": ["product_id", "name", "price", "in_stock"],
  "query": { "match_all": {} }
}
```

### 결과 입력

- 반환 문서 수: `3`
- `_source`에 요구하지 않은 field가 포함됐는가: **아니다.** 반환된 세 문서의 key가 요청한 4개와 정확히 같았다.
  문제 1에서 12 field가 전부 돌아왔던 것과 대비된다.
- 검증한 문서 ID:

  | ID | name | price | in_stock |
  |---|---|---:|---|
  | `P-00003` | Morrow 실속형 오버핏 후드 | 27,700 | `false` |
  | `P-00004` | PeakRun 스마트 등산 스틱 | 145,200 | `true` |
  | `P-00008` | HappyTail 컴팩트 산책 리드줄 | 85,100 | `false` |

## (공통) 문제 3 — 정렬이 포함된 전체 조회 구현

### API 전체 입력

```http
GET /products/_search
{
  "size": 10,
  "_source": ["product_id", "name", "price"],
  "query": { "match_all": {} },
  "sort": [ { "price": "asc" } ]
}
```

### 결과 입력

- 첫 3개 문서의 ID와 `price`:
  - `P-00431` — 한끼연구소 프리미엄 드립백 커피 — `5,900`
  - `P-06599` — 온담 데일리 차 선물세트 — `5,900`
  - `P-06479` — FreshTable 스마트 무설탕 간식 — `5,900`
- 오름차순 여부: **그렇다.** 반환된 10건의 `price`가 단조 증가한다. 응답의 `sort` 배열이 `[5900]`처럼 나온다.
- 두 문서의 price가 같을 때 순서가 고정된다고 말할 수 있는가? 근거:
  **말할 수 없다. 그리고 이번엔 실제로 그 상황이 상위 3건에서 바로 나왔다.**
  1~3위가 전부 `5,900`원으로 동률인데, 정렬 key가 `price` 하나뿐이라 이 셋의 순서를 결정하는 근거가 없다.
  ES는 내부 문서 순서로 채우는데 이는 segment 병합·재색인·shard 배치에 따라 바뀔 수 있다.
  `products`는 3 primary shard라 shard별 결과를 합치는 과정에서 더 흔들릴 여지가 있다.

  동률이 흔하다는 것도 확인했다. `terms` 집계에 `min_doc_count: 2`를 걸었더니
  `16,900`원 9건, `23,200`원 9건, `30,800`원 9건이 나왔다.
  `price`가 100원 단위로 끊기는 정수라 10,000건 안에서 값이 자주 겹친다.

  순서를 고정하려면 유일한 값을 가진 field를 2차 정렬 key로 붙여야 한다.

  ```json
  "sort": [ { "price": "asc" }, { "product_id": "asc" } ]
  ```

## (개인) 문제 4 — 자기 index의 첫 Search API

### API와 결과 입력

```http
GET /scout-players-2627/_search
{
  "size": 5,
  "query": { "match_all": {} }
}
```

- 자기 index: `scout-players-2627-v1` (요청은 alias `scout-players-2627`로 보냄)
- `_count`: `6000` (`GET /scout-players-2627/_count` → `_shards.failed: 0`)
- `hits.total.value`: `6000`
- 반환 문서 수: `5`
- 판정과 근거: **통과.**
  `_count`와 `hits.total.value`가 6,000으로 일치하므로 `match_all`이 색인된 전 문서를 빠짐없이 세고 있다.
  반환 문서 수 5는 `size` 때문이며 일치 건수와 무관하다.
  `_count`는 개수만 세는 전용 API라 문서 본문을 가져오지 않고,
  `_search`는 개수(`total`)와 문서(`hits`)를 함께 주되 문서 쪽만 `size`로 잘린다는 차이가 있다.

## (개인) 문제 5 — 결과 카드 field 설계

스카우팅 리서처가 검색 결과 목록에서 "이 선수 상세를 열어볼까"를 판단하는 카드다.

### API와 결과 입력

```http
GET /scout-players-2627/_search
{
  "size": 3,
  "_source": ["player_id", "name", "club", "detailed_position", "preferred_foot"],
  "query": { "match_all": {} }
}
```

- 포함한 field와 이유:
  - `player_id` — 식별자. 같은 이름의 선수를 구분하고 상세 화면으로 이동하는 키다.
  - `name` — 제목 역할. 카드에서 사람이 가장 먼저 읽는 값이다.
  - `club` — 판단용. 어느 구단 소속인지가 영입 난이도를 좌우한다.
  - `detailed_position` — 판단용. 찾는 포지션이 아니면 여기서 바로 거른다.
  - `preferred_foot` — 판단용. Q1·Q2의 핵심 조건이라 검색 의도와 결과가 맞는지 카드에서 바로 확인된다.
  - 이 5개는 `docs/data-model.md`의 Q1 표시 field와 같은 집합에서 골랐고 전부 mapping에 실재한다.
- 제외한 field와 이유:
  - `scout_note` — 문장이라 카드 한 줄에 안 들어간다. 상세 화면이나 `highlight` 조각으로 보여줄 값이다 (6교시에서 다룬다).
  - `first_name`·`last_name` — `name`이 이미 둘을 합친 값이라 카드에서는 중복이다.
  - `appearances`·`minutes`·`goals`·`assists` — 상세 비교 지표다. 카드에 넣으면 4칸을 잡아먹는데 클릭 여부를 가르지 못한다.
  - `is_synthetic` — 데이터 출처 표시용 운영 field다. 사용자 판단과 무관하다.
- 실제 반환 문서 ID: `P-0001`, `P-0002`, `P-0003`
  - `P-0001` — `Niall Renner` / `Kingsmere FC` / `CM` / `오른발`
  - `P-0002` — `Idris Ashcroft` / `Elderfield Town` / `RB` / `오른발`
  - `P-0003` — `Emeka Renner` / `Northgate City` / `AM` / `오른발`
- 완료 판정: **통과.** 요청한 5개 외의 field가 응답에 없었고, 식별자·제목·판단 정보가 모두 포함됐다.
