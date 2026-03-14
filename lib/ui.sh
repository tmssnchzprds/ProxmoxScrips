#!/usr/bin/env bash
set -u

ui_has_whiptail() { command -v whiptail >/dev/null 2>&1; }

ui_menu() {
  title="$1"; shift
  items=("$@")
  if ui_has_whiptail; then
    TMP=$(mktemp)
    declare -A map
    args=()
    idx=1
    for it in "${items[@]}"; do
      tag="$idx"
      map[$tag]="$it"
      args+=("$tag" "$it")
      idx=$((idx+1))
    done
    choice=$(whiptail --title "$title" --menu "Selecciona:" 20 78 12 "${args[@]}" 3>&1 1>&2 2>&3)
    rm -f "$TMP"
    echo "${map[$choice]}"
  else
    echo "-- Consola: $title --"
    i=1
    for it in "${items[@]}"; do echo "$i) $it"; i=$((i+1)); done
    printf "Elige número: "; read -r num
    echo "${items[$((num-1))]}"
  fi
}

ui_msg() {
  msg="$1"
  if ui_has_whiptail; then
    whiptail --msgbox "$msg" 10 60
  else
    echo "$msg"
  fi
}

ui_confirm() {
  prompt="$1"
  if ui_has_whiptail; then
    if whiptail --yesno "$prompt" 10 60; then return 0; else return 1; fi
  else
    printf "%s [y/N]: " "$prompt"; read -r ans; case "$ans" in [Yy]*) return 0;; *) return 1;; esac
  fi
}

ui_choose_from_list() {
  title="$1"; list_str="$2"
  IFS=$'\n'
  items=()
  for l in $list_str; do items+=("$l"); done
  unset IFS
  if ui_has_whiptail; then
    idx=1; args=(); declare -A map
    for it in "${items[@]}"; do tag="$idx"; args+=("$tag" "$(basename "$it")"); map[$tag]="$it"; idx=$((idx+1)); done
    choice=$(whiptail --title "$title" --menu "Selecciona:" 20 78 12 "${args[@]}" 3>&1 1>&2 2>&3)
    echo "${map[$choice]}"
  else
    i=1; for it in "${items[@]}"; do echo "$i) $it"; i=$((i+1)); done; printf "Elige número: "; read -r num; echo "${items[$((num-1))]}"
  fi
}

ui_show_iconed() {
  id="$1"
  icon=$(get_app_icon "$id" 2>/dev/null || echo "")
  if [ -n "$icon" ]; then
    if ui_has_whiptail; then
      whiptail --msgbox "$icon" 15 60
    else
      echo "$icon"
    fi
  fi
}

ui_search() {
  prompt="$1"; list_str="$2"
  IFS=$'\n'
  results=()
  for l in $list_str; do results+=("$l"); done
  unset IFS
  if ui_has_whiptail; then
    search=$(whiptail --inputbox "$prompt" 10 60 3>&1 1>&2 2>&3)
    [ -z "$search" ] && echo "" && return
    filtered=( )
    for it in "${results[@]}"; do
      if echo "${it}" | grep -i -- "$search" >/dev/null 2>&1; then
        filtered+=("$it")
      fi
    done
    if [ ${#filtered[@]} -eq 0 ]; then whiptail --msgbox "No se encontraron coincidencias" 8 40; echo ""; return; fi
    ui_choose_from_list "Resultados" "$(printf "%s\n" "${filtered[@]}")"
  else
    printf "%s: " "$prompt"; read -r search; [ -z "$search" ] && echo "" && return
    for it in "${results[@]}"; do if echo "$it" | grep -i -- "$search" >/dev/null 2>&1; then echo "$it"; fi; done
  fi
}

ui_proxmox_menu() {
  title="$1"; apps_json="$2"
  # apps_json is a newline list of "category|scriptpath"
  categories=()
  declare -A catmap
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    cat=${line%%|*}
    script=${line#*|}
    categories+=("$cat")
    catmap["$cat"]+="$script"$'\n'
  done <<< "$apps_json"
  # unique
  uniqcats=( $(printf "%s\n" "${categories[@]}" | sort -u) )
  if ui_has_whiptail; then
    idx=1; args=()
    for c in "${uniqcats[@]}"; do args+=("$idx" "$c"); idx=$((idx+1)); done
    sel=$(whiptail --title "$title" --menu "Categorías:" 20 78 12 "${args[@]}" 3>&1 1>&2 2>&3)
    c=${uniqcats[$((sel-1))]}
    ui_choose_from_list "Scripts en $c" "${catmap[$c]}"
  else
    echo "Categorías:"; i=1; for c in "${uniqcats[@]}"; do echo "$i) $c"; i=$((i+1)); done; printf "Elige: "; read -r n; c=${uniqcats[$((n-1))]}; echo "${catmap[$c]}"
  fi
}
