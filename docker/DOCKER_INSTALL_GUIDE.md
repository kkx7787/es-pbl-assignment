# Topic 07 학생교재 초안 — Docker 설치와 ES 3노드 실습환경

## 이 자료의 위치

- **수업 전 준비:** Docker Desktop 설치와 재부팅이 필요하면 수업 전날까지 완료한다.
- **1일 차 7교시:** 설치 상태 확인, 강사 제공 이미지 불러오기, 3노드 환경 시작
- **1일 차 8교시:** Kibana 접속, 버전·클러스터 노드 수 확인

> Docker 설치는 ES 실습의 본문이 아닙니다. 설치 또는 WSL 문제를 길게 해결하지 말고 강사에게 표시한 뒤, 준비된 예비 PC 또는 짝 실습으로 수업을 계속합니다.

## 1. 사전 조건

- Windows 11 64비트, WSL 2 사용 가능
- 실제 메모리 16GB 이상 권장, C 드라이브 여유 15GB 이상 권장
- BIOS/UEFI 가상화 기능이 켜져 있어야 함
- 학교 정책상 설치 권한이 없으면 수업 전에 담당자 또는 강사에게 알림

Docker Desktop은 WSL 2 백엔드를 기본으로 사용하며, Docker 공식 최소 조건은 8GB 시스템 메모리와 하드웨어 가상화입니다. [Docker Desktop Windows 설치 문서](https://docs.docker.com/desktop/setup/install/windows-install/)

## 2. Docker Desktop 설치

1. [Docker Desktop Windows 공식 설치 페이지](https://docs.docker.com/desktop/setup/install/windows-install/)에서 설치 파일을 직접 다운로드해 실행합니다. 강사는 설치 파일을 GitHub 배포 저장소에 넣지 않습니다.
2. 설치 화면에서 **WSL 2 기반 엔진 사용**을 선택합니다.
3. 설치가 끝나면 Docker Desktop을 시작하고 사용 약관을 수락합니다.
4. 재부팅 안내가 나오면 재부팅합니다.
5. PowerShell에서 아래를 실행합니다.

```powershell
wsl --version
docker version
docker compose version
```

`docker version`에 Server 정보가 보이고, `docker compose version`이 보이면 설치 확인이 끝납니다.

### WSL 오류가 날 때

관리자 PowerShell에서 아래 명령이 필요할 수 있습니다. 이 작업은 재부팅이 필요할 수 있으므로 강사 안내에 따라 진행합니다.

```powershell
wsl --install
wsl --update
```

## 3. `.env`를 먼저 만들고 교육용 비밀번호를 입력합니다

Compose 명령을 실행하기 전에 `.env.example`을 내 PC 전용 `.env`로 복사합니다.

```powershell
Copy-Item .env.example .env
```

그 다음 `.env` 파일을 열어 강사가 안내한 교육용 비밀번호를 아래 두 값의 `CHANGE_ME...` 부분에만 입력합니다.

- `ELASTIC_PASSWORD`
- `KIBANA_PASSWORD`

`STACK_VERSION`, 포트, 메모리 같은 다른 값과 `docker-compose.yml`은 수정하지 않습니다. `.env`는 GitHub에 올리거나 화면 공유에 노출하지 않습니다.

## 4. 이미지 내려받기와 YAML은 역할이 다릅니다

`docker-compose.yml`은 **어떤 컨테이너를 어떤 설정으로 실행할지 적은 설계도**입니다. 컨테이너를 실제로 시작하려면 ES와 Kibana **이미지**도 PC에 있어야 합니다.

이번 과정에서는 각 학생 PC가 공식 Elastic Registry에서 필요한 이미지를 직접 내려받습니다. 실습 패키지의 `docker` 폴더에서 아래를 한 번 실행합니다.

```powershell
.\pull-images.ps1
```

이 스크립트는 `docker compose pull`을 실행합니다. Compose 파일의 버전 값에 따라 아래 두 이미지를 받고, 이미지가 정상 준비되었는지 검사합니다. 컨테이너를 시작하지는 않습니다.

- `docker.elastic.co/elasticsearch/elasticsearch:9.5.0`
- `docker.elastic.co/kibana/kibana:9.5.0`

> 학교 네트워크에서 `docker.elastic.co`에 접속할 수 있어야 합니다. 접속이 막히면 학생은 임의로 다른 이미지를 쓰지 말고 강사에게 알립니다.

## 5. 실습환경 시작

실습 패키지의 `docker` 폴더에서 실행합니다.

```powershell
.\preflight.ps1
.\pull-images.ps1
.\start.ps1
```

### `start.ps1`이 실제로 하는 일

| 단계 | 내부 명령·기능 |
|---|---|
| 1 | `preflight.ps1`: Docker CLI·Engine·Compose·WSL·디스크 여유와 9200·5601 포트 사용 여부를 확인 |
| 2 | `docker image inspect ...:9.5.0`: ES·Kibana 이미지가 이미 불러와졌는지 확인 |
| 3 | `docker compose up --detach`: setup, es01, es02, es03, kibana 컨테이너를 백그라운드로 시작 |
| 4 | Compose의 healthcheck: 인증서 생성, ES 응답, Kibana 응답을 각 컨테이너가 확인 |

`setup` 컨테이너는 인증서를 생성하고 Kibana가 사용할 내부 계정을 준비합니다. 학생이 인증서 설정을 직접 수행할 필요는 없습니다.

### 포트 사용 중 오류가 날 때

`preflight.ps1`은 ES용 `9200`, Kibana용 `5601` 포트가 이미 사용 중인지 먼저 확인합니다. 다른 ES·Kibana·Docker 실습을 실행 중이면 `CHECK`가 표시되고 시작을 멈춥니다. 학생은 임의로 Compose 파일의 포트를 바꾸지 말고, 기존 실습을 종료할지 강사에게 문의합니다.

## 6. 버전·환경 정상 여부 확인

```powershell
.\status.ps1
```

이 스크립트는 아래 내용을 출력합니다.

1. Docker Engine과 Docker Compose 버전
2. `docker compose ps`의 컨테이너 상태
3. ES 클러스터 health 응답
4. ES 노드 목록

정상 기준은 아래와 같습니다. ES가 먼저 `green`이 된 뒤 Kibana가 추가로 20~60초 정도 준비될 수 있습니다. `status.ps1`의 `Kibana overall: available`이 보일 때 브라우저를 엽니다.

- Elasticsearch 이미지 태그가 `9.5.0`
- Kibana 이미지 태그가 `9.5.0`
- es01, es02, es03, kibana가 실행 중이거나 healthy
- cluster health 응답의 `number_of_nodes`가 `3`
- 노드 목록에 es01, es02, es03이 보임

그 다음 브라우저에서 `http://localhost:5601`을 열고, 강사가 제공한 수업용 계정으로 Kibana에 로그인합니다. ES API 통신은 TLS를 사용하며, Kibana 웹 화면은 외부가 아닌 `127.0.0.1` localhost에만 공개됩니다.

| 항목 | 수업용 값 |
|---|---|
| Kibana 로그인 계정 | `elastic` |
| 수업용 비밀번호 | 강사가 실습 패키지의 `.env`와 함께 별도 안내 |

수업용 비밀번호는 교육용 localhost 환경에서만 사용하며, 개인 계정·실무 계정·외부 서비스에는 재사용하지 않습니다.

Kibana Dev Tools에서 같은 결과를 다시 확인합니다.

```http
GET /

GET /_cluster/health

GET /_cat/nodes?v
```

`GET /` 응답에서는 `version.number`가 `9.5.0`인지 확인합니다. `GET /_cluster/health` 응답에서는 `status`가 `green`이고 `number_of_nodes`가 `3`인지 확인합니다. 각 field는 서로 다른 응답에 있으므로 한 요청의 결과만 보고 두 조건을 판단하지 않습니다.

## 6. 종료와 주의사항

수업 종료 후에는 다음만 사용합니다.

```powershell
.\stop.ps1
```

이 스크립트는 `docker compose down`을 실행합니다. 데이터 볼륨은 유지됩니다.

**`docker compose down -v`는 실행하지 않습니다.** 이 명령은 ES 데이터와 인증서 볼륨을 지울 수 있습니다. 환경 초기화는 강사 안내가 있을 때만 합니다.

### 환경 초기화가 필요한 경우

중간에 원인을 알 수 없는 오류가 반복되고 강사가 처음 상태로 되돌리도록 안내한 경우에만 아래를 실행합니다.

```powershell
.\reset.ps1
```

`RESET`을 정확히 입력해야 실행됩니다. `reset.ps1`은 현재 Docker Compose 프로젝트의 컨테이너·named volume·네트워크를 삭제하고 `.env`도 제거합니다. ES·Kibana 이미지는 다른 컨테이너가 사용 중이지 않을 때만 삭제합니다. 개인 PBL 저장소·강사 배포 저장소의 파일은 삭제하지 않습니다. 초기화가 끝나면 `.env.example`에서 `.env`를 다시 만든 후 `preflight → pull-images → start → status` 순서로 시작합니다.

## 7. 스스로 확인

- [ ] Docker Desktop이 실행 중이다.
- [ ] `docker version`, `docker compose version`이 정상 출력된다.
- [ ] `pull-images.ps1`로 이미지를 내려받았다.
- [ ] `start.ps1`로 3노드 ES와 Kibana를 시작했다.
- [ ] `status.ps1`에서 노드 3개를 확인했다.
- [ ] Kibana Dev Tools에서 ES·Kibana 버전과 클러스터 상태를 확인했다.
