#!/usr/bin/env bash
set -u

# cluster.sh: Esqueleto para ejecución remota en múltiples nodos Proxmox
# Usa ssh para invocar `master.sh` en nodos remotos o transferir scripts.

cluster_run_on_nodes() {
  nodes=("$@")
  for n in "${nodes[@]}"; do
    echo "Ejecutando en nodo: $n"
    # ejemplo (requiere SSH key o passwordless):
    # ssh root@${n} 'bash -s' < /path/to/master.sh
  done
}

cluster_sync_repos() {
  nodes=("$@")
  for n in "${nodes[@]}"; do
    echo "Sincronizando repos a $n (placeholder)"
  done
}
