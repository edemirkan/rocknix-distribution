#!/usr/bin/env bash
set -euo pipefail
# usage: PROJECT=... DEVICE=... ARCH=... tools/list_deps.sh toolchain alsa-lib llvm:host

declare -A SEEN
QUEUE=("$@")
PKG_DIRS=()
WATCH_PATHS=()

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
  [ -n "$dir" ] && PKG_DIRS+=("$dir")

  # PKG_NEED_UNPACK is already-resolved paths (project/device overlays, stamp
  # deps) — not package names, and not necessarily package.mk-shaped. Watch
  # them as raw content, don't try to walk them as dependencies.
  need_unpack=$(echo "$info" | grep '^PKG_NEED_UNPACK=' | cut -d'"' -f2)
  for p in $need_unpack; do
    [ -d "$p" ] && WATCH_PATHS+=("$p")
  done

  case "$stage" in
    host)      deps=$(echo "$info" | grep '^PKG_DEPENDS_HOST=' | cut -d'"' -f2) ;;
    init)      deps=$(echo "$info" | grep '^PKG_DEPENDS_INIT=' | cut -d'"' -f2) ;;
    bootstrap) deps=$(echo "$info" | grep '^PKG_DEPENDS_BOOTSTRAP=' | cut -d'"' -f2) ;;
    *)         deps=$(echo "$info" | grep '^PKG_DEPENDS_TARGET=' | cut -d'"' -f2) ;;
  esac
  unpack_deps=$(echo "$info" | grep '^PKG_DEPENDS_UNPACK=' | cut -d'"' -f2)

  for d in $deps $unpack_deps; do
    [ "$d" = "$base" ] && continue
    QUEUE+=("$d")
  done
done

UNIQUE_PKG_DIRS=$(printf '%s\n' "${PKG_DIRS[@]}" | sort -u)
UNIQUE_WATCH_PATHS=$(printf '%s\n' "${WATCH_PATHS[@]}" | sort -u)

echo "Resolved package count: $(echo "$UNIQUE_PKG_DIRS" | grep -c .)" >&2
echo "Watch-path count: $(echo "$UNIQUE_WATCH_PATHS" | grep -c .)" >&2

printf '%s\n' "$UNIQUE_PKG_DIRS"
echo '---WATCH---'
printf '%s\n' "$UNIQUE_WATCH_PATHS"
