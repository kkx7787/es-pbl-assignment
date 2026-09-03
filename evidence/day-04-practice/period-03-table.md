# 3교시 연습 — Table·Count·Average·정렬

- 필수 권장 시간: 40분
- 선택 도전: 5분
- 제출 상태 확인: 5분
- 시작 기준: 공통 Dashboard의 Metric과 category Bar 저장 완료
- 화면 순서: [Table 상세 가이드](../KIBANA_9_5_STEP_BY_STEP.md#7-패널-3--브랜드별-상품-수와-평균-가격-table)

## (공통·필수) 문제 1 — brand Table 제작

다음 세 열을 가진 Table을 만드세요.

1. `brand` Top values
2. Count of records
3. Average of `price`

Average는 `Metrics → Quick function → Average → Field: price`로 추가합니다. 열 Name은 `브랜드`, `상품 수`, `평균 가격`으로 지정합니다.

패널 제목은 `브랜드별 상품 수와 평균 가격`으로 저장합니다.

### 설정·결과 입력

- brand Number of values:
- 첫 번째 Metric과 label:
- 두 번째 Metric과 label:
- 표시된 행 수:
- 첫 3개 브랜드와 상품 수:
- 첫 3개 브랜드의 평균 가격:
- 캡처 파일:

## (변형·필수) 문제 2 — 정렬 기준 하나만 바꿔 비교

Table의 나머지 설정을 유지하고 다음 두 정렬을 비교하세요.

- 설정 A: 상품 수 내림차순
- 설정 B: 평균 가격 내림차순

| 비교 | 설정 A | 설정 B |
|---|---|---|
| 첫 번째 브랜드 |  |  |
| 첫 번째 상품 수 |  |  |
| 첫 번째 평균 가격 |  |  |

- 순서가 달라진 이유:
- “상품이 많은 브랜드”에 맞는 정렬:
- “평균 가격이 높은 브랜드”에 맞는 정렬:
- 최종 Dashboard에서 선택한 정렬과 이유:

## (진단·필수) 문제 3 — 평균만 보고 결론 내리는 오류 찾기

평균 가격이 높은 브랜드 하나를 선택하세요. 그 브랜드의 상품 수를 함께 확인하고 다음 질문에 답하세요.

- 선택한 브랜드:
- 평균 가격:
- 상품 수:
- 평균 가격만 보면 내릴 수 있는 결론:
- 상품 수를 함께 보면 추가로 필요한 주의:
- 현재 데이터로 말할 수 없는 것:
- Count와 Average를 함께 보여 줘야 하는 이유:

## (개인·필수) 문제 4 — 내 데이터의 정확한 값 비교 Table

자기 데이터에서 범주 field 하나와 숫자 field 하나를 선택해 Table을 설계하거나 만드세요.

- 사용자:
- 분석 질문:
- 행에 사용할 범주 field:
- Metric 1과 이유:
- Metric 2와 이유:
- Top N:
- 정렬 기준:
- 완료 기준:
- 실제 결과 또는 데이터 부족 상태:
- 캡처/설계 문서 경로:

## (선택 도전) 문제 5 — Table에 필요한 Metric 하나 추가

`rating` 또는 `review_count`처럼 실제 mapping에 있는 숫자 field 중 하나를 선택해 세 번째 Metric을 추가하고, 판단에 도움이 되는지 평가하세요.

- 추가한 field와 계산:
- 추가 전 질문:
- 추가 후 알 수 있는 것:
- 표가 너무 복잡해졌는가:
- 유지/제거 결정과 이유:

## 교시 완료 신호

- GREEN: 3열 Table, 정렬 비교, 평균 해석, 개인 Table 설계 완료
- YELLOW: Table은 있으나 Average·정렬·label 중 하나가 미완료
- RED: Table에 brand 행 또는 price 평균을 표시할 수 없음
