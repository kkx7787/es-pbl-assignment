# Day 2 데이터 준비 결과

> 아래 값은 2026-09-01 macOS(Apple Silicon) / Docker Desktop / Elasticsearch 9.5.0 3-node 환경에서
> 실제로 실행한 출력이다. 공통 실습(쇼핑몰 products) 응답은 포함하지 않는다.

## 1. Index와 문서

- Index 이름: `scout-players-2627-v1` (alias `scout-players-2627`)
- 문서 한 건의 의미: 스카우팅 검색 결과 목록에 표시되는 선수 한 명
- 실제 색인 건수: **6,000건** (`GET /scout-players-2627/_count` → `{"count":6000,"_shards":{"failed":0}}`)
- Mapping의 `dynamic` 설정: **`strict`** (`GET /scout-players-2627-v1/_mapping` 응답에서 확인)
- shard 구성: `1 primary / 1 replica`, cluster status `green`
  (`GET /_cat/indices/scout-players-2627-v1?v` → `store.size 2.7mb`, `pri.store.size 1.3mb`로 복제본 존재 확인)

## 2. 최종 Field

23개다. 근거는 `docs/data-model.md`의 V1-T11-P 표에 있고, 여기에는 실제 색인된 type을 적는다.

| Field | Type | 검색에서 사용할 목적 |
|---|---|---|
| `player_id` | `keyword` | 업무 ID 정확 비교·표시 |
| `first_name` | `keyword` | `name`의 재료, 집계 |
| `last_name` | `keyword` | 성 단위 필터·집계 |
| `name` | `text` (`name_analyzer`) + `.keyword` | 이름 일부 검색 / 이름순 정렬 |
| `club` | `keyword` + `.text` | 구단별 집계 / 부분 검색 |
| `league` | `keyword` | 리그별 집계 축 |
| `nationality` | `keyword` | 국적 필터·집계 |
| `detailed_position` | `keyword` | Q2 주 포지션 정확 일치 |
| `secondary_positions` | `keyword` 배열 | Q2 소화 가능 포지션 포함 여부 |
| `preferred_foot` | `keyword` | Q2 주발 정확 조건 |
| `age` | `short` | Q2 나이 범위·정렬 |
| `height_cm` | `short` | 신장 범위·정렬 |
| `is_homegrown` | `boolean` | Q2 홈그로운 자격 |
| `contract_until` | `date` (format 미지정) | Q3 계약 만료 범위·정렬 |
| `market_value_eur` | `long` | 시장 가치 범위·정렬·집계 |
| `appearances` | `short` | 출전 수 범위·집계 |
| `minutes` | `integer` | 출전 시간 범위·집계 |
| `goals` | `short` | 득점 범위·집계 |
| `assists` | `short` | 도움 범위·집계 |
| `trait` | `keyword` | 강점 유형 집계, `scout_note` 재료 |
| `scout_note` | `text` (`standard`) | Q1 전문 검색 |
| `tags` | `keyword` 배열 | 태그 집계 |
| `is_synthetic` | `boolean` | 합성 데이터 표시 |

## 3. 대량 데이터 생성·색인 결과

- 생성 건수: **6,000건** (`$DocumentCount = 6000`, `$Seed = 20262027`, `$SampleCount = 30`)
- 로컬 검증 결과:
  `LOCAL CHECK PASS: 6000 documents, unique IDs, target index and NDJSON verified. This is not an Elasticsearch indexing result.`
- Bulk 색인 결과:
  `PASS: Bulk item errors=false. Actual count=6000, generated=6000.`
- ES 실제 `_count`: **6000** (`_shards.failed: 0`)
- 재현성: 같은 seed로 두 번 생성해 `cmp`로 비교했고 바이트 단위로 동일했다.

### 분류·숫자·boolean 분포 확인 결과

`POST /scout-players-2627/_search` (`size:0` + `terms`/`stats`/`missing` 집계)로 확인했다.

**분류 (`terms`)**

| Field | 실제 분포 | 설정과 대조 |
|---|---|---|
| `league` | Serie A 932, La Liga 926, Bundesliga 919, EFL L1 719, EFL L2 703, Championship 691, PL 612, PL U21 498 | 가중치 13/13/13/10/10/10/9/7 순서와 일치 |
| `preferred_foot` | 오른발 4,304 (71.7%) / 왼발 1,472 (24.5%) / 양발 224 (3.7%) | 가중치 72:24:4와 일치 |
| `detailed_position` | CB 630 … CM 580 (10종) | 균등 추첨, 편차 ±4% 이내 |
| `trait` | 탈압박 첫 터치 778 … 세트피스 처리 704 (8종) | 균등 추첨 |
| `nationality` | France 637 … England 571 (10종) | 균등 추첨 |
| `tags` | 6종 각 1,920~1,993 | 균등 추첨 |

**숫자 (`stats`)**

| Field | min | max | avg | 설정 범위 |
|---|---|---|---|---|
| `age` | 16 | 38 | 27.0 | 16~38 ✅ |
| `market_value_eur` | 223,829 | 89,975,240 | 45,261,334 | 200,000~90,000,000 ✅ |
| `minutes` | 0 | 3,419 | 1,686.2 | 0~3,420 ✅ |

**boolean / 결측 (`missing`)**

| 항목 | 실제 | 설정 |
|---|---|---|
| `is_homegrown` true | 2,035 (33.9%) | `TrueRatio = 0.35` ✅ |
| `secondary_positions` 없음 | 591 (9.8%) | `MissingRatio = 0.10` ✅ |
| `tags` 없음 | 177 (3.0%) | `MissingRatio = 0.03` ✅ |

전 항목이 설정값대로 나왔다.

## 4. Day 3 연결

- 검색 질문 기준: `docs/data-model.md`의 사용자 질문 3개
- Day 2 시점에 실제 index로 미리 확인한 건수 (Day 3에서 query를 확정하며 다시 기록한다):

| 질문 | 실행 형태 | 건수 |
|---|---|---|
| Q1 `왼발 측면 돌파` | `match` 기본(OR) | 2,019 |
| Q1 `왼발 측면 돌파` | `match` + `operator: and` | 169 |
| Q2 홈그로운·22세 이하·왼발·LW | `bool` filter | 35 |
| Q3 `contract_until <= 2028-06-30` | `range` | 1,551 |

- 분석기 확인: `POST /scout-players-2627/_analyze`, `standard`
  `왼발 LW 자원. 강점은 측면 돌파.` → `[왼발, lw, 자원, 강점은, 측면, 돌파]`
- 대표 3건은 본 index를 오염시키지 않기 위해 같은 mapping의 임시 index에 넣어 확인하고 삭제했다.
  결과: Q1(and) → `P-0001` / Q2 → `P-0001`,`P-0002` / Q3 → `P-0001`,`P-0002`. 설계한 포함·경계·제외 역할대로다.
  `P-0002`는 `scout_note`에 `왼발`이 들어가므로 기본 OR 매칭에서는 함께 나온다. Q1은 세 token을 모두 요구하는 형태로 쓴다.

## 5. 결과 파일 위치

- Mapping: `elasticsearch/index-create.json`
- 실행 요청: **미작성** — `requests.http`를 아직 만들지 않았다 (아래 7절)
- 대표 문서: `data/sample-documents.json`
- 데이터 생성 설정: `data/pbl-data-template/my-data-settings.ps1`
- 생성 표본: `data/pbl-data-template/generated/scout-players-2627-v1-sample-30.ndjson`
- 생성 요약: `data/pbl-data-template/generated/generation-summary.json`
- 생성·검증·적재 코드(macOS 실행본): `data/pbl-data-template/macos/`
- 전체 Bulk 파일 `scout-players-2627-v1-6000.ndjson`은 `.gitignore`로 제외했다. 한 번도 추적된 적 없다.

## 6. Pipeline 적용 판단

- 적용 / 미적용 / 보류: **미적용**
- 판단 이유:

`POST /_ingest/pipeline/_simulate`로 두 가지를 실제로 확인한 뒤 결정했다.

1. **파생값이 이미 생성 단계에서 만들어져 있다.** `name`을 `first_name`+`last_name`으로 다시 조립하고
   `club`을 `trim`하는 후보 pipeline을 실제 문서 `P-0001`에 `_simulate`했더니
   입력 `name = "Niall Renner"`, `club = "Kingsmere FC"` → 출력이 **입력과 완전히 같았다.**
   생성기 template이 이미 같은 일을 하고 있어 pipeline이 바꿀 것이 없다.
2. **`dynamic: strict`가 pipeline이 만든 새 field를 거부한다.**
   `set` processor로 `contract_year`를 추가하는 pipeline은 `_simulate`에서는 통과했지만,
   같은 문서를 실제로 색인하니 거부됐다:
   `strict_dynamic_mapping_exception - mapping set to strict, dynamic introduction of [contract_year] within [_doc] is not allowed`
   pipeline으로 field를 늘리려면 mapping을 먼저 고쳐야 하므로, pipeline만으로 얻는 이점이 없다.

- 처리 위치: **생성 단계**. `my-data-settings.ps1`의 `template` Kind가 `name`과 `scout_note`를 만든다.
- 원본 보존: 재료 field(`first_name`, `last_name`, `preferred_foot`, `detailed_position`, `trait`)를 모두 그대로 남겼다. 파생값을 지우고 재계산할 수 있다.
- 재검토 조건: 외부에서 받은 실제 스카우팅 데이터를 적재하게 되면 구단명 표기 통일·날짜 형식 정규화가 필요해지므로 그때 서버 pipeline을 다시 검토한다.
- 개인 pipeline 구현은 과제상 선택 항목이며 구현하지 않았다.

## 7. 미완료·오류

**현재 상태**

- 개인(P) 트랙 T09~T12, T15는 완료. T16은 적재·count·분포·pipeline 판단까지 했고 아래가 남았다.
- **T13-P 미완료**: 3입력 × 2분석방식 비교를 하지 않았다. `standard` 분석기로 1개 입력만 확인했다.
- **T14-P 미완료**: CRUD 실습(생성·조회·수정·삭제, 삭제 후 `found:false`, 출발 count 복귀)을 하지 않았다.
- **공통(C) 트랙**: Day 2 시점에는 미실행이었다. Day 3 실습을 진행하며 뒤늦게 처리했다 —
  `day-02/data/product-mapping.json`으로 `products` index를 만들고 `products-10000.ndjson`을 `_bulk`로 적재했다.
  `_count` 10,000, `green`, 3 primary + 1 replica, category 8종 × 1,250건으로 `generation-summary.json`과 일치한다.
  **아래 1~6절의 수치는 전부 개인 index `scout-players-2627`의 결과이며 공통 응답은 섞지 않았다.**
- **미작성 파일**: `requests.http`, `data/generation-notes.md`, `docs/pipeline-decision.md`
- `README.md`의 Day 2 절과 `SUBMISSION.md`의 이름·GitHub ID가 비어 있다.

**겪은 오류와 조치**

| 오류 | 조치 |
|---|---|
| `scout-players-2627-v1`이 `name`·`club` 2 field만 가진 채 남아 있었다 | 문서 0건임을 확인한 뒤 삭제하고 정본 mapping 23 field로 다시 만들었다. 데이터가 든 index를 지운 것이 아니다 |
| 강사 배포 스크립트가 전부 `.ps1`이고 `pwsh`가 없다 | Day 1 docker 스크립트와 같은 방식으로 `data/pbl-data-template/macos/`에 bash+python3 실행본을 만들었다. 배포 `.ps1`은 수정하지 않았다 |
| `brew install --cask powershell`이 동작하지 않는다 | cask가 없어졌다. 지금은 formula(`brew install powershell`)다. 이번에는 설치하지 않고 포팅본으로 진행했다 |

**검증하지 못한 것**

- 실제 PowerShell 배포본으로 생성한 결과와 macOS 포팅본 결과가 바이트 단위로 같은지는 확인하지 못했다.
  난수는 .NET `System.Random(seed)` 알고리즘을 재구현했으나 교차 검증할 `pwsh`가 없었다.
  따라서 `generation-summary.json`의 `bulk_sha256`은 포팅본 기준 값이다.

**다음에 할 작업**

1. T13 분석 실습 — 3입력 × `standard`/`name_analyzer` 두 방식, 예상 token을 먼저 적고 실제와 비교
2. T14 CRUD 실습 — 출발 count 6,000 기록 → 임시 문서 1건 생성·조회·수정·삭제 → `found:false` 확인 → count 6,000 복귀
3. 위 과정의 요청을 `requests.http`에 정리
4. `data/generation-notes.md`, `docs/pipeline-decision.md` 작성
5. `README.md` Day 2 절, `SUBMISSION.md` 기입
6. 공통(C) 트랙 진행 여부 결정
