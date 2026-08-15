#!/usr/bin/env bash
set -euo pipefail
# usage: PROJECT=... DEVICE=... ARCH=... tools/list_deps.sh toolchain alsa-lib llvm:host

declare -A SEEN
QUEUE=()
for a in "$@"; do QUEUE+=("${a}|walk"); done   # trigger packages: full walk
PKG_DIRS=()
WATCH_PATHS=()

while [ ${#QUEUE[@]} -gt 0 ]; do
  entry="${QUEUE[0]}"
  QUEUE=("${QUEUE[@]:1}")
  pkg="${entry%|*}"
  mode="${entry#*|}"   # "walk" = recurse into its deps, "leaf" = content-only

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

  need_unpack=$(echo "$info" | grep '^PKG_NEED_UNPACK=' | cut -d'"' -f2)
  for p in $need_unpack; do
    [ -d "$p" ] && WATCH_PATHS+=("$p")
  done

  # leaf entries (reached via PKG_DEPENDS_UNPACK) contribute their own
  # content but their dependency chain never actually builds — stop here.
  [ "$mode" = "leaf" ] && continue

  case "$stage" in
    host)      deps=$(echo "$info" | grep '^PKG_DEPENDS_HOST=' | cut -d'"' -f2) ;;
    init)      deps=$(echo "$info" | grep '^PKG_DEPENDS_INIT=' | cut -d'"' -f2) ;;
    bootstrap) deps=$(echo "$info" | grep '^PKG_DEPENDS_BOOTSTRAP=' | cut -d'"' -f2) ;;
    *)         deps=$(echo "$info" | grep '^PKG_DEPENDS_TARGET=' | cut -d'"' -f2) ;;
  esac
  unpack_deps=$(echo "$info" | grep '^PKG_DEPENDS_UNPACK=' | cut -d'"' -f2)

  for d in $deps; do
    [ "$d" = "$base" ] && continue
    QUEUE+=("${d}|walk")
  done
  for d in $unpack_deps; do
    [ "$d" = "$base" ] && continue
    QUEUE+=("${d}|leaf")
  done
done

UNIQUE_PKG_DIRS=$(printf '%s\n' "${PKG_DIRS[@]}" | sort -u)
UNIQUE_WATCH_PATHS=$(printf '%s\n' "${WATCH_PATHS[@]}" | sort -u)

echo "Resolved package count: $(echo "$UNIQUE_PKG_DIRS" | grep -c .)" >&2
echo "Watch-path count: $(echo "$UNIQUE_WATCH_PATHS" | grep -c .)" >&2

printf '%s\n' "$UNIQUE_PKG_DIRS"
echo '---WATCH---'
printf '%s\n' "$UNIQUE_WATCH_PATHS"
