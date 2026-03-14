#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$ROOT_DIR/cache/scripts_list.txt"
OUT="$ROOT_DIR/catalog/apps.json"
ICONS_DIR="$ROOT_DIR/catalog/icons"

mkdir -p "$(dirname "$OUT")" "$ICONS_DIR"

declare -A seen
apps=()

if [ ! -f "$CACHE" ]; then
  echo "No cache file: $CACHE" >&2
  exit 1
fi

while IFS= read -r line; do
  [ -z "$line" ] && continue
  # include scripts under /install/ or files ending with -install.sh
  if [[ "$line" == */install/* || "$line" == *-install.sh ]]; then
    script="$line"
  else
    continue
  fi
  base=$(basename "$script")
  id="${base%.sh}"
  id="${id%-install}"
  # normalize id: lowercase, remove spaces
  id=$(echo "$id" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')
  if [ -z "$id" ]; then continue; fi
  if [ "${seen[$id]+_}" ]; then continue; fi
  seen[$id]=1
  # pretty name
  name=$(echo "$id" | sed 's/[-_]/ /g' | awk '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) } print}')
  category="apps"
  template="local:vztmpl/${id}.tar.gz"
  memory=1024
  cores=1
  icon=""
  if [ -f "$ICONS_DIR/${id}.txt" ]; then icon="${id}.txt"; fi
  # build JSON object (compact)
  desc="Instalador para $name."
  obj=$(cat <<EOF
{"id":"$id","name":"$name","category":"$category","description":"$desc","template":"$template","resources":{"memory":$memory,"cores":$cores},"icon":"$icon","script":"$script"}
EOF
)
  apps+=("$obj")
done < "$CACHE"

# write JSON
mkdir -p "$(dirname "$OUT")"
{
  printf '{\n  "apps": [\n'
  first=1
  for a in "${apps[@]}"; do
    if [ $first -eq 1 ]; then
      printf '    %s\n' "$a"
      first=0
    else
      printf '    ,%s\n' "$a"
    fi
  done
  printf '  ]\n}\n'
} > "$OUT"

echo "Generated $OUT with ${#apps[@]} apps"
