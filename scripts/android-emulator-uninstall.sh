#!/usr/bin/env bash
# Android emulator uninstall helper (macOS, Ubuntu, Windows/WSL)
# Removes only the AVD created by android-emulator-setup.sh. SDK and tools remain intact.

set -euo pipefail

AVD_NAME="pixel6-api34"
AUTO_YES="false"
CURRENT_STAGE="start"

ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"

log()  { >&2 printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn() { >&2 printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { >&2 printf "\033[1;31m[ERR ]\033[0m %s\n" "$*"; }
stage() { CURRENT_STAGE="$1"; log "Etapa: $1 (SO=${OS_TYPE:-?}, SDK=${ANDROID_HOME:-unset})"; }

trap 'err "Fallo en etapa: ${CURRENT_STAGE:-desconocida} (SO=${OS_TYPE:-?}, SDK=${ANDROID_HOME:-unset})"; exit 1' ERR

usage() {
  cat <<'EOF'
Android Emulator Uninstall

Elimina el AVD creado por android-emulator-setup.sh. No borra el SDK ni cmdline-tools.

Uso:
  android-emulator-uninstall.sh [opciones]

Opciones:
  --avd-name NAME   Nombre del AVD a borrar (default: pixel6-api34)
  --yes             No pedir confirmación
  --help            Muestra esta ayuda
EOF
}

detect_os() {
  local uname_out
  uname_out="$(uname -s | tr '[:upper:]' '[:lower:]')"
  case "$uname_out" in
    darwin*) OS_TYPE="macos" ;;
    linux*)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        OS_TYPE="wsl"
      else
        if command -v lsb_release >/dev/null 2>&1 && lsb_release -i | grep -qi ubuntu; then
          OS_TYPE="ubuntu"
        else
          OS_TYPE="linux"
        fi
      fi
      ;;
    *) OS_TYPE="unknown" ;;
  esac
  log "Detectado SO: $OS_TYPE"
}

set_android_home_if_macos() {
  if [[ "${OS_TYPE:-}" == "macos" ]]; then
    local mac_sdk="$HOME/Library/Android/sdk"
    if [[ -d "$mac_sdk" ]]; then
      ANDROID_HOME="${ANDROID_HOME:-$mac_sdk}"
    fi
  fi
}

locate_sdk_default() {
  local candidates=()
  [[ -n "${ANDROID_HOME:-}" ]] && candidates+=("$ANDROID_HOME")
  [[ -n "${ANDROID_SDK_ROOT:-}" ]] && candidates+=("$ANDROID_SDK_ROOT")
  [[ "$OS_TYPE" == "macos" ]] && candidates+=("$HOME/Library/Android/sdk")
  candidates+=("$HOME/Android/Sdk" "$HOME/Android/sdk" "/usr/lib/android-sdk" "/opt/android-sdk")

  for path in "${candidates[@]}"; do
    if [[ -d "$path" ]]; then
      ANDROID_HOME="$path"
      break
    fi
  done
}

ensure_paths() {
  export ANDROID_HOME
  export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
  export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
}

confirm_action() {
  local prompt="$1"
  if [[ "$AUTO_YES" == "true" ]]; then
    return
  fi
  read -r -p "$prompt [y/N] " reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    log "Operación cancelada por el usuario."
    exit 0
  fi
}

avd_exists() {
  local ini="$HOME/.android/avd/${AVD_NAME}.ini"
  local dir="$HOME/.android/avd/${AVD_NAME}.avd"
  if command -v avdmanager >/dev/null 2>&1; then
    if avdmanager list avd | grep -q "Name: ${AVD_NAME}"; then
      return 0
    fi
  fi
  [[ -f "$ini" || -d "$dir" ]]
}

delete_avd() {
  stage "eliminar-avd"
  if ! avd_exists; then
    warn "AVD ${AVD_NAME} no encontrado. Nada que borrar."
    return
  fi

  confirm_action "¿Eliminar AVD ${AVD_NAME} y sus archivos?"

  if command -v avdmanager >/dev/null 2>&1; then
    if avdmanager delete avd -n "${AVD_NAME}"; then
      log "AVD ${AVD_NAME} eliminado con avdmanager."
    else
      warn "avdmanager no pudo eliminar ${AVD_NAME}. Se intentará limpieza manual."
    fi
  else
    warn "avdmanager no está disponible; se realizará limpieza manual."
  fi

  local ini="$HOME/.android/avd/${AVD_NAME}.ini"
  local dir="$HOME/.android/avd/${AVD_NAME}.avd"

  if [[ -f "$ini" || -d "$dir" ]]; then
    rm -rf "$ini" "$dir"
    log "Restos locales en ~/.android/avd/${AVD_NAME}* eliminados."
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --avd-name) AVD_NAME="$2"; shift ;;
      --yes) AUTO_YES="true" ;;
      --help|-h) usage; exit 0 ;;
      *)
        err "Opción no reconocida: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"
  stage "deteccion-entorno"
  detect_os
  set_android_home_if_macos
  locate_sdk_default
  ensure_paths

  delete_avd
  log "Listo. AVD ${AVD_NAME} eliminado (SDK intacto en ${ANDROID_HOME})."
}

main "$@"
