#!/usr/bin/env bash
set -u

is_dangerous() {
  script="$1"
  patterns=("rm -rf /" "rm -rf" "dd if=" "mkfs" "mkfs." ":(){ :|: & };:" "wget .*sh" "curl .*sh" "curl -sL" "nc -l" "chmod 777" "chmod 0777")
  for p in "${patterns[@]}"; do
    if grep -E -n -- "$p" "$script" >/dev/null 2>&1; then
      return 0
    fi
  done
  # also mark scripts that download and pipe to sh
  if grep -E -n "curl .*\| *sh|wget .*\| *sh" "$script" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# sandbox_run: intenta ejecutar el script en modo seguro usando `bash -n` + entorno limitado
sandbox_run() {
  script="$1"
  # syntax check
  if ! bash -n "$script" 2>/dev/null; then
    echo "Fallo en syntax check: $script"; return 2
  fi
  # run in restricted environment: no network, restricted PATH
  ( 
    PATH=/usr/sbin:/usr/bin:/sbin:/bin
    unset LD_PRELOAD
    # optional: use firejail if installed
    if command -v firejail >/dev/null 2>&1; then
      firejail --quiet --net=none --private -- /bin/bash "$script"
    else
      # best-effort: run in subshell with limited env
      /bin/bash "$script"
    fi
  )
}

# verify_app: basic checks before install (e.g., dangerous patterns)
verify_app() {
  app_id="$1"
  # if app has associated script, check for dangerous patterns
  if [ -f "catalog/apps.json" ] && command -v jq >/dev/null 2>&1; then
    path=$(jq -r --arg id "$app_id" '.apps[] | select(.id==$id) | .script // empty' catalog/apps.json)
    [ -n "$path" ] && is_dangerous "$path" && return 1 || return 0
  fi
  return 0
}
