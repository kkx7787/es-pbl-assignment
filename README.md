# PL Scout 26/27 — 프리미어리그 스카우팅 선수 검색

> Day 1 문서입니다. mapping 확정, 데이터 적재, Dashboard 결과는 Day 2~5에 실제로 수행한 뒤 추가합니다.

---

## 1. 프로젝트 소개

- **문제와 사용자:**
  프리미어리그 구단에서 하위 리그와 유스 자원을 검토하는 스카우팅 리서처가
  나이·홈그로운 자격·주발·소화 가능 포지션 조건으로 영입 후보를 좁힌다.
  지금은 리그별·구단별 스쿼드 페이지를 일일이 열어 눈으로 걸러야 하고,
  조건 하나가 바뀌면 처음부터 다시 봐야 한다.

- **ES로 검색할 문서 1건:**
  선수 1명

- **이 주제를 선택한 이유:**
  개인적으로 계속 따라가는 주제라 검색 결과가 맞는지 직접 판정할 수 있다.
  또 선수 데이터는 이름(전문 검색), 구단·포지션(정확 조건), 나이·시장가치(범위),
  계약 만료일(날짜), 홈그로운 여부(참·거짓)가 한 문서 안에 자연스럽게 들어 있어
  field 역할을 나누는 연습에 맞는다.

---

## 2. 검색 질문 초안

| 번호 | 사용자 질문 | 예상 조건 또는 결과 | 유형 |
|---:|---|---|---|
| 1 | "왼발 윙어" 같은 표현으로 스카우팅 코멘트를 검색하고 싶다. | 스카우팅 코멘트나 이름에 해당 표현이 포함된 선수 | 자유 검색 |
| 2 | 22세 이하이면서 홈그로운 자격이 있고, 왼발잡이로 레프트윙을 볼 수 있는 선수만 보고 싶다. | 나이 ≤ 22, 홈그로운 = 예, 주발 = 왼발, 소화 포지션에 LW 포함 | 조건 검색 |
| 3 | 홈그로운 자격이 있는 22세 이하 자원이 어느 리그에 몰려 있는지 알고 싶다. | 리그별 홈그로운 유망주 수 요약 | Dashboard |

> 위 표는 **Day 1 초안**이며 그대로 둔다.
> 1번 검색어는 Day 2에 `왼발 윙어` → **`왼발 측면 돌파`**로 바뀌었다.
> `scout_note`가 생성기 template의 `{{detailed_position}}` 자리에 `LW` 같은 약어를 넣기 때문에
> `윙어`라는 한국어 낱말이 어느 문서에도 없다. 근거는 `docs/data-model.md`,
> 확정된 질문과 실제 결과는 아래 7절과 `docs/quality-test.md`에 있다.

---

## 3. 결과에 보여 줄 값과 후보 조건

- **검색 결과 한 줄에 보여 줄 값:**
  이름, 소속 구단, 리그, 나이, 주 포지션, 주발, 홈그로운 여부, 계약 만료일

- **filter 후보:**
  리그, 소속 구단, 주 포지션, 주발, 홈그로운 여부

- **정렬 후보:**
  나이(오름차순), 출전 시간(내림차순), 시장 가치, 계약 만료일(오름차순 — 곧 풀리는 순)

---

## 4. Day 1 환경 확인

- Docker Desktop: 확인
- Kibana 접속: 확인
- Console 첫 요청: 확인

> 확인 결과는 `evidence/day-01-environment.md`에 기록합니다.

---

## 5. 실행 순서 — 재현 방법

macOS(Apple Silicon) 기준이다. 강사 배포 실습 패키지는 PowerShell(`.ps1`)이라 그대로 돌지 않아
`data/pbl-data-template/macos/`에 bash+python3 실행본을 만들어 두었다.
배포 `.ps1` 원본은 수정하지 않았고 설정 원본도 `my-data-settings.ps1` 하나뿐이다.

1. **Docker 환경 시작** — Day 1 docker 폴더에서 `./start.sh`.
   Elasticsearch 9.5.0 3-node(es01/es02/es03) + Kibana. `./status.sh`로 cluster status가 `green`인지 확인한다.
2. **index와 mapping 생성** — Kibana Dev Tools Console에서
   `GET /scout-players-2627-v1`로 존재를 먼저 확인하고, **없을 때만** `elasticsearch/index-create.json`
   전체를 body로 `PUT /scout-players-2627-v1`. 이어서 alias를 붙인다.
   요청 본문은 `requests.http`의 `V1-T12-P` 구간에 있다.
3. **데이터 생성·Bulk 적재**

   ```bash
   cd data/pbl-data-template/macos
   ./generate-data.sh
   ./validate-data.sh
   ./load-data.sh -k <Day1 docker 폴더 경로>
   ```

   seed가 `20262027`로 고정돼 있어 몇 번을 돌려도 바이트 단위로 같은 파일이 나온다.
4. **검색 요청 실행** — 루트 `requests.http`를 열어 요청을 **하나씩** Kibana Console에 복사한다.
   파일 전체를 실행하지 않는다. `V1-T09-P`~`V1-T16-P`가 Day 2, `V1-T17-P`~`V1-T20-P`가 Day 3다.
5. **Kibana Dashboard 확인** — Day 4에 작성

### 관련 파일

| 경로 | 내용 |
|---|---|
| `elasticsearch/index-create.json` | mapping 정본 (23 field) |
| `data/sample-documents.json` | 대표 3건 (포함/경계/제외) |
| `data/pbl-data-template/my-data-settings.ps1` | 생성기 설정 정본 |
| `data/pbl-data-template/macos/` | 생성·검증·적재 macOS 실행본 |
| `requests.http` | 개인 요청 모음 (`V1-T09-P`~`V1-T20-P`) |
| `docs/data-model.md` | 문서 단위·질문 3개·field 계약 |
| `docs/quality-test.md` | 검색 품질 점검표 |
| `evidence/day-02-data.md` | Day 2 실행 결과 |
| `evidence/day-03-search.md` | Day 3 실행 결과 |
| `evidence/day-03-practice/` | Day 3 교시별 실습 40문제 답안 |

---

## 6. 데이터와 mapping

- **문서 수:** 6,000건 (course 요건 최소 1,000 / 권장 5,000~10,000).
  실제 색인 `_count` = 6000, `_shards.failed: 0`, cluster `green`, 1 primary + 1 replica.
- **데이터 생성 규칙과 seed:** `$Seed = 20262027`, `$DocumentCount = 6000`, `$SampleCount = 30`.
  23개 field를 `id`/`choice`/`weighted_choice`/`integer`/`date`/`boolean`/`tags`/`template` 규칙으로 만든다.
  분포가 설정대로 나왔음을 집계로 확인했다 — `preferred_foot` 72:24:4 → 실측 71.7:24.5:3.7,
  `is_homegrown` `TrueRatio 0.35` → 실측 33.9%, `secondary_positions` 결측 0.10 → 실측 9.8%.
- **개인정보 미사용 확인:** 모든 선수 데이터가 합성이며 전 문서에 `is_synthetic: true`다.
  실존 선수의 이름·생년월일·계약 조건·이적료를 넣지 않았다.
  구단명도 가상 이름을 쓴다 — 실존 구단과 무작위 `league`를 조합하면
  `Arsenal / EFL League Two` 같은 모순이 생기기 때문이다.
- **핵심 필드와 타입 선택 이유:**
  - `"dynamic": "strict"` — mapping에 없는 field가 오면 문서를 거부한다. 생성 스크립트의 오타를 bulk 시점에 잡는다.
  - `name`은 `text`+`.keyword`, `club`은 `keyword`+`.text` — 주 용도가 반대다.
    `text`만으로는 정렬·집계가 안 되고 `keyword`만으로는 부분 검색이 안 된다.
  - `contract_until`은 `date`이고 **`format`을 지정하지 않는다.** 생성기가 ISO 8601을 출력하므로
    `"yyyy-MM-dd"`로 못 박으면 적재가 거부된다.
  - `secondary_positions`·`tags`는 `keyword` 배열. 값이 여러 개다.
  - `scout_note`는 `text`(`standard` 분석기). `nori`는 ES 기본 포함이 아니라 과제 범위 밖이다.
  - 파생 field(`league_tier` 등)는 두지 않는다. 계산으로 나오는 값을 독립 난수로 저장하면 정합성이 깨진다.
- **한계:** `appearances`/`minutes`/`goals`/`assists`가 서로 독립 난수라
  `appearances: 4`인데 `goals: 26`인 문서가 존재한다. 생성기가 field 간 종속을 표현하지 못한다.
- 전체 결과는 `evidence/day-02-data.md`, 설계 근거는 `docs/data-model.md`에 있다.

---

## 7. 검색·품질 테스트

| 검색 질문 | 기대 결과 | 실제 결과 | 판정 |
|---|---|---|---|
| **Q1** 왼발로 측면을 돌파하는 유형 (전문 검색, `V1-T18-P`) | `scout_note`에 `왼발`·`측면`·`돌파`가 모두 있는 선수. 오른발 중앙 수비수는 제외 | **169건.** 상위 3건 `P-0024`·`P-0039`·`P-0067` 전부 `왼발 … 강점은 측면 돌파.` 제외 대상 `P-0001` 없음 | **통과** (개선 후) |
| **Q2** 22세 이하·홈그로운·왼발·LW 소화 (정확 조건, `V1-T19-P`) | 네 조건을 모두 만족. 부 포지션으로 LW를 소화해도 포함 | **35건.** 상위 3건 `P-0233`·`P-2948`·`P-5057`. `P-5057`은 `detailed_position: CM`이지만 `secondary_positions`에 `LW`가 있어 포함 | **통과** |
| **Q3** 2028-06-30 이전 계약 만료 (범위·정렬, `V1-T20-P`) | 만료일이 경계 이하인 선수를 빠른 순으로 | **1,551건.** 상위 3건 전부 `2027-06-30`. 경계 바깥 4,449건과 합쳐 정확히 6,000 | **통과** |

**구현한 기능:** 전문 검색(`match` + `operator: and`), 정확 조건(`term`), 범위(`range`),
bool 결합(`filter`/`should` + `minimum_should_match`), 정렬 2단(동률 대비 2차 key), 0건이 정답인 경계 조건.

**개선 1건:** Q1을 기본 `match`로 실행하면 2,019건이 나오고 `왼발`만 걸린 문서가 대량 섞인다.
1차 원인은 query다 — `match`의 `operator` 기본값이 OR다.
`operator: "and"` **하나만** 바꿔 세 token을 모두 요구하니 **2,019 → 169건**이 됐고,
기대 문서 `P-0024`가 1위를 유지하면서 제외 대상 `P-0001`은 계속 결과에 없다.

> 점검표 전체는 `docs/quality-test.md`, 실행 결과는 `evidence/day-03-search.md`,
> 교시별 실습 답안은 `evidence/day-03-practice/`에 있다. **1~4교시까지 수행했고 5~8교시는 미실시다.**

---

## 이후 작성 예정

### 8. Dashboard — Day 4에 작성

- Dashboard 사용자:
- 차트 1이 답하는 질문:
- 차트 2가 답하는 질문:
- control/filter 목적:

> Day 1 계획은 `docs/dashboard-plan.md`에 있습니다.

### 9. AI Search 확장 판단 — Day 5에 작성

- 적용 여부와 근거:
