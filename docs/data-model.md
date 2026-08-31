# 데이터 모델 초안

> Day 1 초안입니다. ES type은 **후보**이며, mapping은 Day 2에 실제로 설계·검증한 뒤 확정합니다.

## 1. 문서 단위

- **검색 결과 한 건은 무엇인가:** 선수 1명
- **이 문서 한 건이 사용자에게 보여 주는 정보:**
  이름, 소속 구단, 리그, 나이, 주 포지션, 주발, 홈그로운 여부, 계약 만료일

## 2. 대표 문서 예시

```json
{
  "player_id": "P2627-CHA-COV-0417",
  "name": "Callum Whitfield",
  "club": "Coventry City",
  "league": "EFL Championship",
  "league_tier": 3,
  "position": "FW",
  "detailed_position": "LW",
  "secondary_positions": ["ST", "AM"],
  "nationality": "England",
  "age": 21,
  "height_cm": 178,
  "preferred_foot": "left",
  "is_homegrown": true,
  "homegrown_type": "club-trained",
  "seasons_registered_in_england": 6,
  "contract_until": "2028-06-30",
  "market_value_eur": 6500000,
  "stats": {
    "appearances": 34,
    "minutes": 2210,
    "goals": 9,
    "assists": 7
  },
  "scout_note": "왼발 윙어. 안쪽으로 접어 들어가는 드리블과 왼발 슈팅이 강점. 수비 가담과 공중볼 경합은 약점.",
  "tags": ["left-footed", "inverted-winger", "u23"],
  "is_synthetic": true
}
```

> 이 문서는 검색 질문 2의 조건(22세 이하 · 홈그로운 · 왼발 · LW)을 모두 만족하는 예시다.

## 3. 핵심 field와 역할

| field | 예시 값 | 검색에서 맡는 역할 | ES type 후보 | 선택 이유 |
|---|---|---|---|---|
| `name` | Callum Whitfield | 전문 검색·표시 | `text` (+ `keyword` 서브필드) | 이름 일부나 철자가 틀려도 찾아야 하고, 정렬에는 정확한 값이 필요하다. |
| `scout_note` | 왼발 윙어. 안쪽으로… | 전문 검색 | `text` | 질문 1의 자유 검색 대상. 유일한 서술형 field다. |
| `club` | Coventry City | 정확 조건·집계 | `keyword` | 구단명이 단어로 쪼개지면 집계 버킷이 깨진다. |
| `league` | EFL Championship | 정확 조건·집계 | `keyword` | 리그별 요약이 Dashboard 질문 3의 축이다. |
| `detailed_position` | LW | 정확 조건·집계 | `keyword` | 값 집합이 닫혀 있고 정확 일치만 필요하다. |
| `secondary_positions` | ["ST", "AM"] | 정확 조건 | `keyword` 배열 | "LW도 볼 수 있는 선수"를 찾으려면 배열 안을 봐야 한다. |
| `preferred_foot` | left | 정확 조건·집계 | `keyword` | 값이 셋뿐이다(left/right/both). |
| `is_homegrown` | true | 정확 조건 | `boolean` | 참·거짓 하나로 끝나는 조건이다. |
| `age` | 21 | 범위·정렬 | `integer` | "22세 이하" 범위 질의와 나이순 정렬에 쓴다. |
| `market_value_eur` | 6500000 | 범위·정렬·집계 | `long` | 값이 커서 `integer` 범위를 넘길 수 있다. |
| `contract_until` | 2028-06-30 | 범위·정렬 | `date` | "2년 내 만료" 같은 상대 날짜 질의를 쓰려면 문자열이면 안 된다. |
| `stats.minutes` | 2210 | 정렬·집계 | `integer` | 출전 시간으로 실전 검증 여부를 가른다. |

> `secondary_positions`를 배열로 둔 이유: 질문 2의 "레프트윙을 볼 수 있는 선수"는
> 주 포지션이 LW인 선수뿐 아니라 LW를 소화 가능한 선수까지 포함해야 한다.
> `detailed_position` 하나만으로는 이 질문에 답할 수 없다.

## 4. 검색 질문과 field 연결

| 검색 질문 | 사용할 field | 확인할 역할 |
|---|---|---|
| "왼발 윙어" 코멘트 검색 | `scout_note`, `name` | 전문 검색 |
| 22세 이하 · 홈그로운 · 왼발 · LW | `age`, `is_homegrown`, `preferred_foot`, `detailed_position`, `secondary_positions` | 정확 조건·범위 |
| 리그별 홈그로운 유망주 분포 | `league`, `is_homegrown`, `age`, `detailed_position` | 집계 |

## 5. 제외할 데이터

- **수집하거나 저장하지 않을 개인정보:**
  실존 선수의 이름, 생년월일, 실제 계약 조건, 실제 이적료, 연락처, 의료 기록

- **제외 이유:**
  이 PBL은 검색 설계를 연습하는 과제이며 실존 인물의 정보가 필요하지 않다.
  선수 6,000건은 전부 규칙과 seed로 생성한 합성 데이터이고,
  모든 문서에 `is_synthetic: true`를 넣어 구분한다.
  구단명과 리그명만 실제 명칭을 쓰며, 이는 법인·조직명이라 개인정보에 해당하지 않는다.
  생성 후 실존 선수 명단과 대조해 이름이 겹치면 재생성한다.

---

> ES type은 아직 **후보**다. `text`와 `keyword` 중 무엇을 쓸지,
> 서브필드를 둘지는 Day 2에 실제 mapping을 만들고 검색을 돌려 본 뒤 확정한다.
