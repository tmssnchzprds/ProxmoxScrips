#!/usr/bin/env bash
set -u

# resources.sh: helpers para controlar recursos por defecto y validación

resources_validate() {
  mem="$1"; cores="$2"
  if ! [[ "$mem" =~ ^[0-9]+$ ]]; then echo "mem invalid"; return 1; fi
  if ! [[ "$cores" =~ ^[0-9]+$ ]]; then echo "cores invalid"; return 2; fi
  return 0
}

resources_prompt() {
  def_mem="$1"; def_cores="$2"
  mem=$(whiptail --inputbox "Memoria (MB)" 8 40 "$def_mem" 3>&1 1>&2 2>&3)
  cores=$(whiptail --inputbox "Cores" 8 40 "$def_cores" 3>&1 1>&2 2>&3)
  echo "$mem|$cores"
}
