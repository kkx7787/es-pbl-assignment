# Day 2 데이터 모델

## V1-T09-P · 문서 단위

- 개인 index 이름: `scout-players-2627-v1` (alias `scout-players-2627`)
- 검색 결과 한 줄 / 문서 한 건의 의미: 스카우팅 검색 결과 목록에 표시되는 선수 한 명
- 업무 ID field / 예시 값: `player_id` / `P-0001`
- ES `_id`와 업무 ID 관계: 같은 값을 사용할 계획이지만 역할은 다르며 ES가 자동으로 동기화하지 않는다. `_id`는 문서를 찾아가는 주소이고 검색·집계·정렬의 대상이 아니므로, 같은 값을 `player_id`라는 일반 field로 한 번 더 저장한다.

## V1-T10-P · 질문 3개

| 번호 | 사용자 질문 | 검색어 | 조건 | 정렬 | 표시 field |
|---|---|---|---|---|---|
| Q1 | 왼발로 측면을 돌파하는 유형의 선수를 찾아줘. | 왼발 측면 돌파 | 없음 | 관련도순 | `player_id`, `name`, `club`, `detailed_position`, `preferred_foot`, `scout_note` |
| Q2 | 홈그로운 자격이 있는 22세 이하 왼발 선수 중 레프트윙을 볼 수 있는 선수를 보여줘. | 없음 | `age<=22`, `is_homegrown=true`, `preferred_foot=왼발`, `detailed_position=LW` 또는 `secondary_positions`에 `LW` 포함 | `age` 오름차순 | `player_id`, `name`, `club`, `age`, `detailed_position`, `secondary_positions` |
| Q3 | 2028-06-30 이전에 계약이 끝나는 선수를 만료가 빠른 순으로 보여줘. | 없음 | `contract_until<=2028-06-30` | `contract_until` 오름차순 | `player_id`, `name`, `club`, `contract_until`, `market_value_eur` |

Q1의 검색어는 `왼발 윙어`가 아니라 `왼발 측면 돌파`다. `scout_note`는 생성기 template `{{preferred_foot}} {{detailed_position}} 자원. 강점은 {{trait}}.`로 만들어지고 `{{detailed_position}}` 자리에는 `LW` 같은 약어가 들어가므로, `윙어`라는 한국어 낱말은 어느 문서에도 나타나지 않는다. 반면 `측면 돌파`는 `trait` 후보에 있는 값이라 실제로 색인된다.

대표 3건은 [`../data/sample-documents.json`](../data/sample-documents.json)에 저장한다.
선수명과 스카우팅 코멘트는 실제 스카우팅 리포트에서 볼 법한 형태로 작성했으며, 나이·홈그로운 자격·계약 만료일은 검색 조건 검증을 위해 구성한 합성 값이다. 실존 선수·실존 구단과 무관하며 모든 문서에 `is_synthetic: true`를 넣는다.

| 문서 | 포함/제외/경계 역할 | 연결 질문 | 예상과 field 근거 |
|---|---|---|---|
| `P-0001` | 정상 포함 | Q1, Q2, Q3 | `scout_note`가 `왼발 LW 자원. 강점은 측면 돌파.`라 Q1 검색어 세 token을 모두 담는다. 20세, 홈그로운, `preferred_foot=왼발`, `detailed_position=LW`, 계약 2027-06-30 |
| `P-0002` | 포함 경계 | Q2, Q3 | 세 경계를 한 문서로 검증한다. (a) 나이가 상한과 같은 22세 (b) 계약 만료일이 경계와 같은 2028-06-30 (c) `detailed_position=AM`이고 `secondary_positions`에만 `LW`가 있어 배열 조건을 검증. Q1에서는 `scout_note`가 `왼발 AM 자원. 강점은 전진 패스.`라 `측면`·`돌파`가 없어 검색어 세 token을 모두 만족하지 못한다 |
| `P-0003` | 제외 | Q1, Q2, Q3 | 오른발 센터백, 24세, 홈그로운 아님, 계약 2030-06-30. `scout_note`에 `왼발`·`측면`·`돌파`가 하나도 없어 세 질문 모두에서 빠진다 |

`P-0002`는 `preferred_foot=왼발`이라 template상 `scout_note`에도 `왼발`이 들어간다. 따라서 Q1을 "검색어의 모든 token을 요구"하는 형태로 실행해야 이 문서가 제외된다. token 하나만 걸려도 되는 기본 형태로 실행하면 `왼발` 하나로 낮은 관련도의 결과에 섞인다. 어느 쪽으로 정할지는 Day 3에서 실제 query를 작성하며 결정하고 그 결과를 `quality-test.md`에 기록한다.

## V1-T11-P · field 계약

| field | 예시 값 | 역할 | type | 질문 번호 | 선택 이유 |
|---|---|---|---|---|---|
| `player_id` | `P-0001` | 정확 비교·표시 | `keyword` | 공통 | 업무 ID 전체를 하나의 값으로 보존 |
| `first_name` | `Callum` | 정확 조건·집계 | `keyword` | 공통 | `name`을 만드는 재료이며 값 전체로 집계 |
| `last_name` | `Whitfield` | 정확 조건·집계 | `keyword` | 공통 | 성만으로 거르거나 집계할 때 값 전체가 필요 |
| `name` | `Callum Whitfield` | 전문 검색·표시·정렬 | `text` + `keyword` 서브필드 | 공통 | 이름 일부로 검색하려면 `text`, 이름순 정렬에는 `keyword`가 필요 |
| `club` | `Ashford United` | 정확 조건·집계·표시 | `keyword` + `text` 서브필드 | 공통 | 집계 버킷은 값 전체로, `Ashford` 부분 검색은 서브필드로 |
| `league` | `EFL Championship` | 정확 조건·집계 | `keyword` | 공통 | 리그별 집계 축 |
| `nationality` | `England` | 정확 조건·집계 | `keyword` | 공통 | 국적 전체 값으로 필터 |
| `detailed_position` | `LW` | 정확 조건·집계·표시 | `keyword` | Q2 | 주 포지션을 정확히 일치로 거름 |
| `secondary_positions` | `["ST","AM"]` | 정확 조건·표시 | `keyword` 배열 | Q2 | 소화 가능 포지션이 여러 개이므로 배열이 필요 |
| `preferred_foot` | `왼발` | 정확 조건·집계·표시 | `keyword` | Q2 | 값이 셋뿐(왼발/오른발/양발) |
| `age` | `20` | 범위·정렬·표시 | `short` | Q2 | 정수 나이의 범위 계산과 숫자 정렬 |
| `height_cm` | `178` | 범위·정렬 | `short` | 공통 | 값이 32,767 이하 |
| `is_homegrown` | `true` | 정확 조건·표시 | `boolean` | Q2 | 자격 있음과 없음을 두 상태로 구분 |
| `contract_until` | `2027-06-30T00:00:00Z` | 범위·정렬·표시 | `date` (format 미지정) | Q3 | 날짜 범위 계산과 날짜 정렬. 문자열이면 둘 다 불가 |
| `market_value_eur` | `6500000` | 범위·정렬·집계·표시 | `long` | Q3 | 억 단위를 넘어 `integer`(약 21억) 한계를 넘길 수 있음 |
| `appearances` | `34` | 범위·정렬·집계 | `short` | 공통 | 값이 32,767 이하 |
| `minutes` | `2210` | 범위·정렬·집계 | `integer` | 공통 | 시즌 출전 시간이 만 단위 |
| `goals` | `9` | 범위·정렬·집계 | `short` | 공통 | 값이 32,767 이하 |
| `assists` | `7` | 범위·정렬·집계 | `short` | 공통 | 값이 32,767 이하 |
| `trait` | `측면 돌파` | 정확 조건·집계 | `keyword` | Q1 | 강점 유형을 값 전체로 집계하며 `scout_note` 문장의 재료 |
| `scout_note` | `왼발 LW 자원. 강점은 측면 돌파.` | 전문 검색·표시 | `text` | Q1 | 스카우팅 코멘트를 분석한 token으로 검색 |
| `tags` | `["u23","loan-candidate"]` | 정확 조건·집계 | `keyword` 배열 | 공통 | 태그가 여러 개이며 값 전체로 집계 |
| `is_synthetic` | `true` | 정확 조건 | `boolean` | 공통 | 합성 데이터임을 문서 자체에 표시 |

- 배열/객체 여부: 배열은 `secondary_positions`와 `tags` 2개, 객체는 없다. 시즌 기록은 선수당 한 벌뿐이라 `stats` 객체를 두지 않고 `appearances`·`minutes`·`goals`·`assists`로 평탄하게 둔다. 객체를 없애면 `stats.goals` 대신 `goals`로 접근하게 되어 정렬·집계 표현이 단순해진다.
- 파생 field 제외: `league_tier`, `position`, `homegrown_type`, `seasons_registered_in_england`는 두지 않는다. 모두 다른 field에서 계산으로 얻을 수 있는 값인데 생성기는 field 사이의 종속을 표현하지 못해 독립 난수로 채워진다. 그러면 `league=Premier League`인데 `league_tier=4`처럼 서로 어긋나는 문서가 생긴다.
- 실존 구단명 제외: 같은 이유로 구단명도 가상 이름을 쓴다. 실존 구단명과 무작위 `league`를 조합하면 `Arsenal` / `EFL League Two` 같은 모순이 생긴다.
- 제외한 개인정보: 실존 선수의 이름, 생년월일, 실제 계약 조건, 실제 이적료, 연락처, 의료 기록
- 제외 이유: 세 검색 질문을 검증하는 데 필요하지 않으며 합성 선수 데이터만 사용한다.
- 자가 점검: 숫자는 JSON 문자열이 아닌 숫자, 홈그로운 여부는 문자열이 아닌 boolean, 날짜는 생성기가 내보내는 ISO 8601 문자열(`2027-06-30T00:00:00Z`), 소화 가능 포지션은 값 하나가 아닌 배열로 작성했다.
- 완전한 mapping: [`../elasticsearch/index-create.json`](../elasticsearch/index-create.json)

### 날짜 format 기록

`contract_until`에는 `format`을 지정하지 않는다. 생성기의 `date` Kind가 `2027-06-30T00:00:00Z` 형태를 내보내는데 `"format": "yyyy-MM-dd"`로 못 박으면 이 값이 거부되어 bulk 적재가 통째로 실패한다. format을 비워 두면 ES 기본값 `strict_date_optional_time||epoch_millis`가 적용되어 `2027-06-30`과 `2027-06-30T00:00:00Z`를 모두 받는다.

### 분석기 선택 기록

`scout_note`는 한국어이며 기본 `standard` 분석기를 쓴다. 공백으로 나뉜 `왼발 측면 돌파`는 `왼발`, `측면`, `돌파` 세 token으로 색인되어 Q1이 동작한다.
한국어 형태소 분석기 `nori`는 ES에 기본 포함되어 있지 않고 3개 node 전부에 설치한 뒤 재시작해야 하므로 이 과제 범위에서는 쓰지 않는다.
그 결과 `왼발잡이`처럼 붙여 쓴 복합어는 `왼발`로 찾히지 않는다. 이 한계는 `quality-test.md`의 경계 조건에 기록한다.
