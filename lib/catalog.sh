#!/usr/bin/env bash
set -u

# catalog.sh: carga y consulta de catálogo de apps (usa jq si está disponible)

CATALOG_JSON=""

load_catalog() {
  path="$1"
  if [ -f "$path" ]; then
    CATALOG_JSON="$path"
  else
    echo "No existe $path" >&2
    return 1
  fi
}

has_jq() { command -v jq >/dev/null 2>&1; }
jq_ok() { has_jq || return 1; jq -e . "$CATALOG_JSON" >/dev/null 2>&1; }

get_categories() {
  if has_jq && jq_ok; then
    jq -r '.apps[].category' "$CATALOG_JSON" | sort -u | awk 'NF' | sed 's/^/ /'
  else
    # fallback: parse apps.json without jq (simple parser)
    awk '/"category"/ {gsub(/[",]/,"",$0); print $2}' "$CATALOG_JSON" | sed 's/^ *//g' | sort -u
  fi
}

get_all_apps() {
  if has_jq && jq_ok; then
    jq -r '.apps[] | .id + "|" + .name' "$CATALOG_JSON"
  else
    # parse id and name
    awk '/"id"/ {gsub(/[",]/,"",$0); id=$2} /"name"/ {gsub(/[",]/,"",$0); name=$2; if (id!="") {print id"|"name; id=""}}' "$CATALOG_JSON"
  fi
}

get_apps_in_category() {
  cat="$1"
  if has_jq && jq_ok; then
    jq -r --arg c "$cat" '.apps[] | select(.category==$c) | .id + "|" + .name' "$CATALOG_JSON"
  else
    # parse objects and print those matching category
    awk -v cat="$cat" 'BEGIN{RS="}"} /"id"/ {id=""; name=""; category=""; template=""; icon=""; script=""} /"id"/ { if (match($0,/"id"[[:space:]]*:[[:space:]]*"([^"]+)"/,m)) id=m[1]} /"name"/ { if (match($0,/"name"[[:space:]]*:[[:space:]]*"([^"]+)"/,m)) name=m[1]} /"category"/ { if (match($0,/"category"[[:space:]]*:[[:space:]]*"([^"]+)"/,m)) category=m[1]} { if (category==cat && id!="") print id"|"name }' "$CATALOG_JSON"
  fi
}

get_app_details() {
  id="$1"
  if has_jq && jq_ok; then
    jq -r --arg id "$id" '.apps[] | select(.id==$id) | "ID: "+.id+"\nNombre: "+.name+"\nCategoria: "+.category+"\nDescripcion: "+.description+"\nTemplate: "+.template+"\nRecursos por defecto: memoria="+.resources.memory+"MB, cores="+.resources.cores' "$CATALOG_JSON"
  else
    # fallback: extract a small block around the id and parse keys with sed/grep (portable)
    block=$(sed -n "/\"id\"[[:space:]]*:[[:space:]]*\"$id\"/,/}/p" "$CATALOG_JSON" | sed -n '1,200p')
    if [ -z "$block" ]; then echo "App no encontrada: $id"; return 1; fi
    name=$(echo "$block" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
    catn=$(echo "$block" | sed -n 's/.*"category"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
    desc=$(echo "$block" | sed -n 's/.*"description"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
    tpl=$(echo "$block" | sed -n 's/.*"template"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
    mem=$(echo "$block" | sed -n 's/.*"memory"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' | head -n1)
    cores=$(echo "$block" | sed -n 's/.*"cores"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' | head -n1)
    printf "ID: %s\nNombre: %s\nCategoria: %s\nDescripcion: %s\nTemplate: %s\nRecursos por defecto: memoria=%sMB, cores=%s\n" "$id" "$name" "$catn" "$desc" "$tpl" "$mem" "$cores"
  fi
}

get_app_icon() {
  id="$1"
  # icon file expected in catalog/icons/<id>.txt
  file="catalog/icons/${id}.txt"
  [ -f "$file" ] && cat "$file" || echo "(sin icono)"
}
