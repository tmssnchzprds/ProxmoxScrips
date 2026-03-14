#!/usr/bin/env bash
set -u

# installer.sh: instala apps desde el catálogo usando proxmox_api (esqueleto)

installer_install_app() {
  app_id="$1"
  shift
  targets=("$@")
  [ ${#targets[@]} -eq 0 ] && targets=("local")
  # load details
  if command -v jq >/dev/null 2>&1; then
    app_json=$(jq -r --arg id "$app_id" '.apps[] | select(.id==$id)' catalog/apps.json)
    if [ -z "$app_json" ]; then echo "App no encontrada: $app_id"; return 1; fi
    template=$(echo "$app_json" | jq -r '.template')
    memory=$(echo "$app_json" | jq -r '.resources.memory')
    cores=$(echo "$app_json" | jq -r '.resources.cores')
  else
    echo "jq no disponible: instalador limitado"; return 2
  fi

  for t in "${targets[@]}"; do
    log "Instalando $app_id en $t (template=$template mem=${memory}MB cores=${cores})"
    if command -v pvesh >/dev/null 2>&1; then
      proxmox_create_lxc_from_template "$t" "$template" "" "${app_id}" "$memory" "$cores" "local-lvm"
      ret=$?
      if [ $ret -ne 0 ]; then
        echo "Fallo creación en $t (ret=$ret)"; return $ret
      fi
    elif [ -n "${PVEAPITOKEN:-}" ] || [ -n "${PM_API_URL:-}" ]; then
      proxmox_create_lxc_from_template "$t" "$template" "" "${app_id}" "$memory" "$cores" "local-lvm"
      ret=$?
      if [ $ret -ne 0 ]; then echo "Fallo creación via API en $t (ret=$ret)"; return $ret; fi
    else
      # fallback: log and create marker file
      echo "SIMULACION: crear LXC $app_id on $t template=$template mem=${memory} cores=${cores}" | tee -a logs/installer.log
    fi
  done
  ui_msg "Instalación iniciada para $app_id"
}
