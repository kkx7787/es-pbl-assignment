#!/usr/bin/env bash
#
# start.sh — macOS 포팅 (start.ps1)
#
# 사용법:
#   chmod +x start.sh
#   ./start.sh                    # 사전 점검 후 시작
#   ./start.sh --skip-preflight   # 이미 떠 있는 상태에서 재시작할 때
#
set -uo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKIP_PREFLIGHT=0
for arg in "$@"; do
  case "$arg" in
    --skip-preflight) SKIP_PREFLIGHT=1 ;;
    -h|--help)
      sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "알 수 없는 옵션: $arg" >&2
      exit 1 ;;
  esac
done

die() { echo "$*" >&2; exit 1; }

# ─────────────────────────────────────────────
# .env 확인
# ─────────────────────────────────────────────
[ -f .env ] || die '.env가 없습니다. 강사가 제공한 실습 패키지의 .env를 이 폴더에 둡니다.'

# ─────────────────────────────────────────────
# 사전 점검
# ─────────────────────────────────────────────
if [ "$SKIP_PREFLIGHT" -eq 1 ]; then
  echo '사전 점검을 건너뜁니다 (--skip-preflight).'
else
  [ -f ./preflight.sh ] || die 'preflight.sh 가 이 폴더에 없습니다.'
  if [ ! -x ./preflight.sh ]; then
    chmod +x ./preflight.sh 2>/dev/null || die 'preflight.sh 에 실행 권한을 줄 수 없습니다: chmod +x preflight.sh'
  fi

  if ! ./preflight.sh; then
    echo '' >&2
    echo '사전 점검을 통과하지 못했습니다. 위 CHECK 항목을 해결한 후 다시 실행합니다.' >&2
    echo '' >&2
    echo '참고: 컨테이너가 이미 떠 있으면 포트 점검에서 걸립니다.' >&2
    echo '      그 경우는 ./start.sh --skip-preflight 로 실행하거나,' >&2
    echo '      docker compose down 후 다시 시도하세요.' >&2
    exit 1
  fi
fi

# ─────────────────────────────────────────────
# 스택 버전 (pull-images.sh 와 동일한 규칙)
# ─────────────────────────────────────────────
STACK_VERSION="$(
  grep -m1 '^STACK_VERSION=' .env 2>/dev/null \
    | cut -d= -f2- \
    | tr -d '"'"'"'[:space:]' \
    || true
)"
STACK_VERSION="${STACK_VERSION:-9.5.0}"

ES_IMAGE="docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}"
KIBANA_IMAGE="docker.elastic.co/kibana/kibana:${STACK_VERSION}"

# ─────────────────────────────────────────────
# 이미지 존재 확인
#   원본의 try/catch 는 PowerShell 5.1에서 동작하지 않는다.
#   네이티브 명령(docker)의 비-0 종료코드는 catch로 잡히지 않아서,
#   이미지가 없어도 그냥 통과해 버린다. 여기서는 종료코드를 직접 본다.
# ─────────────────────────────────────────────
for image in "$ES_IMAGE" "$KIBANA_IMAGE"; do
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    die "ES 또는 Kibana 이미지가 없습니다 (없는 이미지: ${image}).
인터넷 연결 상태에서 ./pull-images.sh 를 먼저 한 번 실행합니다."
  fi
done

# ─────────────────────────────────────────────
# 시작
# ─────────────────────────────────────────────
echo '3노드 Elasticsearch와 Kibana를 시작합니다. 최초 실행은 인증서 생성 때문에 시간이 더 걸릴 수 있습니다.'

if ! docker compose up --detach; then
  die '컨테이너 시작에 실패했습니다. 오류 메시지를 확인하고 강사에게 알립니다.'
fi

echo ''
echo '시작 요청이 완료되었습니다. ./status.sh 로 상태를 확인하고, http://localhost:5601 을 엽니다.'
echo ''
echo '  (3노드 기동과 인증서 생성에 보통 1~3분 걸립니다.'
echo '   바로 status.sh 를 돌리면 아직 준비 중으로 나오는 게 정상입니다.)'
