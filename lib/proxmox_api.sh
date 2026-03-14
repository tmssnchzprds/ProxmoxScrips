#!/usr/bin/env bash
set -u

# proxmox_api.sh: funciones básicas para interactuar con Proxmox API.
# Requiere `pvesh` or use `curl` with API tokens. Aquí un esqueleto.

PM_API_URL="${PM_API_URL:-https://127.0.0.1:8006}"
# PVE token expected either in env var `PVEAPITOKEN` or in `config.conf` as `PVEAPITOKEN`.
PVEAPITOKEN="${PVEAPITOKEN:-}"

proxmox_api_request() {
  method="$1"; path="$2"; data="$3"
  url="$PM_API_URL/api2/json$path"
  headers=("-k" "-s" "-H" "Accept: application/json")
  if [ -n "$PVEAPITOKEN" ]; then
    headers+=("-H" "Authorization: PVEAPIToken=${PVEAPITOKEN}")
  fi
  if [ -n "$data" ]; then
    curl "${headers[@]}" -X "$method" -d @$data "$url"
  else
    curl "${headers[@]}" -X "$method" "$url"
  fi
}

proxmox_api_ping() {
  proxmox_api_request GET /version
}

proxmox_get_nextid() {
  # Returns the next free VMID (parses JSON response)
  proxmox_api_request GET /cluster/nextid | sed -n 's/.*"data"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p'
}

proxmox_create_lxc_from_template() {
  # params: node, template, vmid(optional), hostname, memory, cores, storage
  node="$1"; template="$2"; vmid="$3"; hostname="$4"; memory="$5"; cores="$6"; storage="${7:-local-lvm}"
  if [ -z "$vmid" ] || [ "$vmid" = "" ]; then
    vmid=$(proxmox_get_nextid)
  fi
  # Build form-encoded body in a temp file
  data=$(mktemp)
  printf 'vmid=%s&ostemplate=%s&hostname=%s&memory=%s&cores=%s&rootfs=%s:4' "$vmid" "$template" "$hostname" "$memory" "$cores" "$storage" > "$data"
  proxmox_api_request POST "/nodes/${node}/lxc" "$data"
  ret=$?
  rm -f "$data"
  return $ret
}

