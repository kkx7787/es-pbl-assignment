# 8교시 실습 — 통합·개선·제출

## (공통) 문제 1 — 제공 코드로 통합 검색 검증

```http
GET /products/_search
{
  "size": 10,
  "_source": ["product_id", "name", "description", "category", "price", "rating", "in_stock"],
  "query": {
    "bool": {
      "must": [{
        "multi_match": {
          "query": "무선 이어폰",
          "fields": ["name^3", "description"]
        }
      }],
      "filter": [
        { "term": { "category": "전자기기" } },
        { "term": { "in_stock": true } },
        { "range": { "price": { "gte": 50000, "lte": 200000 } } }
      ]
    }
  },
  "sort": [{ "rating": "desc" }, { "price": "asc" }],
  "highlight": { "fields": { "name": {}, "description": {} } }
}
```

### 결과 입력

- `hits.total.value`:
- 상위 3개 ID:
- 세 filter 통과 여부:
- 1·2차 정렬 통과 여부:
- highlight 확인 결과:
- 관련/보류/무관 판정:

## (공통) 문제 2 — boost 개선 전후 직접 구현

`name`, `description`에서 `무선 이어폰`을 검색하는 boost 없는 요청과 `name^3` 요청을 각각 작성하세요. 다른 조건은 동일하게 유지하세요.

### 개선 전 API

```http

```

### 개선 후 API

```http

```

### 비교 결과

- 전/후 상위 3개 ID:
- 순위가 달라진 문서:
- 개선/보류/악화:
- 사용자 의도 근거:

## (공통) 문제 3 — 요구사항으로 최종 API 직접 구현

다음 요구사항만 보고 실행 가능한 Search API 전체를 작성하세요.

- index: `products`
- 검색어: `무선 이어폰`
- 검색 field: `name`, `description`; name을 더 중요하게 처리
- category: `전자기기`
- 재고 있는 상품만 포함
- 가격: 50,000원 이상 200,000원 이하
- 평점 높은 순, 가격 낮은 순
- 최대 10건
- 결과 카드 field와 검색어 highlight 포함

### API 전체 입력

```http

```

### 검증 결과

- 문제 1과 기능적으로 같은 조건인가:
- 다른 부분이 있다면 이유:
- 실제 실행 성공 여부:
- 상위 결과 검증:

## (개인) 문제 4 — 자기 검색 한 요소 개선

7교시에서 진단한 개인 검색 문제 하나를 선택해 query, field, boost, filter, sort, 검색어 중 한 요소만 변경하고 다시 실행하세요.

### 역할·검증 기준

- 같은 index·데이터·검색어·size를 유지합니다. 검색어를 바꾸는 실험이라면 나머지 요소를 유지합니다.
- 변경 전후 요청을 모두 보존합니다.
- hit 수가 아니라 사용자 의도와 조건 통과로 개선을 판정합니다.

### API와 결과 입력

```http

```

- 문제 / 추정 원인:
- 변경한 한 요소:
- 전/후 상위 3개:
- 개선/보류/악화와 근거:

## (개인) 문제 5 — 최종 재현·산출물 완성

자기 전문 검색·정확 조건·bool/filter 요청을 새 Console에서 다시 실행하고 다른 사람이 commit만으로 재현할 수 있게 정리하세요.

### 역할·검증 기준

- 루트 `requests.http`에 `V1-T17-P`~`V1-T21-P`를 정리합니다.
- `docs/quality-test.md`에 질문별 기대·실제·개선 근거를 작성합니다.
- `evidence/day-03-search.md`에 핵심 결과와 commit SHA를 기록합니다.

### 최종 입력

- 새 Console 재현 성공 여부:
- 전문 검색 요청 ID:
- 정확 조건 요청 ID:
- bool/filter 요청 ID:
- 품질표 경로:
- evidence 경로:
- 최종 commit SHA:
- 미완료 또는 재현 실패 항목:
