# 1교시 연습 — Data View·Discover·KQL·데이터 준비 상태

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

- 선택한 Data View 이름:
- index pattern:
- time field:
- 확인한 7개 field:
- 사용한 절대 시간 범위:
- Discover 실제 문서 수:
- 정상/보류/오류:
- 판정 근거:
- 캡처 파일:

## (공통·필수) 문제 2 — KQL 적용 전후를 비교

Discover의 전체 20,000건 상태에서 다음 KQL을 실행하세요.

```text
in_stock : false
```

결과를 기록한 뒤 KQL을 지우고 전체 상태로 복구하세요.

### 비교 결과

| 확인 항목 | 적용 전 | 적용 후 | KQL 제거 후 |
|---|---:|---:|---:|
| 문서 수 |  |  |  |

- 적용 후 대표 문서 ID 2개:
- `in_stock` 값 확인:
- 복구 성공 여부:
- 캡처 파일:
- KQL이 데이터를 삭제한 것인가? 이유:

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

- 재현한 증상:
- 마지막 정상 상태:
- 확인한 항목과 순서:
- 발견한 원인:
- 수정한 내용:
- 수정 후 문서 수:
- 다음부터 먼저 확인할 항목:
- 캡처 파일:

## (개인·필수) 문제 4 — 내 데이터 준비 상태 카드

자기 index 또는 준비 중인 데이터에서 Dashboard 질문 하나를 정하고 필요한 field를 점검하세요. 개인 Data View가 아직 없다면 mapping·샘플 문서로 판단합니다.

### 개인 답안

- 내 주제:
- 한 문서가 의미하는 대상 또는 사건:
- Dashboard 사용자:
- 사용자가 내릴 판단:
- 첫 분석 질문:
- 필요한 field:
- 각 field의 mapping type:
- 실제 존재 여부:
- 데이터 문서 수:
- A 개인 데이터 사용 / B 공통 products 사용+보강 설계 / C 공통 실습+개인 청사진 중 선택:
- 선택 이유:
- 부족한 데이터와 다음 행동:

## (선택 도전) 문제 5 — 서로 다른 KQL 3개 설계

`products`에서 category, price, in_stock 중 서로 다른 field를 사용한 KQL 3개를 만들고, 한 번에 한 조건만 실행하세요.

| KQL | 질문 | 결과 수 | 대표 문서 | 조건 제거 후 20,000 복구 |
|---|---|---:|---|---|
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |

## 교시 완료 신호

- GREEN: 필수 1~4 완료, 마지막 상태 20,000, KQL/filter 없음
- YELLOW: 결과는 있으나 수치·시간·field 중 하나가 다름
- RED: Data View 또는 Discover에서 데이터를 확인할 수 없음
