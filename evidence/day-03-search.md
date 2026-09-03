# Day 3 검색 구현·품질 검증 산출물

> 공통 쇼핑몰 답을 복사하지 않고 자신의 PBL index와 실제 결과를 기록합니다. 실행하지 않은 결과는 완료로 표시하지 않습니다.

## 1. 실행 기준

- 개인 index: `scout-players-2627-v1` (alias `scout-players-2627`)
- 수업 시작 시 실제 `_count`: **6000** (`_shards.failed: 0`, 실습 종료 후에도 6000으로 변동 없음)
- 개인 요청 파일: `requests.http` (`V1-T17-P`~`V1-T20-P` 구간)
- 검색 품질 주 문서: `docs/quality-test.md`
- 교시별 실습 답안: `evidence/day-03-practice/period-01`~`period-08`
- 실행 환경·시각: macOS(Apple Silicon), Docker Desktop, Elasticsearch 9.5.0 3-node(cluster `green`), Kibana Dev Tools Console / 2026-09-02

## 2. 검색 질문과 요구사항

| 요청 ID | 사용자 질문 | 검색 field·검색어 | 정확 조건·범위 | 정렬 | 표시·highlight |
|---|---|---|---|---|---|
| Q01 전문 검색<br>`V1-T18-P` | 왼발로 측면을 돌파하는 유형의 선수를 찾아줘 | `scout_note`(text) · `왼발 측면 돌파`, `operator: and` | 없음 | 관련도순 | `player_id`,`name`,`club`,`detailed_position`,`preferred_foot` |
| Q02 정확 조건<br>`V1-T19-P` | 홈그로운 자격이 있는 22세 이하 왼발 선수 중 레프트윙을 볼 수 있는 선수 | 없음 | `age ≤ 22`, `is_homegrown = true`, `preferred_foot = 왼발`, `detailed_position = LW` 또는 `secondary_positions`에 `LW` | `age` asc → `player_id` asc | `player_id`,`name`,`club`,`age`,`detailed_position`,`secondary_positions` |
| Q03 bool/filter<br>`V1-T20-P` | 2028-06-30 이전에 계약이 끝나는 선수를 만료가 빠른 순으로 | 없음 | `contract_until ≤ 2028-06-30` | `contract_until` asc → `player_id` asc | `player_id`,`name`,`club`,`contract_until`,`market_value_eur` |

## 3. 실행 전 기대 기준

| 요청 ID | 기대 문서 ID·이유 | 제외 문서 ID·이유 | 의도한 0건 조건 | 경계 포함·제외 기준 |
|---|---|---|---|---|
| Q01 | `P-0024` — `왼발 ST 자원. 강점은 측면 돌파.`로 검색어 세 token을 모두 가짐 | `P-0001` — `오른발 CM 자원. 강점은 세트피스 처리.`로 세 token 중 하나도 없음 | `scout_note`에 야구 용어 `좌완 투수` 검색 | 세 token을 **모두** 요구(AND). 하나만 걸린 문서는 제외 |
| Q02 | `P-2948` — 16세, 홈그로운, 왼발, `detailed_position: LW` | `P-0001` — 홈그로운 `false`, `오른발`, `CM`/`CB`로 세 조건 불만족 | `age ≤ 15` 조건 추가 | `age`는 **22 포함**(`lte`). `secondary_positions`에만 LW가 있어도 포함 |
| Q03 | `P-2563` — `2027-06-30T01:00:35Z`로 가장 이른 만료 | `P-0548` — `2028-07-01T06:55:21Z`로 경계 하루 뒤 | 존재하지 않는 리그 `조기축구회` 필터 | `2028-06-30` **포함**(`lte`). 날짜만 준 값은 그날 마지막 순간으로 올림됨 |

## 4. 실제 결과와 판정

| 요청 ID | `hits.total.value` | 상위 3개 ID | 조건·경계 통과 | 관련/보류/무관과 근거 | 판정 |
|---|---:|---|---|---|---|
| Q01 | **169** | `P-0024`, `P-0039`, `P-0067` | 통과 — 기대 문서 `P-0024`가 1위, 제외 문서 `P-0001` 없음 | 상위 3건 **관련**. 셋 다 `왼발 … 강점은 측면 돌파.`(`_score` 모두 `5.752409`). `operator: and`로 세 token을 모두 요구해 기본 OR의 2,019건에서 169건으로 좁힌 결과다 | **통과** |
| Q02 | **35** | `P-0233`, `P-2948`, `P-5057` | 통과 — 셋 다 `age ≤ 22`·홈그로운·왼발. `P-5057`은 `detailed_position: CM`이지만 `secondary_positions`에 `LW` | 상위 3건 **관련**. 배열 조건이 실제로 작동함을 `P-5057`이 증명 | **통과** |
| Q03 | **1551** | `P-2563`, `P-0888`, `P-5345` | 통과 — 셋 다 `2027-06-30`. 경계 바깥 4,449건과 합쳐 정확히 6,000. `P-0548` 없음 | 상위 3건 **관련**. 만료 임박순이라 스카우팅 우선순위와 일치 | **통과** |

- 0건이 정답인 조건은 `docs/quality-test.md`의 경계 조건 표(7·8번)에서 별도로 확인했다.

## 5. 조건 제거·변형 실험

| 기준 요청 | 바꾼 한 요소 | 변경 전 total·대표 ID | 변경 후 total·새로 들어온/빠진 ID | 관찰한 역할 |
|---|---|---|---|---|
| Q01 | `operator` 기본(OR) ↔ `and` | OR **2,019** | AND **169** | `왼발`만 걸린 문서 1,850건이 빠졌다. 기본값이 OR이라는 것이 Q1 품질을 가르는 요소였다 |
| Q01 | `match` → `match_phrase` slop 0 | 169 | **0** | token 위치가 `왼발`=0, `측면`=4, `돌파`=5라 세 단어가 붙어 있지 않다. `slop: 3`으로 열면 169건으로 복귀하되 점수만 낮아진다(`2.20` vs `5.75`) |
| Q01 | `multi_match`에 `scout_note^3` boost | 716 (`측면 돌파`) `P-0010`,`P-0018`,`P-0023` | **716, 순위 동일** (`_score` `4.323388`→`12.970164`) | 점수만 정확히 3배가 됐다. `scout_note`와 `name`의 어휘가 겹치지 않아 boost가 순위를 바꿀 수 없다 |
| Q02 | `secondary_positions` 조건 제거 | 35 | **13** (22건 빠짐) | 부 포지션으로 LW를 소화하는 22명이 통째로 누락된다. 배열 field를 조건에 넣어야 하는 이유 |
| Q03 | `gte/lte` → `gt/lt` (4교시 `age` 기준) | 780 | **262** (518건 빠짐 = age 20의 238 + age 22의 280) | 경계 포함/제외의 차이. Q3·Q2가 "이하"이므로 `lte`여야 한다 |

## 6. 실패 원인 진단

- 문제: **`왼발 측면 돌파`를 기본 `match`로 실행하면 2,019건이 나오고, `왼발`만 걸린 문서가 대량 섞인다.**
  예: `왼발 CB 자원. 강점은 대인 방어.`처럼 `측면`·`돌파`가 없는 문서도 낮은 점수로 결과에 들어온다.
- 1차 원인 분류: **query**
- 확인한 실제 근거:
  - mapping 정상 — `scout_note`가 `text`이고 `_analyze` 결과가 `[왼발, lw, 자원, 강점은, 측면, 돌파]`로 기대대로 쪼개진다.
  - analyzer 정상 — 검색어 `왼발 측면 돌파`도 같은 분석기를 거쳐 세 token이 된다.
  - **원인은 query다.** `match`의 `operator` 기본값이 `or`라 token 하나만 걸려도 결과에 포함된다.
    `preferred_foot`이 `왼발`인 문서가 1,472건인데, `scout_note`가 생성기 template
    `{{preferred_foot}} {{detailed_position}} 자원. 강점은 {{trait}}.`를 따르므로
    주발이 항상 문장 첫 단어로 들어간다. 그래서 `왼발`만으로 걸리는 문서가 구조적으로 많다.
- 다음 확인 또는 변경: `operator`를 `and`로 바꿔 세 token을 모두 요구한다. 다른 요소는 건드리지 않는다.

## 7. 개선 전후

| 문제 | 추정 원인 | 변경한 한 요소 | 같은 조건으로 재실행한 결과 | 개선 판정과 근거 |
|---|---|---|---|---|
| `왼발 측면 돌파`에 `왼발`만 걸린 문서가 대량 포함 | query — `match`의 기본 `operator`가 OR | `operator: "and"` 명시. 검색어·field·`size`는 유지 | **2,019 → 169건.** 상위 3건 `P-0024`,`P-0039`,`P-0067`, `_score` 모두 `5.752409` | **개선.** 판정 근거는 건수가 아니라 상위 결과가 질문 의도에 맞는지다. 세 token을 모두 가진 문서만 남았고, 기대 문서 `P-0024`가 1위를 유지했으며 제외 대상 `P-0001`은 계속 결과에 없다 |

- 한계: `operator: and`는 "세 단어가 모두 있는 문서"만 남길 뿐, 그 단어들이 서로 맞는 조합인지는 보지 못한다.
  실제로 169건 안에는 `detailed_position`이 `GK`·`CB`인 문서도 들어 있다.
  `detailed_position`과 `trait`가 생성기에서 독립 난수로 뽑히기 때문이며 검색만으로는 해결되지 않는다.
  이 관찰은 기록만 하고 조치는 이후 교시로 미룬다.

## 8. 완료 체크

- [x] 전문 검색 요청 1개 — `V1-T18-P` (169건)
- [x] 정확 조건 요청 1개 — `V1-T19-P` (35건)
- [x] bool/filter 요청 1개 — `V1-T19-P` filter 4개, `V1-T20-P`
- [x] filter 2개 이상 — `age` 범위 · `is_homegrown` · `preferred_foot` · 포지션 `should`
- [x] sort 2개 — `age`+`player_id`, `contract_until`+`player_id`
- [ ] highlight 1개 — **미실시.** 6교시(T20 결과 표현)를 진행하지 않았다
- [x] 의도한 0건 요청 1개 — `docs/quality-test.md` 경계 조건 7·8번 (`total: 0`, `error` 없음)
- [x] 상위 3건 사람 평가 — 4절
- [x] 개선 1건과 전후 결과 — 7절 (2,019 → 169)
- [x] README의 기능 목록·실행 경로 동기화 — `README.md` 7절
- [x] 최종 commit SHA: `889216d` (`889216d4899838fd9e1fe3777cc1cef426493442`) — Day 3 산출물 커밋

## 미완료·이월

- **공통(C) 트랙:** `products` index를 10,000건으로 적재하고
  `evidence/day-03-practice/`의 공통 문제 24개를 제공 코드 그대로 실행했다
  (`green`, 3 primary + 1 replica, category 8종 × 1,250건, `_count` 10,000).
  개인 문제 16개는 자기 index에서 실행했으며 공통 응답을 개인 증거로 제출하지 않았다.
  **[2026-09-03]** Day 4가 `products` 20,000건을 기준으로 해서 같은 생성기·같은 seed로
  `-Count 20000` 재생성분 중 `P-10001`~`P-20000` 10,000건을 추가 적재했다(`docs.deleted: 0`, 순수 추가).
  적재 후 실측은 전체 20,000 / `in_stock:false` 3,001 / `true` 16,999 / category 8종 각 2,500으로
  Day 4 기준값과 일치한다. 1~4교시 공통 문제의 수치는 **10,000건 시점의 실제 결과**이므로 고치지 않았고,
  각 문제지 상단에 그 사실을 적었다.
- **Day 2 이월:** `V1-T13-P`(분석 3입력×2방식), `V1-T14-P`(CRUD)는 미실행이며
  `requests.http`에 `[미실행]`으로 표시했다. `data/generation-notes.md`,
  `docs/pipeline-decision.md`는 아직 작성하지 않았다.
- **미검증이었으나 해소됨 [2026-09-03]:** macOS 포팅본의 .NET `System.Random(seed)` 재구현이
  실제 PowerShell 생성기와 같은 결과를 내는지 확인하지 못하고 있었다.
  강사 배포 `generate-products.ps1`을 같은 방식으로 포팅해 `-Count 10000 -Seed 9502026`으로 돌린 결과,
  배포된 `products-10000.ndjson`과 **SHA256이 완전히 일치**했다
  (`9847ffeb7ee4b7a20d4a98bc7d6d993ddd0dcdba5d94a113d41e4f29c6516575`).
  맞추는 과정에서 두 가지를 확인했다 — PowerShell 파이프라인은 `Select-Object -First (식)`의 식을
  데이터가 흐르기 전에 평가하고, `[int]` 캐스트는 버림이 아니라 은행가 반올림(round-half-to-even)이다.
  같은 포팅본으로 `-Count 20000`을 만들면 Day 4 기준값(20,000 / 3,001 / 16,999 / 2,500)이 정확히 재현된다.
