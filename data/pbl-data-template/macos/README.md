# macOS 실행본

강사 배포 실습 패키지는 PowerShell(`.ps1`)이라 macOS에서 그대로 돌지 않는다.
Day 1에서 docker 스크립트를 bash로 옮긴 것과 같은 방식으로, Day 2 생성·검증·적재 스크립트를 옮겼다.

## 원칙

- **강사 배포 `.ps1` 파일은 수정하지 않는다.** `generator/generate-data.ps1`, `data-contract.ps1`,
  `validate-data.ps1`, `load-data.ps1`은 받은 그대로 두고, 이 폴더에 별도 구현을 만들었다.
- **설정 원본은 계속 `../my-data-settings.ps1` 하나뿐이다.** 설정을 JSON 등으로 복제하지 않았다.
  `pbl_generator.py`가 이 `.ps1` 파일을 직접 파싱한다. Windows에서 원본 `.ps1`을 돌려도 같은 설정이 쓰인다.

## 파일

| 파일 | 대응하는 배포본 | 하는 일 |
|---|---|---|
| `generate-data.sh` | `generator/generate-data.ps1` | 설정을 읽어 NDJSON 2개와 `generation-summary.json` 생성 |
| `validate-data.sh` | `validate-data.ps1` | 네트워크 없이 로컬 검사 (해시·줄 수·ID 중복·업무 ID와 `_id` 일치·mapping type) |
| `load-data.sh` | `load-data.ps1` | 로컬 검증 → index 존재 확인 → `docker cp` → `_bulk` → `_count` |
| `pbl_generator.py` | `generate-data.ps1` + `data-contract.ps1` | 위 둘의 실제 구현 |

## 실행

~~~bash
./generate-data.sh
./validate-data.sh
./load-data.sh -k /Users/hanseongmin/Desktop/es-pbl-assignment/docker
~~~

인자를 생략하면 설정은 `../my-data-settings.ps1`, mapping은 `../../../elasticsearch/index-create.json`을 쓴다.
`load-data.sh`의 `-k`는 Day 1 docker 폴더(= `.env`와 `docker-compose.yml`이 있는 곳)다.

## 배포본과 다른 점

- **난수**: 배포본은 .NET `System.Random(seed)`를 쓴다. 같은 알고리즘(subtractive lagged Fibonacci)을
  Python으로 재구현했고 규칙별 난수 소비 횟수와 순서도 맞췄다. 다만 이 환경에 `pwsh`가 없어
  **실제 PowerShell 실행 결과와 바이트 단위로 같은지는 교차 검증하지 못했다.**
  같은 seed로 이 스크립트를 다시 돌리면 항상 같은 파일이 나오는 것(재현성)은 확인했다.
- **`generation-summary.json`**: 배포본과 같은 key를 쓰되 `generator` key를 하나 더 넣어
  어떤 구현으로 만든 파일인지 남긴다.
- **비밀번호 취급**: `load-data.sh`는 `.env`의 `ELASTIC_PASSWORD`를 읽어 `docker exec -e` 로 이름만 넘긴다.
  값이 host 프로세스 인자에 남지 않는다. `.env`가 CRLF여도 되도록 `\r`을 제거한다.

## 배포본을 그대로 쓰려면

PowerShell을 설치하면 원본 `.ps1`을 쓸 수 있다. `brew install --cask powershell`은 더 이상 동작하지 않는다
(cask가 없어졌다). 지금은 formula다.

~~~bash
brew install powershell
~~~
