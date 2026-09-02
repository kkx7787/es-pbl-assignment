# 2교시 실습 — term과 match

> **공통 문제**는 강사 배포 공통 index `products`(10,000건)에서 제공 코드 그대로 실행했다.
> `day-02/data/product-mapping.json`으로 index를 만들고 `products-10000.ndjson`을 `_bulk`로 적재했다
> (`green`, 3 primary + 1 replica, category 8종 × 1,250건).
> **개인 문제**는 자기 index `scout-players-2627`(6,000건)에서 실행했다.
> 실행 2026-09-02 / ES 9.5.0 3-node / 추측으로 채운 값은 없다.

## (공통) 문제 1 — 제공 코드로 정확 조건 확인

```http
GET /products/_search
{
  "size": 5,
  "query": { "term": { "category": "전자기기" } }
}
```

### 결과 입력

- `hits.total.value`: `1250`
- 상위 3개 문서 ID: `P-00009`, `P-00025`, `P-00081`
- 상위 3개 문서의 category: 세 건 모두 `전자기기`
  - `P-00009` NeoTech 데일리 기계식 키보드 / `P-00025` MobiCore 컴팩트 무선 이어폰 / `P-00081` NeoTech 스마트 기계식 키보드
- 모든 확인 문서가 정확 조건을 만족하는가: **그렇다.** `_source.category`가 전부 `전자기기`였다.
  세 문서의 `_score`가 `2.1181247`로 완전히 같은 것도 근거다. `term`은 조건을 만족/불만족으로만 가르므로
  일치한 문서끼리 점수 차이가 생기지 않는다.
  건수도 `generation-summary.json`의 `category_counts`(8종 각 1,250건)와 정확히 맞는다.
- `term`을 선택한 mapping 근거: `category`는 `keyword`다. `keyword`는 색인할 때 분석기를 거치지 않고
  `"전자기기"`라는 **값 전체가 하나의 token**으로 저장된다. 입력 문자열과 저장 token을
  글자 그대로 비교하는 `term`이 맞는 짝이다.

## (공통) 문제 2 — text 전문 검색 직접 구현

### API 전체 입력

```http
GET /products/_search
{
  "size": 5,
  "_source": ["product_id", "name"],
  "query": { "match": { "name": "무선" } }
}
```

### 결과 입력

- 선택한 query와 이유: **`match`.** `name`은 `text`(`korean_search` 분석기)라 색인 시 token으로 쪼개져 있다.
  `match`는 **검색어도 같은 분석기에 통과시킨 뒤** token끼리 비교하므로 색인 쪽과 질의 쪽 처리가 같아진다.
- `hits.total.value`: `505`
- 상위 3개 ID·name (`_score` 모두 `3.0212545`):
  - `P-00025` — MobiCore 컴팩트 무선 이어폰
  - `P-00042` — CleanMate 실속형 무선 청소기
  - `P-00129` — Auralis 스마트 무선 이어폰

## (공통) 문제 3 — 부적절한 조합 비교

### API 전체 입력

```http
GET /products/_search
{
  "size": 5,
  "_source": ["product_id", "name"],
  "query": { "term": { "name": "무선" } }
}
```

### 비교 결과

- 문제 2 total / 문제 3 total: **`505` / `505` — 같다.**
- 공통으로 나온 문서 ID: `P-00025`, `P-00042`, `P-00129` (상위 3개가 순서·점수까지 동일)
- 달라진 이유: **이 검색어에서는 달라지지 않았다.** 이유가 중요하다.
  `korean_search`는 `standard` 기반이라 공백·문장부호로 자르고 영문을 소문자로 바꾼다.
  `무선`은 한국어라 **소문자화의 영향을 받지 않고 자르는 지점도 없어서 색인된 token이 입력 문자열과 글자까지 똑같다.**
  `term`은 분석 없이 그대로 비교하는데 비교 대상이 우연히 일치하므로 `match`와 결과가 같아진다.
- `term`은 text에서 항상 0건인가? 실제 근거: **아니다.** 검색어가 색인된 token과 글자까지 같은지에 달렸다.
  같은 `name` field에 영문 브랜드명으로 확인했다.

  | query | 검색어 | total |
  |---|---|---:|
  | `term` | `Auralis` | **0** |
  | `term` | `auralis` | **263** |
  | `match` | `Auralis` | **263** |
  | `term` | `무선` | **505** |
  | `match` | `무선` | **505** |

  `name`의 `Auralis`는 분석기가 소문자로 바꿔 `auralis`로 색인된다. `term`에 `Auralis`를 넣으면
  저장된 `auralis`와 글자가 달라 0건이고, `auralis`를 넣으면 263건이 나온다.
  `match`는 검색어 `Auralis`도 소문자로 바꿔주므로 263건이다.
  즉 `term`이 text에서 위험한 이유는 "항상 0건이라서"가 아니라 **분석 결과를 사람이 직접 맞춰야 하고,
  그 규칙이 언어·field마다 달라 재현하기 어렵기 때문**이다.
  한국어 검색어로만 시험하면 이 함정을 못 보고 지나간다.

## (개인) 문제 4 — 자기 정확 조건 검색

### API와 결과 입력

```http
GET /scout-players-2627/_search
{
  "size": 5,
  "_source": ["player_id", "name", "preferred_foot", "detailed_position"],
  "query": { "term": { "preferred_foot": "왼발" } }
}
```

- field / type / 값: `preferred_foot` / `keyword` / `왼발`
- 사용자 질문: "왼발잡이 선수만 보여줘."
- `hits.total.value`: `1472`
- 상위 3개 ID와 실제 값:
  - `P-0005` Marcus Kowalski — `preferred_foot: "왼발"`, `RW`
  - `P-0021` Finley Moreau — `preferred_foot: "왼발"`, `LW`
  - `P-0024` Marcus Bankole — `preferred_foot: "왼발"`, `ST`
- 왜 전문 검색이 아니라 정확 비교인가: `preferred_foot`은 값이 `왼발`/`오른발`/`양발` 셋뿐인 닫힌 집합이고
  mapping type이 `keyword`다. 분석되지 않으므로 부분 일치·유사어라는 개념 자체가 없다.
  사용자도 "왼발과 비슷한 것"을 원하는 게 아니라 "왼발인 것"만 원한다. 조건은 참/거짓 하나다.
- 통과/실패와 근거: **통과.** 상위 3건의 `_source.preferred_foot`이 모두 `왼발`이었고
  `_score`가 `1.4049644`로 전부 동일해 관련도 차등 없이 조건 충족 여부만 판정됐음을 확인했다.

## (개인) 문제 5 — 자기 전문 검색

### API와 결과 입력

```http
GET /scout-players-2627/_search
{
  "size": 5,
  "_source": ["player_id", "scout_note", "preferred_foot", "trait"],
  "query": { "match": { "scout_note": "왼발 측면 돌파" } }
}
```

- field / type / 검색어: `scout_note` / `text` (`standard` 분석기) / `왼발 측면 돌파`
  - mapping 확인: `GET /scout-players-2627/_mapping` → `"scout_note": { "type": "text" }`
- `hits.total.value`: `2019`
- 상위 3개 ID: `P-0024`, `P-0039`, `P-0067` (`_score` 모두 `5.752409`)
- 관련/보류/무관과 이유: **상위 3건 모두 관련.**
  - `P-0024` — `왼발 ST 자원. 강점은 측면 돌파.` / `preferred_foot: 왼발`, `trait: 측면 돌파`
  - `P-0039` — `왼발 CM 자원. 강점은 측면 돌파.` / 동일
  - `P-0067` — `왼발 RW 자원. 강점은 측면 돌파.` / 동일

  세 건 모두 검색어의 세 token(`왼발`,`측면`,`돌파`)을 전부 포함해 점수가 가장 높다.
  다만 **total 2,019건은 전부 관련이라고 볼 수 없다.** `match`의 기본 동작이 OR이라
  `왼발`만 있고 `측면 돌파`는 없는 문서(예: `왼발 CB 자원. 강점은 대인 방어.`)도 낮은 점수로 섞인다.
  세 token을 모두 요구하면 `169`건이다(3교시 개인 5에서 실측). 이 격차가 7·8교시 개선 대상이다.
- 정확 조건 문제와 query 선택 이유의 차이: 문제 4의 `preferred_foot`은 값이 셋뿐인 `keyword`라
  "맞다/아니다"만 판정하면 된다. 문제 5의 `scout_note`는 자유 문장 `text`라 어느 단어가 몇 개
  걸렸는지에 따라 **얼마나 관련 있는지**를 점수로 매겨야 한다. 그래서 `term`이 아니라 `match`다.
- 완료 판정: **통과.** 요청이 성공했고 상위 3건이 검색 의도와 일치했다.
