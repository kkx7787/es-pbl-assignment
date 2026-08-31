#!/usr/bin/env bash
#
# preflight.sh — macOS 사전 점검 (preflight.ps1의 macOS 포팅)
#
# 사용법:
#   chmod +x preflight.sh
#   ./preflight.sh
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_check() {
  local name="$1" ok="$2" detail="$3"
  if [ "$ok" = "true" ]; then
    printf '[PASS]  %s - %s\n' "$name" "$detail"
  else
    printf '[CHECK] %s - %s\n' "$name" "$detail"
  fi
}

# ─────────────────────────────────────────────
# 1. Docker CLI
# ─────────────────────────────────────────────
if command -v docker >/dev/null 2>&1; then
  show_check 'Docker CLI' true 'docker 명령 사용 가능'
else
  show_check 'Docker CLI' false 'Docker Desktop 미설치 → brew install --cask docker'
  exit 1
fi

# ─────────────────────────────────────────────
# 2. Docker Engine 실행 여부
# ─────────────────────────────────────────────
if server_version="$(docker version --format '{{.Server.Version}}' 2>/dev/null)" && [ -n "$server_version" ]; then
  show_check 'Docker Engine' true "실행 중 (v${server_version})"
else
  show_check 'Docker Engine' false 'Docker Desktop 앱을 실행한 뒤 다시 시도'
  exit 1
fi

# ─────────────────────────────────────────────
# 3. Docker Compose
# ─────────────────────────────────────────────
if compose_version="$(docker compose version 2>/dev/null)"; then
  show_check 'Docker Compose' true "$compose_version"
else
  show_check 'Docker Compose' false 'Docker Desktop 최신 버전 확인 (compose v2 필요)'
  exit 1
fi

# ─────────────────────────────────────────────
# 4. CPU 아키텍처  ← 원본의 'WSL 2' 검사를 대체
#    Mac에는 WSL이 없음. 대신 arm64/amd64 이미지 이슈를 확인한다.
# ─────────────────────────────────────────────
arch="$(uname -m)"
if [ "$arch" = "arm64" ]; then
  show_check 'CPU 아키텍처' true 'Apple Silicon (arm64) — ES/Kibana arm64 네이티브 이미지 사용'
else
  show_check 'CPU 아키텍처' true "Intel ($arch)"
fi

# ─────────────────────────────────────────────
# 5. Docker Desktop 메모리 할당  ← Mac에서 추가로 필요한 검사
#    ES 8.x 단일 노드 + Kibana는 최소 4GB는 있어야 뜬다.
# ─────────────────────────────────────────────
mem_bytes="$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)"
mem_gb=$(( mem_bytes / 1024 / 1024 / 1024 ))
if [ "$mem_gb" -ge 4 ]; then
  show_check 'Docker 메모리' true "${mem_gb} GB (권장 4GB 이상)"
else
  show_check 'Docker 메모리' false "${mem_gb} GB — Docker Desktop > Settings > Resources 에서 4GB 이상으로 상향"
  exit 1
fi

# ─────────────────────────────────────────────
# 6. 디스크 여유 공간
#    C 드라이브 대신 홈 디렉터리 기준.
#    (Docker 이미지는 ~/Library/Containers/com.docker.docker 아래에 쌓인다)
# ─────────────────────────────────────────────
free_gb="$(df -g "$HOME" | awk 'NR==2 {print $4}')"
if [ "${free_gb:-0}" -ge 15 ]; then
  show_check '디스크 여유 공간' true "${free_gb} GB (권장 15GB 이상)"
else
  show_check '디스크 여유 공간' false "${free_gb} GB — 15GB 이상 확보 필요"
  exit 1
fi

# ─────────────────────────────────────────────
# 7. .env 에서 포트 읽기
# ─────────────────────────────────────────────
get_configured_port() {
  local var="$1" fallback="$2"
  local env_file="$SCRIPT_DIR/.env"
  [ -f "$env_file" ] || { echo "$fallback"; return; }

  local line
  line="$(grep -m1 "^${var}=" "$env_file" 2>/dev/null)" || { echo "$fallback"; return; }
  [ -n "$line" ] || { echo "$fallback"; return; }

  local value="${line#*=}"
  value="${value%\"}"; value="${value#\"}"      # 따옴표 제거
  value="$(echo "$value" | tr -d '[:space:]')"

  if [[ "$value" =~ :([0-9]+)$ ]]; then         # 127.0.0.1:9200 형태
    echo "${BASH_REMATCH[1]}"
  elif [[ "$value" =~ ^[0-9]+$ ]]; then         # 9200 형태  ← 원본은 이 케이스를 놓침
    echo "$value"
  else
    echo "$fallback"
  fi
}

# ─────────────────────────────────────────────
# 8. 포트 점유 확인
#    Get-NetTCPConnection → lsof
# ─────────────────────────────────────────────
test_port_available() {
  local port="$1" label="$2"
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    local proc
    proc="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -F c 2>/dev/null | sed -n 's/^c//p' | head -1)"
    show_check "$label" false "localhost:${port} 사용 중 (프로세스: ${proc:-unknown})"
    exit 1
  fi
  show_check "$label" true "localhost:${port} 사용 가능"
}

es_port="$(get_configured_port 'ES_PORT' 9200)"
kibana_port="$(get_configured_port 'KIBANA_PORT' 5601)"
test_port_available "$es_port" 'ES 포트'
test_port_available "$kibana_port" 'Kibana 포트'

printf '\n다음 단계: ./pull-images.sh 실행 후 ./start.sh\n'
