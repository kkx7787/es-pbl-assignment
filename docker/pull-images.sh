#!/usr/bin/env bash
#
# pull-images.sh — macOS 포팅 (pull-images.ps1)
#
# 사용법:
#   chmod +x pull-images.sh
#   ./pull-images.sh
#
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─────────────────────────────────────────────
# .env 확인
# ─────────────────────────────────────────────
if [ ! -f .env ]; then
  echo '.env가 없습니다. 강사가 제공한 실습 패키지의 .env를 이 폴더에 둡니다.' >&2
  exit 1
fi

# ─────────────────────────────────────────────
# 스택 버전 결정
#   .env에 STACK_VERSION이 있으면 그 값을, 없으면 9.5.0을 쓴다.
#   원본은 9.5.0을 세 군데에 하드코딩해서, .env 버전이 다르면
#   pull한 이미지와 검증 대상이 어긋난다.
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

echo "공식 Elastic Registry에서 ES와 Kibana ${STACK_VERSION} 이미지를 내려받습니다. 컨테이너는 아직 시작하지 않습니다."
docker compose pull

# ─────────────────────────────────────────────
# 다운로드 검증
# ─────────────────────────────────────────────
for image in "$ES_IMAGE" "$KIBANA_IMAGE"; do
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    echo "FAIL: ${image} 이미지를 찾을 수 없습니다." >&2
    echo "      docker-compose.yml의 image 태그가 ${STACK_VERSION} 인지 확인하세요." >&2
    exit 1
  fi
done

# ─────────────────────────────────────────────
# 아키텍처 확인 (Mac 전용 추가 검사)
#   Apple Silicon에서 amd64 이미지를 받으면 Rosetta 에뮬레이션으로
#   돌아가서 ES 기동이 눈에 띄게 느려지고 간헐적으로 실패한다.
# ─────────────────────────────────────────────
host_arch="$(uname -m)"
if [ "$host_arch" = "arm64" ]; then
  for image in "$ES_IMAGE" "$KIBANA_IMAGE"; do
    image_arch="$(docker image inspect --format '{{.Architecture}}' "$image" 2>/dev/null || echo unknown)"
    if [ "$image_arch" != "arm64" ]; then
      echo "WARN: ${image} 가 ${image_arch} 이미지입니다 (호스트는 arm64)." >&2
      echo "      docker-compose.yml에 'platform: linux/amd64' 가 있는지 확인하세요." >&2
      echo "      에뮬레이션으로 동작하며 기동이 느려집니다." >&2
    fi
  done
fi

echo "PASS: Elasticsearch ${STACK_VERSION} 및 Kibana ${STACK_VERSION} 이미지 다운로드가 완료되었습니다."
