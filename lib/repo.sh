#!/usr/bin/env bash
set -u

update_repos() {
  root="$1"
  for d in "$root"/amd64 "$root"/arm64; do
    if [ -d "$d/.git" ]; then
      echo "Actualizando repo $d"
      (cd "$d" && git pull --rebase --autostash) || echo "Fallo actualización $d"
    fi
  done
}

auto_update_repos() {
  root="$1"
  echo "Auto-actualizando repos..."
  update_repos "$root"
}

clone_missing_repos() {
  # placeholder: user can add remote URLs in config later
  echo "Comprobar repos faltantes (no hay remotes configurados)."
}
