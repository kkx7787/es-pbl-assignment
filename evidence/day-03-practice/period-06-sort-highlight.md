# 6교시 실습 — 정렬·highlight

## (공통) 문제 1 — 제공 코드로 1·2차 정렬 확인

```http
GET /products/_search
{
  "size": 10,
  "_source": ["product_id", "name", "price", "rating", "in_stock"],
  "query": { "match": { "name": "무선" } },
  "sort": [
    { "rating": "desc" },
    { "price": "asc" }
  ]
}
```

### 결과 입력

- 상위 5개 ID / rating / price:
- 1차 정렬이 올바른가:
- rating 동률에서 2차 정렬이 적용된 사례:
- 동률이 없다면 2차 정렬을 확인할 수 있는 방법:

## (공통) 문제 2 — 정렬 우선순위 교환

문제 1과 같은 검색 결과를 가격이 낮은 순서로 먼저 정렬하고, 가격이 같으면 평점이 높은 순서로 정렬하세요.

### API 전체 입력

```http

```

### 비교 결과

- 변경 후 상위 5개 ID / price / rating:
- 순서가 달라진 문서:
- 검색 hit 집합도 달라졌는가:

## (공통) 문제 3 — highlight와 표시 field 구현

`name`, `description`에서 `무선 이어폰`을 검색하되 `name`에 3배 boost를 적용하세요. 최대 5건을 반환하고 결과 카드용 field만 `_source`에 포함하며 `name`, `description`에 highlight를 적용하세요.

### API 전체 입력

```http

```

### 결과 입력

- `_source` field 목록:
- highlight가 생성된 문서 ID와 field:
- `_source`와 highlight의 차이:
- highlight가 없는 hit가 있다면 이유 추정:

## (개인) 문제 4 — 자기 결과 정렬·카드 설계

자기 서비스에서 중요한 1차·2차 정렬 기준과 결과 카드 field 3~5개를 선택해 Search API를 구현하세요.

### 역할·검증 기준

- 정렬 가능한 mapping type을 사용합니다.
- 1차·2차 정렬의 업무적 이유를 설명합니다.
- 실제 상위 5개 값으로 순서를 검증합니다.

### API와 결과 입력

```http

```

- 정렬 field·방향·이유:
- 카드 field와 이유:
- 상위 5개 정렬 검증:

## (개인) 문제 5 — 자기 highlight 또는 표시 최적화

자기 text 검색에 highlight를 적용하세요. text 검색이 없는 프로젝트라면 `_source` 최소화 전후를 비교하세요.

### 역할·검증 기준

- 검색 field와 highlight field의 관계가 타당해야 합니다.
- 원본 데이터와 강조 조각을 구분합니다.
- 사용자 판단에 실제로 도움이 되는지 평가합니다.

### API와 결과 입력

```http

```

- 선택한 방식과 이유:
- 실제 결과:
- 사용자에게 유용한가:
- 개선할 점:
