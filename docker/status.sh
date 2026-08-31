#!/usr/bin/env bash
#
# status.sh — macOS 포팅 (status.ps1)
#
# 사용법:
#   chmod +x status.sh
#   ./status.sh
#
# 진단용 스크립트이므로 -e 를 켜지 않는다.
# 한 섹션이 실패해도 나머지 섹션은 계속 출력해야 원인을 좁힐 수 있다.
set -uo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─────────────────────────────────────────────
# .env 에서 ELASTIC_PASSWORD 읽기
# ─────────────────────────────────────────────
if [ ! -f .env ]; then
  echo '.env가 없습니다.' >&2
  exit 1
fi

password_line="$(grep -m1 '^ELASTIC_PASSWORD=' .env 2>/dev/null || true)"
if [ -z "$password_line" ]; then
  echo '.env에서 ELASTIC_PASSWORD를 찾지 못했습니다.' >&2
  exit 1
fi

ELASTIC_PASSWORD="${password_line#ELASTIC_PASSWORD=}"

# CR 제거: Windows에서 만든 .env는 CRLF 줄바꿈이라
# 값 끝에 \r 이 붙는다. PowerShell의 Get-Content는 이걸 알아서 떼지만
# grep은 그대로 남겨서, 비밀번호가 "changeme\r" 이 되어 401이 난다.
ELASTIC_PASSWORD="${ELASTIC_PASSWORD%$'\r'}"

# 값 전체를 감싼 따옴표만 제거 (비밀번호 안의 따옴표는 보존)
case "$ELASTIC_PASSWORD" in
  \"*\") ELASTIC_PASSWORD="${ELASTIC_PASSWORD#\"}"; ELASTIC_PASSWORD="${ELASTIC_PASSWORD%\"}" ;;
  \'*\') ELASTIC_PASSWORD="${ELASTIC_PASSWORD#\'}"; ELASTIC_PASSWORD="${ELASTIC_PASSWORD%\'}" ;;
esac

if [ -z "$ELASTIC_PASSWORD" ]; then
  echo 'ELASTIC_PASSWORD 값이 비어 있습니다.' >&2
  exit 1
fi

CACERT='config/certs/ca/ca.crt'

# ─────────────────────────────────────────────
echo '=== Docker / Compose 버전 ==='
docker version --format 'Docker Engine: {{.Server.Version}}'
docker compose version

# ─────────────────────────────────────────────
printf '\n=== 컨테이너 상태 ===\n'
docker compose ps --all

# ─────────────────────────────────────────────
printf '\n=== Elasticsearch 클러스터 상태 ===\n'
health_json="$(
  docker compose exec -T es01 \
    curl -s --cacert "$CACERT" -u "elastic:${ELASTIC_PASSWORD}" \
    'https://localhost:9200/_cluster/health?pretty' 2>/dev/null
)"

if [ -z "$health_json" ]; then
  echo 'es01에서 응답이 없습니다. 컨테이너가 아직 기동 중이거나 죽었습니다.'
  echo '  docker compose logs --tail 50 es01'
else
  echo "$health_json"
fi

# ─────────────────────────────────────────────
printf '\n=== 노드 목록 ===\n'
docker compose exec -T es01 \
  curl -s --cacert "$CACERT" -u "elastic:${ELASTIC_PASSWORD}" \
  'https://localhost:9200/_cat/nodes?v' 2>/dev/null \
  || echo '노드 목록을 가져오지 못했습니다.'

# ─────────────────────────────────────────────
printf '\n=== Kibana 상태 ===\n'

# macOS에는 jq가 기본 설치되어 있지 않다. jq → python3 순으로 시도한다.
extract_kibana_level() {
  local json="$1"
  if command -v jq >/dev/null 2>&1; then
    echo "$json" | jq -er 'if .status.overall.level then "\(.status.overall.level) - \(.status.overall.summary)" else empty end' 2>/dev/null && return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    echo "$json" | python3 -c '
import json, sys
try:
    o = json.load(sys.stdin)["status"]["overall"]
    print(str(o["level"]) + " - " + str(o.get("summary", "")))
except Exception:
    sys.exit(1)
' 2>/dev/null && return 0
  fi
  return 1
}

kibana_json="$(
  docker compose exec -T kibana \
    sh -c "curl -s -u 'elastic:${ELASTIC_PASSWORD}' http://localhost:5601/api/status" 2>/dev/null
)"

if [ -n "$kibana_json" ] && overall="$(extract_kibana_level "$kibana_json")"; then
  echo "Kibana overall: $overall"
else
  echo 'Kibana가 아직 준비 중입니다. 20~30초 뒤 ./status.sh 를 다시 실행합니다.'
fi

# ─────────────────────────────────────────────
# 확인 기준 자동 판정
# ─────────────────────────────────────────────
printf '\n=== 판정 ===\n'
node_count="$(echo "${health_json:-}" | sed -n 's/.*"number_of_nodes"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)"
cluster_status="$(echo "${health_json:-}" | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p' | head -1)"

if [ "${node_count:-0}" -eq 3 ] 2>/dev/null; then
  echo "[PASS]  number_of_nodes = 3 (es01, es02, es03)"
else
  echo "[CHECK] number_of_nodes = ${node_count:-확인 불가} — 3이어야 정상입니다."
  echo "        노드가 부족하면 대개 메모리 부족입니다:"
  echo "        docker compose logs --tail 50 es02 es03"
fi

case "${cluster_status:-}" in
  green)  echo "[PASS]  cluster status = green" ;;
  yellow) echo "[CHECK] cluster status = yellow — 복제본 미할당. 노드 수를 먼저 확인하세요." ;;
  red)    echo "[CHECK] cluster status = red — 샤드 할당 실패." ;;
  *)      echo "[CHECK] cluster status = 확인 불가" ;;
esac

printf '\n확인 기준: number_of_nodes가 3이고 es01, es02, es03이 보이면 정상입니다.\n'
