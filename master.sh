#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT_DIR/lib/ui.sh"
source "$ROOT_DIR/lib/repo.sh"
source "$ROOT_DIR/lib/catalog.sh"
source "$ROOT_DIR/lib/installer.sh"
source "$ROOT_DIR/lib/resources.sh"
source "$ROOT_DIR/lib/cluster.sh"
source "$ROOT_DIR/lib/security.sh"
source "$ROOT_DIR/lib/scripts.sh"
source "$ROOT_DIR/lib/proxmox_api.sh"

CONFIG="$ROOT_DIR/config.conf"
CAND_CONF="$ROOT_DIR/config.conf"
# load config if present
if [ -f "$CAND_CONF" ]; then
  # shellcheck disable=SC1090
  source "$CAND_CONF"
fi
CACHE_DIR="$ROOT_DIR/cache"
LOG_DIR="$ROOT_DIR/logs"

mkdir -p "$CACHE_DIR" "$LOG_DIR"

log() { echo "$(date +"%F %T") $*" | tee -a "$LOG_DIR/appstore.log"; }

appstore_menu() {
  while true; do
    CHOICE=$(ui_menu "Proxmox App Store" \
      "Explorar catálogo" "Buscar" "Ejecutar scripts" "Generar catálogo" "Actualizar repositorios" "Modo Cluster" "Salir")
    case "$CHOICE" in
      "Explorar catálogo")
        catalog_browse
        ;;
      "Ejecutar scripts")
        scripts_menu
        ;;
      "Buscar")
        catalog_search
        ;;
      "Generar catálogo")
        bash "$ROOT_DIR/lib/generate_catalog.sh"
        ui_msg "Catálogo regenerado: $ROOT_DIR/catalog/apps.json"
        ;;
      "Actualizar repositorios")
        auto_update_repos "$ROOT_DIR"
        ui_msg "Repos actualizados."
        ;;
      "Modo Cluster")
        cluster_prompt
        ;;
      "Salir")
        log "Salir Proxmox App Store"
        exit 0
        ;;
    esac
  done
}

catalog_browse() {
  load_catalog "$ROOT_DIR/catalog/apps.json"
  # show full list of app names
  all=$(get_all_apps)
  sel=$(ui_choose_from_list "Explorar catálogo (todas las apps)" "$all")
  [ -z "$sel" ] && return
  app_id=${sel%%|*}
  # list available architectures for this app
  # try jq first, fallback to none
  if command -v jq >/dev/null 2>&1; then
    archs=$(jq -r --arg id "$app_id" '.apps[] | select(.id==$id) | (.architectures // [] )[]' "$ROOT_DIR/catalog/apps.json")
  else
    archs=""
  fi
  if [ -z "$archs" ]; then
    # no architectures listed, run generic script
    script=$(get_app_script_path "$app_id" "")
    ui_msg "Ejecutando script: $script"
    sandbox_run "$script"
  else
    # present arch choices plus 'automatico'
    arch_choice=$(ui_menu "Selecciona arquitectura" "automatico" $(printf "%s " $archs))
    [ -z "$arch_choice" ] && return
    if [ "$arch_choice" = "automatico" ]; then
      # prefer amd64
      if echo "$archs" | grep -q "amd64"; then arch_choice=amd64
      else arch_choice=$(echo "$archs" | head -n1)
      fi
    fi
    script=$(get_app_script_path "$app_id" "$arch_choice")
    ui_msg "Ejecutando $app_id ($arch_choice): $script"
    sandbox_run "$script"
  fi
}

get_app_script_path() {
  app_id="$1"; arch="$2"
  if command -v jq >/dev/null 2>&1; then
    if [ -z "$arch" ]; then
      jq -r --arg id "$app_id" '.apps[] | select(.id==$id) | .script // empty' "$ROOT_DIR/catalog/apps.json"
    else
      jq -r --arg id "$app_id" --arg a "$arch" '.apps[] | select(.id==$id) | (.script_paths[$a] // .script // empty)' "$ROOT_DIR/catalog/apps.json"
    fi
  else
    # fallback parsing
    block=$(sed -n "/\"id\"[[:space:]]*:[[:space:]]*\"$app_id\"/,/}/p" "$ROOT_DIR/catalog/apps.json" | sed -n '1,200p')
    if [ -z "$arch" ]; then
      echo "$block" | sed -n 's/.*"script"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
    else
      # try script_paths
      echo "$block" | sed -n "s/.*\"$arch\"[[:space:]]*:[[:space:]]*\"\([^"]*\)\".*/\1/p" | head -n1 || echo ""
    fi
  fi
}

catalog_search() {
  load_catalog "$ROOT_DIR/catalog/apps.json"
  all=$(get_all_apps)
  sel=$(ui_search "Buscar app:" "$all")
  [ -z "$sel" ] && return
  app_id=${sel%%|*}
  show_app_and_install "$app_id"
}

show_app_and_install() {
  app_id="$1"
  ui_show_iconed "$app_id"
  details=$(get_app_details "$app_id")
  ui_msg "$details"
  if ui_confirm "Instalar esta app?"; then
    if ui_confirm "Instalar en modo cluster (varios nodos)?"; then
      nodes_input=$(whiptail --inputbox "Nodos (comma-separated)" 8 60 "" 3>&1 1>&2 2>&3)
      IFS=',' read -r -a nodes <<< "$nodes_input"
      installer_install_app "$app_id" "${nodes[@]}"
    else
      node=$(whiptail --inputbox "Nodo destino" 8 60 "local" 3>&1 1>&2 2>&3)
      installer_install_app "$app_id" "$node"
    fi
  fi
}

cluster_prompt() {
  node_list=$(whiptail --inputbox "Introduce nodos (comma-separated)" 8 60 "node1,node2" 3>&1 1>&2 2>&3)
  ui_msg "Modo cluster configurado: $node_list"
}

scripts_menu() {
  while true; do
    choice=$(ui_menu "Ejecutar scripts" "Ejecutar todos" "Reanudar desde último" "Ejecutar por arquitectura" "Ejecutar por tipo (CT/VM)" "Volver")
    case "$choice" in
      "Ejecutar todos")
        list=$(filter_scripts "" "")
        execute_scripts_list "$list"
        ;;
      "Reanudar desde último")
        list=$(filter_scripts "" "")
        resume_scripts_list "$list"
        ;;
      "Ejecutar por arquitectura")
        arch=$(ui_menu "Elige arquitectura" "amd64" "arm64" "ambas")
        [ -z "$arch" ] && continue
        if [ "$arch" = "ambas" ]; then arch_filter=""; else arch_filter="$arch"; fi
        subchoice=$(ui_menu "Ejecutar" "Todos" "Subselección")
        if [ "$subchoice" = "Todos" ]; then list=$(filter_scripts "$arch_filter" ""); execute_scripts_list "$list"; else nl=$(filter_scripts "$arch_filter" ""); sel=$(ui_choose_from_list "Elige scripts" "$nl"); [ -z "$sel" ] && continue; sandbox_run "$sel"; fi
        ;;
      "Ejecutar por tipo (CT/VM)")
        type=$(ui_menu "Elige tipo" "ct" "vm")
        [ -z "$type" ] && continue
        subchoice=$(ui_menu "Ejecutar" "Todos" "Subselección")
        if [ "$subchoice" = "Todos" ]; then list=$(filter_scripts "" "$type"); execute_scripts_list "$list"; else nl=$(filter_scripts "" "$type"); sel=$(ui_choose_from_list "Elige scripts" "$nl"); [ -z "$sel" ] && continue; sandbox_run "$sel"; fi
        ;;
      "Volver") return;;
    esac
  done
}

execute_scripts_list() {
  list="$1"
  checkpoint="$CACHE_DIR/last_executed.txt"
  > "$checkpoint"
  idx=0
  while IFS= read -r s; do
    [ -z "$s" ] && continue
    idx=$((idx+1))
    echo "[$idx] Ejecutando: $s"
    sandbox_run "$s"
    echo "$s" > "$checkpoint"
  done <<< "$list"
  ui_msg "Ejecución completa."
}

resume_scripts_list() {
  list="$1"
  checkpoint="$CACHE_DIR/last_executed.txt"
  last=""
  [ -f "$checkpoint" ] && last=$(cat "$checkpoint")
  skipping=1
  if [ -z "$last" ]; then skipping=0; fi
  idx=0
  while IFS= read -r s; do
    [ -z "$s" ] && continue
    if [ "$skipping" -eq 1 ]; then
      if [ "$s" = "$last" ]; then skipping=0; continue; else continue; fi
    fi
    idx=$((idx+1))
    echo "[$idx] Ejecutando: $s"
    sandbox_run "$s"
    echo "$s" > "$checkpoint"
  done <<< "$list"
  ui_msg "Reanudado y completado."
}

# Start
# Run menu only when executed directly (not when sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  log "Arrancando Proxmox App Store"
  appstore_menu
fi
