#!/usr/bin/env bash
# macOS 포팅본 · 강사 배포 load-data.ps1 대응
# 로컬 검증 → index/mapping 존재 확인 → docker cp → _bulk → _count 순서를 그대로 따른다.
# index를 자동으로 만들지 않는다. 오류를 index 삭제로 해결하지 않는다.
# 사용: ./load-data.sh -k <Day1 docker 폴더> [-s 설정파일] [-m mapping파일] [-d 데이터파일]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="$HERE/../my-data-settings.ps1"
MAPPING="$HERE/../../../elasticsearch/index-create.json"
DOCKER_DIR=""
DATAFILE=""
while getopts "k:s:m:d:" opt; do
  case "$opt" in
    k) DOCKER_DIR="$OPTARG" ;;
    s) SETTINGS="$OPTARG" ;;
    m) MAPPING="$OPTARG" ;;
    d) DATAFILE="$OPTARG" ;;
    *) echo "사용: $0 -k <docker 폴더> [-s 설정파일] [-m mapping파일] [-d 데이터파일]" >&2; exit 2 ;;
  esac
done
[ -n "$DOCKER_DIR" ] || { echo "-k <Day1 docker 폴더>가 필요합니다." >&2; exit 2; }

read_setting() { python3 -c "
import sys; sys.path.insert(0,'$HERE')
from pbl_generator import load_settings
print(load_settings('$SETTINGS')['$1'])
"; }
INDEX_NAME="$(read_setting IndexName)"
DOC_COUNT="$(read_setting DocumentCount)"
[ -n "$DATAFILE" ] || DATAFILE="$HERE/../generated/${INDEX_NAME}-${DOC_COUNT}.ndjson"
[ -f "$DATAFILE" ] || { echo "Bulk 데이터 파일이 없습니다: $DATAFILE" >&2; exit 1; }

"$HERE/validate-data.sh" -s "$SETTINGS" -m "$MAPPING" -d "$DATAFILE"

# .env는 CRLF일 수 있다. \r을 반드시 제거한다 (붙어 있으면 401이 나는데 화면상 값은 멀쩡해 보인다).
ENV_FILE="$DOCKER_DIR/.env"
[ -f "$ENV_FILE" ] || { echo ".env가 없습니다. Day 1 Docker 환경을 먼저 준비합니다." >&2; exit 1; }
ES_PASSWORD="$(grep '^ELASTIC_PASSWORD=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '\r\n')"
[ -n "$ES_PASSWORD" ] || { echo ".env에서 ELASTIC_PASSWORD를 찾지 못했습니다." >&2; exit 1; }
export ES_PASSWORD

CONTAINER="$(docker compose -f "$DOCKER_DIR/docker-compose.yml" --project-directory "$DOCKER_DIR" ps -q es01)"
[ -n "$CONTAINER" ] || { echo "es01 컨테이너가 실행 중이지 않습니다. Day 1의 start.sh 후 다시 실행합니다." >&2; exit 1; }

# 비밀번호는 -e 이름만 넘겨 host 프로세스 인자에 남기지 않는다.
es() { docker exec -e ES_PASSWORD "$CONTAINER" sh -c "$1"; }
CURL='curl -sS --cacert config/certs/ca/ca.crt -u "elastic:$ES_PASSWORD"'

es "$CURL -f -o /dev/null 'https://localhost:9200/$INDEX_NAME/_mapping'" \
  || { echo "Target index/mapping is not available. Check T12; no automatic creation." >&2; exit 1; }

docker cp "$DATAFILE" "$CONTAINER:/tmp/pbl-bulk.ndjson" >/dev/null
BULK="$(es "$CURL -H 'Content-Type: application/x-ndjson' -X POST 'https://localhost:9200/_bulk?refresh=wait_for&filter_path=errors,items.*.error' --data-binary @/tmp/pbl-bulk.ndjson")"
echo "$BULK" | python3 -c "
import sys,json
r=json.load(sys.stdin)
if r.get('errors') is not False:
    print('Bulk 적재 실패:', json.dumps(r, ensure_ascii=False)[:2000]); sys.exit(1)
" || exit 1

COUNT="$(es "$CURL 'https://localhost:9200/$INDEX_NAME/_count'" | python3 -c "
import sys,json
r=json.load(sys.stdin)
if r['_shards']['failed'] > 0: raise SystemExit('Count validation failed')
print(r['count'])
")"
echo "PASS: Bulk item errors=false. Actual count=$COUNT, generated=$DOC_COUNT. Validate distribution separately."
[ "$COUNT" = "$DOC_COUNT" ] || echo "경고: 실제 건수가 생성 건수와 다릅니다. 기존 문서와 ID를 확인하되 자동으로 삭제하지 않습니다." >&2
