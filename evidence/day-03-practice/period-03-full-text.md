# 3교시 실습 — 전문 검색 확장

> **공통 문제**는 강사 배포 공통 index `products`(10,000건)에서 제공 코드 그대로 실행했다.
> `day-02/data/product-mapping.json`으로 index를 만들고 `products-10000.ndjson`을 `_bulk`로 적재했다
> (`green`, 3 primary + 1 replica, category 8종 × 1,250건).
> **개인 문제**는 자기 index `scout-players-2627`(6,000건)에서 실행했다.
> 실행 2026-09-02 / ES 9.5.0 3-node / 추측으로 채운 값은 없다.

## (공통) 문제 1 — 제공 코드로 여러 field 검색

```http
GET /products/_search
{
  "size": 5,
  "query": {
    "multi_match": {
      "query": "무선 이어폰",
      "fields": ["name", "description"]
    }
  }
}
```

### 결과 입력

- `hits.total.value`: `505`
- 상위 3개 ID·name (`_score` 모두 `6.7587247`):
  - `P-00241` — SoundLab 프리미엄 무선 이어폰
  - `P-00305` — Auralis 실속형 무선 이어폰
  - `P-00529` — NeoTech 스마트 무선 이어폰
- 각 문서가 name·description 중 어디에서 의도와 연결되는가: **전부 `name`이다.**
  세 문서의 `description`은 `재택 학습에 잘 어울리는 전자기기 상품입니다…`처럼
  용도 문구만 담고 있어 `무선`·`이어폰` token이 없다.
  각 field를 따로 검색해 확인했다 — `match name "무선 이어폰"` → **505건**,
  `match description "무선 이어폰"` → **0건**.
  즉 두 field를 걸었지만 실질적으로는 `name` 하나만 기여했다.
- 상위 3개 관련/보류/무관 판정: **3건 모두 관련.** 세 문서 다 실제 무선 이어폰 상품이고
  `category`도 `전자기기`다. 다만 `_score`가 셋 다 같아 이 셋의 상대 순위에는 근거가 없다.

## (공통) 문제 2 — field boost 직접 구현

### API 전체 입력

```http
GET /products/_search
{
  "size": 5,
  "query": {
    "multi_match": {
      "query": "무선 이어폰",
      "fields": ["name^3", "description"]
    }
  }
}
```

### 비교 결과

- 변경 전 상위 3개 ID: `P-00241`, `P-00305`, `P-00529` (`_score` `6.7587247`)
- 변경 후 상위 3개 ID: `P-00241`, `P-00305`, `P-00529` (`_score` `20.276176`)
- 순위가 달라진 문서: **없다.** total도 `505`로 동일하다.
- 관찰: 점수가 정확히 3배가 됐다 (`6.7587247 × 3 = 20.276174`).
  boost는 해당 field에서 나온 점수에 곱해지는 값이라,
  **한 field만 점수를 만들고 있으면 모든 문서에 같은 배수가 곱해져 상대 순위가 변하지 않는다.**
- boost가 사용자 의도에 유리했는가: **이 데이터에서는 효과가 없다.**
  문제 1에서 확인한 대로 `description`이 이 검색어에 0건을 기여한다.
  boost는 **같은 문서가 여러 field에서 걸릴 때 어느 field를 더 쳐줄지** 정하는 도구인데,
  그 상황 자체가 발생하지 않는다.
  `description`이 상품마다 다른 특징을 담고 있었다면 boost가 의미를 가졌을 것이다.

## (공통) 문제 3 — 구문 검색 직접 구현

### API 전체 입력

```http
GET /products/_search
{
  "size": 5,
  "_source": ["product_id", "name"],
  "query": {
    "match_phrase": {
      "name": { "query": "무선 이어폰", "slop": 0 }
    }
  }
}
```

### 결과 입력

- `hits.total.value`: `249`
- 상위 문서 ID·name (`_score` 모두 `6.758724`):
  - `P-00241` — SoundLab 프리미엄 무선 이어폰
  - `P-00305` — Auralis 실속형 무선 이어폰
  - `P-00529` — NeoTech 스마트 무선 이어폰
- 문제 1보다 결과가 같거나 줄어든 이유: **505 → 249로 절반 아래로 줄었다.**
  `multi_match`는 기본이 OR이라 `무선`만 있거나 `이어폰`만 있어도 걸린다.
  실제로 505건에는 `CleanMate 실속형 무선 청소기`처럼 **무선이지만 이어폰이 아닌** 상품이 섞여 있다
  (2교시 문제 2에서 확인).
  `match_phrase`는 두 token이 **이 순서로 바로 붙어 있을 것**을 요구하므로
  `무선 청소기`·`무선 마우스` 같은 상품이 전부 빠지고 실제 `무선 이어폰`만 남는다.
- 구문 의도에 맞지 않는 문서가 있는가: **없다.** 반환된 5건의 `name`이 모두 `… 무선 이어폰`으로 끝난다.
  검색 의도가 "무선인 것"이 아니라 "무선 이어폰"이라면 `match_phrase`가 더 정확한 선택이다.

## (개인) 문제 4 — 여러 text field 검색

### API와 결과 입력

```http
GET /scout-players-2627/_search
{
  "size": 5,
  "_source": ["player_id", "scout_note", "preferred_foot", "trait"],
  "query": {
    "match": { "scout_note": { "query": "왼발 측면 돌파", "operator": "and" } }
  }
}
```

- 사용자 질문·검색어: "왼발로 측면을 돌파하는 유형의 선수를 찾아줘." / `왼발 측면 돌파` (`docs/data-model.md` Q1)
- 선택 field와 역할: **`scout_note` 한 개만 썼다. `match`를 선택했다.**
  - `scout_note` — 스카우팅 코멘트. 주발·포지션·강점이 한 문장에 들어 있어 이 질문의 세 token이 모두 여기 있다.
  - `name` — 선수명. 사용자가 이름으로 찾을 때 쓰는 field지만 이 검색어와 어휘가 겹치지 않는다.
  - `club.text` — 구단명 부분 검색용. 역시 이 검색어와 무관하다.

  문제지가 허용한 대로 **한 field만 필요한 도메인이라 `multi_match`가 아니라 `match`를 골랐다.**
  근거는 자기 index에서 직접 확인한 결과다. `scout-players-2627`에
  `multi_match "측면 돌파" fields:["scout_note","name"]`을 걸면 **716건**(`_score` `4.323388`)이 나오는데,
  이는 `trait`가 `측면 돌파`인 문서 수와 정확히 같다. `name`은 `Marcus Okafor` 같은 영문 인명이라
  `측면`·`돌파` token을 가질 수 없어 점수에 전혀 기여하지 않는다.
  `scout_note^3`으로 boost를 줘도 **716건, 상위 3개 순서 그대로**이고 점수만 3배(`12.970164`)가 된다.
  기여하지 않는 field를 넣으면 요청만 복잡해지고 나중에 원인을 찾기 어려워진다.
- `hits.total.value`: `169`
- 상위 3개 판정: **3건 모두 관련** (`_score` 모두 `5.752409`)
  - `P-0024` — `왼발 ST 자원. 강점은 측면 돌파.`
  - `P-0039` — `왼발 CM 자원. 강점은 측면 돌파.`
  - `P-0067` — `왼발 RW 자원. 강점은 측면 돌파.`
- query 선택 근거: `operator: "and"`를 명시해 세 token을 **모두** 요구했다.
  기본값 OR로 두면 `왼발`만 걸린 문서까지 들어와 2,019건이 된다(2교시 개인 5 실측).
  사용자 질문이 "왼발"과 "측면 돌파"를 **동시에** 요구하므로 AND가 의도에 맞다.

## (개인) 문제 5 — boost 또는 phrase 가설 검증

**phrase 가설을 선택했다.** 같은 index·데이터·검색어(`왼발 측면 돌파`)·`size: 5`를 유지하고
query 종류 한 요소만 바꿨다.

### API와 결과 입력

```http
# 변경 전 (기준)
GET /scout-players-2627/_search
{
  "size": 5,
  "_source": ["player_id", "scout_note"],
  "query": { "match": { "scout_note": { "query": "왼발 측면 돌파", "operator": "and" } } }
}

# 변경 후 A — slop 0
GET /scout-players-2627/_search
{
  "size": 5,
  "_source": ["player_id", "scout_note"],
  "query": { "match_phrase": { "scout_note": { "query": "왼발 측면 돌파", "slop": 0 } } }
}

# 변경 후 B — slop 3
GET /scout-players-2627/_search
{
  "size": 5,
  "_source": ["player_id", "scout_note"],
  "query": { "match_phrase": { "scout_note": { "query": "왼발 측면 돌파", "slop": 3 } } }
}
```

- 선택한 가설: "세 단어가 구문으로 붙어 있는 문서가 더 정확할 것이다."
- 변경 전·후 상위 3개:

  | 요청 | total | 상위 3개 | `_score` |
  |---|---:|---|---|
  | `match` (and) | `169` | `P-0024`, `P-0039`, `P-0067` | `5.752409` |
  | `match_phrase` slop 0 | **`0`** | — | — |
  | `match_phrase` slop 3 | `169` | `P-0024`, `P-0039`, `P-0067` | `2.2014446` |

- 개선/보류/악화 판정: **악화(slop 0) / 보류(slop 3).**
- 판정 근거:
  `scout_note`는 `왼발 ST 자원. 강점은 측면 돌파.` 형태다. token 위치를 세면
  `왼발`=0, `st`=1, `자원`=2, `강점은`=3, `측면`=4, `돌파`=5다.
  검색어 `왼발 측면 돌파`는 세 token이 0,1,2에 연속으로 있기를 요구하는데
  실제로는 `왼발`과 `측면` 사이에 3개가 끼어 있다. 그래서 **slop 0에서 0건**이 된다.
  간격만큼 `slop`을 3으로 열어 주면 `match`(and)와 똑같은 169건이 나온다.

  즉 이 데이터에서 phrase는 **더 정확해지는 게 아니라 template의 고정된 어순에 의존하게 만든다.**
  template이 바뀌면(예: `강점은` 문구가 빠지면) 필요한 slop 값이 달라져 조용히 0건이 된다.
  단어 사이 거리를 조건으로 삼을 이유가 없으므로 **Q1은 `match` + `operator: and`를 유지한다.**
  slop 3이 `match`(and)와 건수가 같으면서 점수만 낮은 것도(`2.20` vs `5.75`) 얻는 게 없다는 근거다.
