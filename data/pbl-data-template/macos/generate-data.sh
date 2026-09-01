#!/usr/bin/env bash
# macOS 포팅본 · 강사 배포 generator/generate-data.ps1 대응
# 사용: ./generate-data.sh [-s 설정파일] [-m mapping파일] [-o 출력폴더]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="$HERE/../my-data-settings.ps1"
MAPPING="$HERE/../../../elasticsearch/index-create.json"
OUTDIR=""
while getopts "s:m:o:" opt; do
  case "$opt" in
    s) SETTINGS="$OPTARG" ;;
    m) MAPPING="$OPTARG" ;;
    o) OUTDIR="$OPTARG" ;;
    *) echo "사용: $0 [-s 설정파일] [-m mapping파일] [-o 출력폴더]" >&2; exit 2 ;;
  esac
done
ARGS=(generate --settings-file "$SETTINGS" --mapping-file "$MAPPING")
[ -n "$OUTDIR" ] && ARGS+=(--output-directory "$OUTDIR")
exec python3 "$HERE/pbl_generator.py" "${ARGS[@]}"
