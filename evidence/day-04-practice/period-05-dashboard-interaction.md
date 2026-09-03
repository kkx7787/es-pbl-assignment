# 5교시 연습 — Dashboard 조립·Control·Filter·KQL

- 필수 권장 시간: 42분
- 선택 도전: 3분
- 제출 상태 확인: 5분
- 시작 기준: 공통 필수 6패널 완성
- 화면 순서: [패널 제목·배치](../KIBANA_9_5_STEP_BY_STEP.md#11-dashboard-배치제목패널-메뉴), [Control](../KIBANA_9_5_STEP_BY_STEP.md#12-category-options-list-control), [Filter 복구](../KIBANA_9_5_STEP_BY_STEP.md#13-controlfilterkql-사용과-복구)

## (공통·필수) 문제 1 — 6패널을 읽는 순서로 배치

다음 원칙으로 Dashboard를 정돈하세요.

- 첫 행: 전체 규모 Metric
- 가운데: category 비교, 재고 비율, 월별 등록 등 핵심 차트
- 아래: 가격 분포와 정확한 값 Table
- 긴 label이 있는 패널은 넓게 배치
- 모든 패널 제목 표시

### 배치 기록

- Dashboard 제목:
- 첫 행 패널:
- 둘째 행 패널:
- 셋째 행 패널:
- 가장 크게 배치한 패널과 이유:
- 크기를 늘려 해결한 가독성 문제:
- 제목이 비어 있던 패널과 수정 결과:
- 캡처 파일:

## (공통·필수) 문제 2 — category Options list 추가

Dashboard 편집 모드에서 category Control을 추가하세요.

진입 순서: `Add`(안 보이면 `More → Add`) → `New → Controls → Control → Select a field`

- Data View: 공통 `products`
- field: `category`
- type: Options list
- label: `카테고리 선택`

category 하나를 선택한 뒤 두 패널 이상의 값이 바뀌는지 확인하고 `Any`로 복구하세요.

### 전후 기록

- 선택한 category:
- 적용 전 Metric:
- 적용 후 Metric:
- 함께 바뀐 패널 2개:
- `Any` 복구 후 Metric:
- 정상 여부:
- 캡처 파일:

## (진단·필수) 문제 3 — Control·Filter·KQL을 구분하고 초기화

다음 세 방식을 한 번씩 사용하세요. 한 방식을 확인한 뒤 반드시 지우고 다음으로 이동합니다.

1. category Control에서 값 선택
2. `Add filter`에서 `in_stock is false`
3. KQL에서 `price >= 100000`

| 방식 | 입력한 조건 | 적용 전 값 | 적용 후 값 | 해제 방법 | 해제 후 값 |
|---|---|---:|---:|---|---:|
| Control |  |  |  |  |  |
| Filter |  |  |  |  |  |
| KQL |  |  |  |  |  |

- 세 방식의 사용자가 느끼는 차이:
- 모든 조건 제거 후 전체값:
- `Filter for value` 문구가 없을 때 확인한 filter pill과 변한 패널:
- 캡처 파일:

## (공통·필수) 문제 4 — 목요일 종료용 저장·재열기

Dashboard를 `D4 공통 상품 Dashboard - 이름`으로 저장한 뒤 Dashboard 목록으로 나갔다가 다시 여세요.

### 저장·복구 기록

- 실제 저장 이름:
- 저장 시각:
- 다시 열기 성공 여부:
- 패널 수:
- Control 초기값:
- KQL/filter 상태:
- Metric 값:
- 다시 열었을 때 달라진 항목:
- 전체 화면 캡처:

## (선택 도전) 문제 5 — 30초 사용성 테스트

옆 학생에게 발표시키지 말고 다음 두 행동만 부탁하세요.

1. 가장 먼저 보이는 핵심값 찾기
2. category 하나 선택 후 원래 상태로 복구하기

- 상대가 처음 본 패널:
- 조건 선택 성공 여부:
- 복구 성공 여부:
- 상대가 멈춘 지점:
- 수정할 제목·배치·Control label:

## 교시 완료 신호

- GREEN: 6패널+Control, 세 조건 전후, 저장·재열기, 최종 20,000 완료
- YELLOW: 저장은 됐지만 조건이나 값이 초기화되지 않음
- RED: Dashboard를 저장하거나 다시 열 수 없음
