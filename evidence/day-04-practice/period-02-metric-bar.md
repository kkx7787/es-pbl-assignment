# 2교시 연습 — Metric·Bar·Top values

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

- Dashboard 이름:
- 사용한 계산:
- 실제 Metric 값:
- 시간 범위:
- KQL/filter/control 상태:
- 정상/보류/오류와 이유:
- 캡처 파일:

## (공통·필수) 문제 2 — category Bar 제작

같은 Dashboard에 category별 상품 수 Bar를 만드세요.

- 그룹 field: `category`
- 그룹 방식: Top values
- Number of values: 8
- 값: Count of records
- 제목: `카테고리별 상품 수`

### 설정·결과 입력

- Bar 방향:
- x축 또는 category 차원:
- y축 또는 Metric:
- Number of values:
- 표시된 category 수:
- 각 category 값이 공통 기준과 일치하는가:
- 캡처 파일:

## (변형·필수) 문제 3 — Bar 방향 한 가지만 바꿔 비교

동일한 category·Count·Top 8을 유지하고 Bar 방향만 vertical과 horizontal로 바꿔 보세요.

방향은 `Style → Appearance → Bar orientation`에서 바꿉니다. 축 label 방향과 혼동하지 않습니다.

| 비교 | vertical | horizontal |
|---|---|---|
| category 이름 가독성 |  |  |
| 값 비교 속도 |  |  |
| 잘림·겹침 |  |  |

- 최종 선택:
- 선택 이유:
- 다른 설정을 동시에 바꾸지 않았는가:

## (진단·필수) 문제 4 — 막대가 하나만 남은 상황 복구

Bar에 `스포츠` 등 하나의 category만 보인다고 가정합니다. Dashboard에서 다음을 확인하고 원래 8개 category로 복구하세요.

1. category Control 선택값
2. 상단 filter pill
3. KQL
4. 시간 범위
5. Lens의 Top values 설정

### 진단 기록

- 보이던 category:
- 발견한 제한 조건:
- 제거 또는 초기화한 항목:
- 복구 후 막대 수:
- 복구 후 Metric 값:
- 원인이 없었다면 추가로 확인한 Lens 설정:
- 캡처 파일:

## (개인·선택 도전) 문제 5 — 내 범주 field로 Metric+Bar 설계

자기 데이터의 전체 규모 Metric과 범주별 Bar를 설계하거나 만드세요. 범주 field가 없으면 필요한 field를 설계합니다.

- 개인 index/Data View:
- 전체 규모가 의미하는 것:
- 범주 field:
- 실제 고유값 수:
- Top N 선택값과 이유:
- 예상 사용자 판단:
- 실제 제작 여부:
- 부족한 경우 필요한 field와 예시값:
- 캡처 또는 설계 문서 경로:

## 교시 완료 신호

- GREEN: Metric 20,000, category Bar 8개, 제목 2개, 비교·복구 기록 완료
- YELLOW: 패널은 있으나 값·Top N·제목 중 하나가 다름
- RED: Lens 저장 또는 Dashboard 복귀 불가
