#!/usr/bin/env bash
set -u

CACHE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/cache"
mkdir -p "$CACHE_DIR"

index_scripts() {
  root="$1"
  out="$CACHE_DIR/scripts_list.txt"
  > "$out"
  for base in amd64 arm64; do
    dir="$root/$base"
    if [ -d "$dir" ]; then
      # find executable .sh or files ending in .sh
      find "$dir" -type f -name '*.sh' -print | while read -r f; do
        # exclude this tool's lib files
        case "$f" in
          */lib/*) continue;;
        esac
        # consider executable or just .sh
        if [ -x "$f" ] || true; then
          # store path relative to repo root
          rel="${f#${root}/}"
          echo "$rel" >> "$out"
        fi
      done
    fi
  done
  # generate simple apps catalog: category|path
  apps_out="$CACHE_DIR/apps_catalog.txt"
  > "$apps_out"
  while IFS= read -r s; do
    # category derived from path: use parent dir of script relative to repo root
    rel=${s#${root}/}
    # category is first path component after arch (e.g. tools, ct, vm)
    cat=$(echo "$rel" | awk -F'/' '{ if (NF>=2) print $2; else print "uncategorized" }')
    echo "$cat|$s" >> "$apps_out"
  done < "$out"
}

detect_duplicates() {
  file="$CACHE_DIR/scripts_list.txt"
  [ -f "$file" ] || return
  awk -F'/' '{print $NF}' "$file" | sort | uniq -c | awk '$1>1{print $2" ("$1" copias)"}'
}

filter_scripts() {
  arch="$1"; typef="$2"
  file="$CACHE_DIR/scripts_list.txt"
  [ -f "$file" ] || { echo ""; return; }
  nl=""
  while IFS= read -r s; do
    ok=1
    case "$arch" in
      amd64) case "$s" in *amd64/*) ;; *) ok=0;; esac;;
      arm64) case "$s" in *arm64/*) ;; *) ok=0;; esac;;
      *) ok=1;;
    esac
    case "$typef" in
      ct) case "$s" in */ct/*) ;; *) ok=0;; esac;;
      vm) case "$s" in */vm/*) ;; *) ok=0;; esac;;
      *) ok=$ok;;
    esac
    if [ "$ok" -eq 1 ]; then nl+="$s"$'\n'; fi
  done < "$file"
  printf "%s" "$nl"
}
