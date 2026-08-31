# Day 1 환경 확인 기록

```md
- 확인 일시: 2026-08-31 15:23
- 실행 환경: macOS (Apple Silicon), Docker Desktop
- Docker 상태: Elasticsearch 3개 node와 Kibana 컨테이너가 실행 중
- Kibana 접속: `http://localhost:5601` 접속 성공
- `GET /` 확인: version number가 `9.5.0`
- `GET /_cluster/health` 확인: status가 `green`
- `GET /_cat/nodes?v` 확인: node가 3개 표시됨
```