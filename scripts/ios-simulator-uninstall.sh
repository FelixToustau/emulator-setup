#!/usr/bin/env bash
# iOS simulator uninstall helper (macOS only)
# Removes only the simulator created by ios-simulator-setup.sh. Xcode and Command Line Tools remain intact.

set -euo pipefail

SIMULATOR_NAME="iphone-ios-latest"
AUTO_YES="false"
CURRENT_STAGE="start"

log()  { >&2 printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn() { >&2 printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { >&2 printf "\033[1;31m[ERR ]\033[0m %s\n" "$*"; }
stage() { CURRENT_STAGE="$1"; log "Etapa: $1 (SO=${OS_TYPE:-?})"; }

trap 'err "Fallo en etapa: ${CURRENT_STAGE:-desconocida} (SO=${OS_TYPE:-?})"; exit 1' ERR

usage() {
  cat <<'EOF'
iOS Simulator Uninstall

Elimina el simulador creado por ios-simulator-setup.sh. No borra Xcode ni Command Line Tools.

Uso:
  ios-simulator-uninstall.sh [opciones]

Opciones:
  --simulator-name NAME   Nombre del simulador a borrar (default: iphone-ios-latest)
  --yes                   No pedir confirmación
  --help                  Muestra esta ayuda
EOF
}

detect_os() {
  local uname_out
  uname_out="$(uname -s | tr '[:upper:]' '[:lower:]')"
  case "$uname_out" in
    darwin*) OS_TYPE="macos" ;;
    *)
      err "Este script solo funciona en macOS."
      exit 1
      ;;
  esac
  log "Detectado SO: $OS_TYPE"
}

ensure_xcode_clt() {
  if ! xcode-select -p >/dev/null 2>&1; then
    err "Command Line Tools no están instalados. No se puede usar xcrun simctl."
    exit 1
  fi

  if ! xcrun simctl list >/dev/null 2>&1; then
    err "xcrun simctl no funciona. Verifica la instalación de Command Line Tools."
    exit 1
  fi
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

simulator_exists() {
  if xcrun simctl list devices 2>/dev/null | grep -q "(${SIMULATOR_NAME})"; then
    return 0
  fi
  return 1
}

get_simulator_uuid() {
  xcrun simctl list devices 2>/dev/null | grep "(${SIMULATOR_NAME})" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -n1 || true
}

delete_simulator() {
  stage "eliminar-simulador"
  
  ensure_xcode_clt

  if ! simulator_exists; then
    warn "Simulador ${SIMULATOR_NAME} no encontrado. Nada que borrar."
    return
  fi

  confirm_action "¿Eliminar simulador ${SIMULATOR_NAME} y sus datos?"

  local simulator_uuid
  simulator_uuid="$(get_simulator_uuid)"
  
  if [[ -z "$simulator_uuid" ]]; then
    err "No se pudo encontrar el UUID del simulador ${SIMULATOR_NAME}."
    exit 1
  fi

  log "Eliminando simulador ${SIMULATOR_NAME} (UUID: ${simulator_uuid})..."

  # Apagar el simulador si está arrancado
  local boot_status
  boot_status="$(xcrun simctl list devices 2>/dev/null | grep "$simulator_uuid" | grep -oE '(Booted|Shutdown)' || true)"
  if [[ "$boot_status" == "Booted" ]]; then
    log "Apagando simulador antes de eliminar..."
    xcrun simctl shutdown "$simulator_uuid" 2>/dev/null || true
  fi

  # Eliminar simulador
  if xcrun simctl delete "$simulator_uuid" 2>/dev/null; then
    log "Simulador ${SIMULATOR_NAME} eliminado exitosamente."
  else
    err "No se pudo eliminar el simulador ${SIMULATOR_NAME}."
    err "Intenta manualmente: xcrun simctl delete ${simulator_uuid}"
    exit 1
  fi

  # Verificar que se eliminó
  if simulator_exists; then
    warn "El simulador aún aparece en la lista. Puede requerir reiniciar Simulator.app."
  else
    log "Simulador eliminado completamente."
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --simulator-name) SIMULATOR_NAME="$2"; shift ;;
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

  delete_simulator
  log "Listo. Simulador ${SIMULATOR_NAME} eliminado (Xcode y Command Line Tools intactos)."
}

main "$@"
