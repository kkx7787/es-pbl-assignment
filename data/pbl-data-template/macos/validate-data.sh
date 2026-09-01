#!/usr/bin/env bash
# macOS 포팅본 · 강사 배포 validate-data.ps1 대응 (네트워크 접근 없음, 로컬 검사만)
# 사용: ./validate-data.sh [-s 설정파일] [-m mapping파일] [-d 데이터파일]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="$HERE/../my-data-settings.ps1"
MAPPING="$HERE/../../../elasticsearch/index-create.json"
DATAFILE=""
while getopts "s:m:d:" opt; do
  case "$opt" in
    s) SETTINGS="$OPTARG" ;;
    m) MAPPING="$OPTARG" ;;
    d) DATAFILE="$OPTARG" ;;
    *) echo "사용: $0 [-s 설정파일] [-m mapping파일] [-d 데이터파일]" >&2; exit 2 ;;
  esac
done
ARGS=(validate --settings-file "$SETTINGS" --mapping-file "$MAPPING")
[ -n "$DATAFILE" ] && ARGS+=(--data-file "$DATAFILE")
exec python3 "$HERE/pbl_generator.py" "${ARGS[@]}"
