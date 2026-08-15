#!/usr/bin/env bash
set -euo pipefail
# usage: PROJECT=... DEVICE=... ARCH=... tools/list_deps.sh toolchain alsa-lib llvm:host

declare -A SEEN
QUEUE=("$@")
DIRS=()

while [ ${#QUEUE[@]} -gt 0 ]; do
  pkg="${QUEUE[0]}"
  QUEUE=("${QUEUE[@]:1}")

  base="${pkg%%:*}"
  stage="target"
  case "$pkg" in
    *:host) stage="host" ;;
    *:init) stage="init" ;;
    *:bootstrap) stage="bootstrap" ;;
  esac

  key="${base}:${stage}"
  [ -n "${SEEN[$key]:-}" ] && continue
  SEEN[$key]=1

  info=$(tools/pkginfo "${base}" 2>/dev/null) || continue

  dir=$(echo "$info" | grep '^PKG_DIR=' | cut -d'"' -f2)
  [ -n "$dir" ] && DIRS+=("$dir")

  case "$stage" in
    host)      deps=$(echo "$info" | grep '^PKG_DEPENDS_HOST=' | cut -d'"' -f2) ;;
    init)      deps=$(echo "$info" | grep '^PKG_DEPENDS_INIT=' | cut -d'"' -f2) ;;
    bootstrap) deps=$(echo "$info" | grep '^PKG_DEPENDS_BOOTSTRAP=' | cut -d'"' -f2) ;;
    *)         deps=$(echo "$info" | grep '^PKG_DEPENDS_TARGET=' | cut -d'"' -f2) ;;
  esac

  for d in $deps; do
    [ "$d" = "$base" ] && continue   # guard self-referencing entries (e.g. toolchain)
    QUEUE+=("$d")
  done
done

printf '%s\n' "${DIRS[@]}" | sort -u
