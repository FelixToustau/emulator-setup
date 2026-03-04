#!/usr/bin/env bash
# iOS simulator setup helper (macOS only)
# Verifies/installs Xcode Command Line Tools and creates/starts an iOS simulator.
# Default simulator: iPhone with latest iOS runtime (configurable via flags).

set -euo pipefail

# Defaults (overridable via flags)
SIMULATOR_NAME="iphone-ios-latest"
DEVICE_TYPE="auto"
IOS_VERSION="latest"
HEADLESS="false"
AUTO_YES="false"
LIST_RUNTIMES_ONLY="false"
START_SIMULATOR="false"
XCODE_PRESENT="false"
CLT_PRESENT="false"
XCODE_VERSION=""

CURRENT_STAGE="boot"

# Logs a stderr para no contaminar salidas capturadas
log()  { >&2 printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn() { >&2 printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { >&2 printf "\033[1;31m[ERR ]\033[0m %s\n" "$*" >&2; }
stage() { CURRENT_STAGE="$1"; log "Etapa: $1 (SO=${OS_TYPE:-?}, ARCH=${ARCH_TYPE:-?})"; }

trap 'err "Fallo en etapa: ${CURRENT_STAGE:-desconocida} (SO=${OS_TYPE:-?}, ARCH=${ARCH_TYPE:-?})"; exit 1' ERR

usage() {
  cat <<'EOF'
iOS Simulator Setup

Usage:
  ios-simulator-setup.sh [options]

Options:
  --simulator-name NAME    Nombre del simulador (default: iphone-ios-latest)
  --device-type TYPE       Tipo de dispositivo (default: auto - más reciente disponible)
  --ios-version VERSION    Versión de iOS (default: latest - más reciente disponible)
  --list-runtimes          Lista runtimes disponibles y sale
  --start                  Arranca el simulador tras crear/verificar
  --yes                    No pedir confirmaciones (instalación no interactiva)
  --help                   Muestra esta ayuda

Ejemplos:
  ./ios-simulator-setup.sh --start
  ./ios-simulator-setup.sh --device-type "iPhone 15 Pro" --ios-version "iOS 17.0"
  ./ios-simulator-setup.sh --list-runtimes
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "Falta el comando: $1"
    return 1
  fi
}

detect_os() {
  local uname_out
  uname_out="$(uname -s | tr '[:upper:]' '[:lower:]')"
  case "$uname_out" in
    darwin*) OS_TYPE="macos" ;;
    *)
      err "Este script solo funciona en macOS. Los simuladores iOS requieren macOS."
      exit 1
      ;;
  esac
  log "Detectado SO: $OS_TYPE"
}

detect_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    arm64|aarch64) ARCH_TYPE="arm64" ;;
    x86_64|amd64)  ARCH_TYPE="x86_64" ;;
    *) ARCH_TYPE="unknown" ;;
  esac
  log "Detectada arquitectura: $ARCH_TYPE"
}

detect_xcode() {
  # Verificar si Xcode completo está instalado
  if [[ -d "/Applications/Xcode.app" ]]; then
    XCODE_PRESENT="true"
    # Intentar obtener versión de Xcode
    if command -v xcodebuild >/dev/null 2>&1; then
      XCODE_VERSION="$(xcodebuild -version 2>/dev/null | head -n1 | sed 's/Xcode //' || echo "unknown")"
      log "Xcode detectado (versión: ${XCODE_VERSION})"
    else
      log "Xcode.app detectado pero xcodebuild no disponible"
    fi
  fi

  # Verificar Command Line Tools
  if xcode-select -p >/dev/null 2>&1; then
    CLT_PRESENT="true"
    local clt_path
    clt_path="$(xcode-select -p)"
    log "Command Line Tools detectados en: $clt_path"
  else
    log "Command Line Tools no detectados"
  fi

  if [[ "$XCODE_PRESENT" == "true" ]]; then
    log "Xcode completo disponible"
  elif [[ "$CLT_PRESENT" == "true" ]]; then
    log "Solo Command Line Tools disponibles (suficiente para simctl)"
  else
    warn "Ni Xcode ni Command Line Tools detectados. Se intentará instalar Command Line Tools."
  fi
}

ensure_xcode_clt() {
  if [[ "$CLT_PRESENT" == "true" ]]; then
    # Verificar que xcrun simctl funciona
    if xcrun simctl list >/dev/null 2>&1; then
      log "xcrun simctl funciona correctamente"
      return
    else
      warn "Command Line Tools instalados pero xcrun simctl no funciona. Reinstalando..."
    fi
  fi

  if [[ "$AUTO_YES" == "false" ]]; then
    read -r -p "Command Line Tools no están instalados. ¿Instalarlos? [y/N] " r
    [[ "$r" =~ ^[Yy]$ ]] || { err "Command Line Tools requeridos para simuladores iOS"; exit 1; }
  fi

  log "Instalando Command Line Tools (esto abrirá un diálogo del sistema)..."
  if xcode-select --install 2>&1 | grep -q "already installed"; then
    log "Command Line Tools ya están instalados"
  else
    log "Diálogo de instalación abierto. Por favor, completa la instalación en el diálogo del sistema."
    if [[ "$AUTO_YES" == "false" ]]; then
      read -r -p "Presiona Enter cuando hayas completado la instalación de Command Line Tools... " r
    else
      # En modo no interactivo, esperar un tiempo razonable
      log "Esperando 60 segundos para que se complete la instalación..."
      sleep 60
    fi
  fi

  # Verificar instalación
  local max_attempts=5
  local attempt=0
  while [[ $attempt -lt $max_attempts ]]; do
    if xcode-select -p >/dev/null 2>&1 && xcrun simctl list >/dev/null 2>&1; then
      CLT_PRESENT="true"
      log "Command Line Tools instalados y funcionando"
      return
    fi
    attempt=$((attempt + 1))
    if [[ $attempt -lt $max_attempts ]]; then
      log "Esperando verificación de Command Line Tools (intento $attempt/$max_attempts)..."
      sleep 10
    fi
  done

  err "Command Line Tools no se pudieron verificar después de la instalación."
  err "Por favor, ejecuta manualmente: xcode-select --install"
  exit 1
}

list_runtimes() {
  log "Runtimes iOS disponibles:"
  xcrun simctl runtime list 2>/dev/null || {
    warn "No se pudieron listar runtimes. Verifica que Command Line Tools estén instalados."
    return 1
  }
}

pick_latest_runtime() {
  local runtime_list
  runtime_list="$(xcrun simctl runtime list 2>/dev/null | grep -i "iOS" | grep -v "unavailable" || true)"
  
  if [[ -z "$runtime_list" ]]; then
    err "No se encontraron runtimes iOS disponibles."
    err "Instala un runtime iOS desde Xcode: Xcode > Settings > Platforms"
    exit 1
  fi

  # Extraer versiones y encontrar la más reciente
  # Formato típico: "iOS 18.0 (18.0 - ...)" o "iOS 17.5 (17.5 - ...)"
  local latest_runtime
  latest_runtime="$(echo "$runtime_list" | grep -oE "iOS [0-9]+\.[0-9]+" | sort -t'.' -k1,1n -k2,2n | tail -n1 || true)"
  
  if [[ -z "$latest_runtime" ]]; then
    # Fallback: tomar la primera línea que contenga "iOS"
    latest_runtime="$(echo "$runtime_list" | head -n1 | grep -oE "iOS [0-9]+\.[0-9]+" || true)"
  fi

  if [[ -z "$latest_runtime" ]]; then
    err "No se pudo determinar el runtime más reciente."
    list_runtimes
    exit 1
  fi

  IOS_VERSION="$latest_runtime"
  log "Runtime seleccionado: ${IOS_VERSION}"
}

find_runtime() {
  local target_version="$1"
  local runtime_list
  runtime_list="$(xcrun simctl runtime list 2>/dev/null || true)"
  
  if [[ -z "$runtime_list" ]]; then
    return 1
  fi

  # Buscar coincidencia exacta o parcial
  if echo "$runtime_list" | grep -qi "$target_version"; then
    # Extraer la versión completa
    local matched
    matched="$(echo "$runtime_list" | grep -i "$target_version" | head -n1 | grep -oE "iOS [0-9]+\.[0-9]+" || true)"
    if [[ -n "$matched" ]]; then
      IOS_VERSION="$matched"
      return 0
    fi
  fi

  return 1
}

list_device_types() {
  log "Tipos de dispositivos disponibles:"
  xcrun simctl list devicetypes 2>/dev/null | grep -i "iPhone" || {
    warn "No se pudieron listar tipos de dispositivos."
    return 1
  }
}

pick_latest_device() {
  local device_list
  device_list="$(xcrun simctl list devicetypes 2>/dev/null | grep -i "iPhone" || true)"
  
  if [[ -z "$device_list" ]]; then
    err "No se encontraron tipos de dispositivos iPhone."
    exit 1
  fi

  # Priorizar iPhone 15/15 Pro, luego iPhone 14, etc.
  local chosen=""
  
  # Buscar iPhone 15 Pro primero
  chosen="$(echo "$device_list" | grep -iE "iPhone 15 Pro" | head -n1 | awk -F'[()]' '{print $1}' | xargs || true)"
  if [[ -n "$chosen" ]]; then
    DEVICE_TYPE="$chosen"
    log "Tipo de dispositivo seleccionado: ${DEVICE_TYPE}"
    return
  fi

  # Buscar iPhone 15
  chosen="$(echo "$device_list" | grep -iE "iPhone 15[^P]" | head -n1 | awk -F'[()]' '{print $1}' | xargs || true)"
  if [[ -n "$chosen" ]]; then
    DEVICE_TYPE="$chosen"
    log "Tipo de dispositivo seleccionado: ${DEVICE_TYPE}"
    return
  fi

  # Buscar iPhone 14 Pro
  chosen="$(echo "$device_list" | grep -iE "iPhone 14 Pro" | head -n1 | awk -F'[()]' '{print $1}' | xargs || true)"
  if [[ -n "$chosen" ]]; then
    DEVICE_TYPE="$chosen"
    log "Tipo de dispositivo seleccionado: ${DEVICE_TYPE}"
    return
  fi

  # Buscar iPhone 14
  chosen="$(echo "$device_list" | grep -iE "iPhone 14[^P]" | head -n1 | awk -F'[()]' '{print $1}' | xargs || true)"
  if [[ -n "$chosen" ]]; then
    DEVICE_TYPE="$chosen"
    log "Tipo de dispositivo seleccionado: ${DEVICE_TYPE}"
    return
  fi

  # Fallback: cualquier iPhone
  chosen="$(echo "$device_list" | grep -i "iPhone" | head -n1 | awk -F'[()]' '{print $1}' | xargs || true)"
  if [[ -n "$chosen" ]]; then
    DEVICE_TYPE="$chosen"
    log "Tipo de dispositivo seleccionado: ${DEVICE_TYPE}"
    return
  fi

  err "No se pudo determinar un tipo de dispositivo iPhone."
  list_device_types
  exit 1
}

find_device_type() {
  local target_type="$1"
  local device_list
  device_list="$(xcrun simctl list devicetypes 2>/dev/null || true)"
  
  if [[ -z "$device_list" ]]; then
    return 1
  fi

  # Buscar coincidencia (case-insensitive, parcial)
  local matched
  matched="$(echo "$device_list" | grep -i "$target_type" | head -n1 | awk -F'[()]' '{print $1}' | xargs || true)"
  
  if [[ -n "$matched" ]]; then
    DEVICE_TYPE="$matched"
    return 0
  fi

  return 1
}

simulator_exists() {
  if xcrun simctl list devices 2>/dev/null | grep -q "(${SIMULATOR_NAME})"; then
    return 0
  fi
  return 1
}

create_simulator() {
  ensure_xcode_clt

  if simulator_exists; then
    log "Simulador ${SIMULATOR_NAME} ya existe; se reutiliza."
    return
  fi

  # Determinar runtime
  if [[ "$IOS_VERSION" == "latest" ]]; then
    pick_latest_runtime
  else
    if ! find_runtime "$IOS_VERSION"; then
      err "Runtime ${IOS_VERSION} no encontrado."
      list_runtimes
      exit 1
    fi
  fi

  # Determinar device type
  if [[ "$DEVICE_TYPE" == "auto" ]]; then
    pick_latest_device
  else
    if ! find_device_type "$DEVICE_TYPE"; then
      err "Tipo de dispositivo '${DEVICE_TYPE}' no encontrado."
      list_device_types
      exit 1
    fi
  fi

  log "Creando simulador ${SIMULATOR_NAME} (${DEVICE_TYPE}, ${IOS_VERSION})..."
  
  if ! xcrun simctl create "${SIMULATOR_NAME}" "${DEVICE_TYPE}" "${IOS_VERSION}" >/dev/null 2>&1; then
    err "Fallo al crear el simulador."
    err "Verifica que el tipo de dispositivo '${DEVICE_TYPE}' y el runtime '${IOS_VERSION}' existan."
    err "Lista de runtimes:"
    list_runtimes
    err "Lista de tipos de dispositivos:"
    list_device_types
    exit 1
  fi

  log "Simulador ${SIMULATOR_NAME} creado exitosamente."
}

start_simulator() {
  ensure_xcode_clt

  if ! simulator_exists; then
    err "Simulador ${SIMULATOR_NAME} no existe. Créalo primero."
    exit 1
  fi

  log "Arrancando simulador ${SIMULATOR_NAME}..."
  
  # Obtener UUID del simulador
  local simulator_uuid
  simulator_uuid="$(xcrun simctl list devices 2>/dev/null | grep "(${SIMULATOR_NAME})" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -n1 || true)"
  
  if [[ -z "$simulator_uuid" ]]; then
    err "No se pudo encontrar el UUID del simulador ${SIMULATOR_NAME}."
    exit 1
  fi

  # Arrancar simulador
  if xcrun simctl boot "$simulator_uuid" 2>/dev/null; then
    log "Simulador arrancado. Abriendo Simulator.app..."
    open -a Simulator
  else
    # Puede que ya esté arrancado
    local boot_status
    boot_status="$(xcrun simctl list devices 2>/dev/null | grep "$simulator_uuid" | grep -oE '(Booted|Shutdown)' || true)"
    if [[ "$boot_status" == "Booted" ]]; then
      log "Simulador ya está arrancado."
      open -a Simulator
    else
      warn "No se pudo arrancar el simulador. Intenta manualmente:"
      warn "  xcrun simctl boot ${simulator_uuid}"
      warn "  open -a Simulator"
    fi
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --simulator-name) SIMULATOR_NAME="$2"; shift ;;
      --device-type) DEVICE_TYPE="$2"; shift ;;
      --ios-version) IOS_VERSION="$2"; shift ;;
      --list-runtimes) LIST_RUNTIMES_ONLY="true" ;;
      --start|--boot) START_SIMULATOR="true" ;;
      --yes) AUTO_YES="true" ;;
      --headless) HEADLESS="true"; warn "Opción --headless no implementada aún para iOS" ;;
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
  detect_arch
  detect_xcode

  stage "dependencias-base"
  ensure_xcode_clt

  if [[ "$LIST_RUNTIMES_ONLY" == "true" ]]; then
    list_runtimes
    exit 0
  fi

  stage "creacion-simulador"
  create_simulator

  if [[ "$START_SIMULATOR" == "true" ]]; then
    stage "inicio-simulador"
    start_simulator
  else
    log "Simulador listo. Ejecuta '--start' o 'xcrun simctl boot ${SIMULATOR_NAME}' para arrancar."
  fi

  log "Listo. Simulador ${SIMULATOR_NAME} configurado."
}

main "$@"
