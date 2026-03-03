#!/usr/bin/env bash
# Android emulator setup helper (macOS, Ubuntu, Windows/WSL)
# Installs Android SDK cmdline-tools, required packages, and creates/starts an AVD.
# Default AVD: Pixel 6, API 34, Google APIs, x86_64 (configurable via flags).

set -euo pipefail

# Defaults (overridable via flags)
AVD_NAME="pixel6-api34"
API_LEVEL="34"
DEVICE_ID="pixel_6"
ABI="x86_64"
ABI_SET="false"
HEADLESS="false"
AUTO_YES="false"
LIST_IMAGES_ONLY="false"
START_EMULATOR="false"
ANDROID_STUDIO_PRESENT="false"
EXISTING_SDK_FOUND="false"

CURRENT_STAGE="boot"

ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
# URLs separados para permitir override vía env si Google actualiza versiones
CMDLINE_TOOLS_URL_LINUX="${CMDLINE_TOOLS_URL_LINUX:-https://dl.google.com/android/repository/commandlinetools-linux-11560868_latest.zip}"
CMDLINE_TOOLS_URL_DARWIN="${CMDLINE_TOOLS_URL_DARWIN:-https://dl.google.com/android/repository/commandlinetools-mac-11560868_latest.zip}"

# Logs a stderr para no contaminar salidas capturadas
log()  { >&2 printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn() { >&2 printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { >&2 printf "\033[1;31m[ERR ]\033[0m %s\n" "$*" >&2; }
stage() { CURRENT_STAGE="$1"; log "Etapa: $1 (SO=${OS_TYPE:-?}, ARCH=${ARCH_TYPE:-?}, SDK=${ANDROID_HOME:-unset})"; }

trap 'err "Fallo en etapa: ${CURRENT_STAGE:-desconocida} (SO=${OS_TYPE:-?}, ARCH=${ARCH_TYPE:-?}, SDK=${ANDROID_HOME:-unset})"; exit 1' ERR

usage() {
  cat <<'EOF'
Android Emulator Setup

Usage:
  android-emulator-setup.sh [options]

Options:
  --avd-name NAME         Nombre del AVD (default: pixel6-api34)
  --api-level N           Nivel de API (default: 34)
  --device ID             Dispositivo avdmanager (default: pixel_6)
  --abi ABI               ABI de la imagen (default auto: arm64-v8a en ARM, x86_64 en Intel)
  --headless              Ejecutar emulator sin ventana (-no-window)
  --start                 Arranca el emulador tras crear/verificar el AVD
  --list-system-images    Lista imágenes disponibles y sale
  --yes                   No pedir confirmaciones (instalación no interactiva)
  --help                  Muestra esta ayuda

Variables útiles:
  ANDROID_HOME o ANDROID_SDK_ROOT para forzar la ruta del SDK.

Ejemplos:
  ./android-emulator-setup.sh --api-level 34 --device pixel_6 --start
  ./android-emulator-setup.sh --abi arm64-v8a --avd-name pixel6-arm --headless
  ./android-emulator-setup.sh --list-system-images
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
    linux*)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        OS_TYPE="wsl"
      else
        # Best-effort Ubuntu check
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

detect_android_studio_and_sdk() {
  # Determina si hay Android Studio instalado y si ya existe un SDK utilizable.
  if [[ -d "/Applications/Android Studio.app" ]]; then
    ANDROID_STUDIO_PRESENT="true"
  fi

  local candidates=()
  # Prioridad: variables de entorno, rutas conocidas por SO y Android Studio
  [[ -n "${ANDROID_HOME:-}" ]] && candidates+=("$ANDROID_HOME")
  [[ -n "${ANDROID_SDK_ROOT:-}" ]] && candidates+=("$ANDROID_SDK_ROOT")
  if [[ "$OS_TYPE" == "macos" ]]; then
    candidates+=("$HOME/Library/Android/sdk")
  fi
  candidates+=("$HOME/Android/Sdk" "$HOME/Android/sdk" "/usr/lib/android-sdk" "/opt/android-sdk")

  for path in "${candidates[@]}"; do
    if [[ -d "$path" ]]; then
      ANDROID_HOME="$path"
      EXISTING_SDK_FOUND="true"
      break
    fi
  done

  if [[ "$ANDROID_STUDIO_PRESENT" == "true" ]]; then
    log "Android Studio detectado. SDK ${EXISTING_SDK_FOUND:+encontrado en $ANDROID_HOME}"
  else
    log "Android Studio no detectado. Se instalará SDK standalone si falta."
  fi

  if [[ "$EXISTING_SDK_FOUND" == "true" ]]; then
    log "Usando SDK existente en ${ANDROID_HOME}"
  fi
}

ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi
  if [[ "$AUTO_YES" == "false" ]]; then
    read -r -p "Homebrew no está instalado. ¿Instalarlo? [y/N] " r
    [[ "$r" =~ ^[Yy]$ ]] || { err "Homebrew requerido en macOS"; exit 1; }
  fi
  log "Instalando Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  log "Homebrew instalado. Reinicia tu shell si los binarios no son visibles."
}

ensure_java() {
  if command -v java >/dev/null 2>&1; then
    log "Java detectado."
    return
  fi
  case "$OS_TYPE" in
    macos)
      ensure_homebrew
      log "Instalando OpenJDK..."
      brew install openjdk
      ;;
    ubuntu|linux|wsl)
      log "Instalando OpenJDK..."
      sudo apt-get update
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-17-jdk curl unzip zip libglu1-mesa libpulse0
      ;;
    *)
      err "Instala manualmente Java (OpenJDK 17+) antes de continuar."
      exit 1
      ;;
  esac
}

download_cmdline_tools() {
  local url dest tmpdir
  tmpdir="$(mktemp -d)"
  case "$OS_TYPE" in
    macos) url="$CMDLINE_TOOLS_URL_DARWIN" ;;
    ubuntu|linux|wsl) url="$CMDLINE_TOOLS_URL_LINUX" ;;
    *) err "SO no soportado para descarga automática de cmdline-tools"; exit 1 ;;
  esac
  dest="$tmpdir/cmdline-tools.zip"
  log "Descargando cmdline-tools desde $url..."
  curl -fsSL "$url" -o "$dest"
  printf "%s\n" "$dest"   # solo la ruta por stdout
}

install_cmdline_tools() {
  local target="$ANDROID_HOME/cmdline-tools/latest"
  if [[ -x "$target/bin/sdkmanager" ]]; then
    log "cmdline-tools ya instalado en $target"
    return
  fi
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  local zip_path
  zip_path="$(download_cmdline_tools)"
  local tmpdir
  tmpdir="$(mktemp -d)"
  unzip -q "$zip_path" -d "$tmpdir"
  # Google distribuye como cmdline-tools; lo movemos a latest
  mv "$tmpdir/cmdline-tools" "$target"
  log "cmdline-tools instalado en $target"
}

ensure_paths() {
  export ANDROID_HOME
  export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
  export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
}

ensure_sdkmanager() {
  ensure_paths
  if ! command -v sdkmanager >/dev/null 2>&1; then
    err "sdkmanager no encontrado tras instalar cmdline-tools."
    exit 1
  fi
}

accept_licenses() {
  yes | sdkmanager --licenses >/dev/null
}

install_sdk_components() {
  ensure_sdkmanager
  local platform="platforms;android-${API_LEVEL}"
  local sys_image="system-images;android-${API_LEVEL};google_apis;${ABI}"
  log "Instalando componentes SDK (platform-tools, emulator, ${platform}, ${sys_image})..."
  # sdkmanager a veces devuelve 141 (SIGPIPE) pese a instalar correctamente. Permitimos 0 o 141.
  if ! yes | sdkmanager "platform-tools" "emulator" "$platform" "$sys_image"; then
    local code=$?
    if [[ $code -eq 141 ]]; then
      warn "sdkmanager terminó con código 141 (SIGPIPE) pero puede haber instalado paquetes; continuando."
    else
      err "sdkmanager falló instalando componentes (exit=$code). Revisa conectividad y permisos."
      exit $code
    fi
  fi
}

list_system_images() {
  ensure_sdkmanager
  sdkmanager --list | grep "system-images;android-" || true
}

pick_device_id() {
  # Elige un dispositivo válido de avdmanager; prioriza Pixel.
  local device_list chosen
  device_list="$(avdmanager list device | awk -F '[: ]+' '/id:/{print $2}' | tr -d ' ')"
  chosen="$(echo "$device_list" | grep -E '^pixel' | head -n1 || true)"
  if [[ -z "$chosen" ]]; then
    chosen="$(echo "$device_list" | head -n1 || true)"
  fi
  if [[ -z "$chosen" ]]; then
    err "No se encontraron dispositivos en avdmanager list device. Revisa cmdline-tools."
    exit 1
  fi
  DEVICE_ID="$chosen"
  log "Dispositivo para AVD: ${DEVICE_ID}"
}

create_avd() {
  ensure_sdkmanager
  if avdmanager list avd | grep -q "Name: ${AVD_NAME}"; then
    log "AVD ${AVD_NAME} ya existe; se reutiliza."
    return
  fi
  pick_device_id
  local sys_image="system-images;android-${API_LEVEL};google_apis;${ABI}"
  log "Creando AVD ${AVD_NAME} (${sys_image}, device ${DEVICE_ID})..."
  if ! echo "no" | avdmanager create avd \
    --name "${AVD_NAME}" \
    --package "${sys_image}" \
    --device "${DEVICE_ID}" \
    --abi "${ABI}" \
    --force; then
    err "Fallo al crear el AVD. Verifica que el paquete ${sys_image} y el device ${DEVICE_ID} existan."
    exit 1
  fi
  # Ajustes básicos para headless/server
  {
    echo "hw.gpu.mode=auto"
    echo "hw.gpu.enabled=yes"
    echo "skin.dynamic=yes"
  } >> "$HOME/.android/avd/${AVD_NAME}.avd/config.ini"
}

start_emulator() {
  local args=("-avd" "${AVD_NAME}" "-netdelay" "none" "-netspeed" "full")
  if [[ "$HEADLESS" == "true" ]]; then
    args+=("-no-window")
  fi
  log "Arrancando emulador ${AVD_NAME}..."
  emulator "${args[@]}" >/dev/null 2>&1 &
  log "Emulador lanzado en background. Usa 'adb devices' para verificar."
}

install_dependencies_by_os() {
  case "$OS_TYPE" in
    macos)
      ensure_homebrew
      ensure_java
      ;;
    ubuntu|linux|wsl)
      ensure_java
      ;;
    *)
      err "SO no soportado automáticamente. Usa macOS, Ubuntu o WSL."
      exit 1
      ;;
  esac
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --avd-name) AVD_NAME="$2"; shift ;;
      --api-level) API_LEVEL="$2"; shift ;;
      --device) DEVICE_ID="$2"; shift ;;
      --abi) ABI="$2"; ABI_SET="true"; shift ;;
      --headless) HEADLESS="true" ;;
      --start) START_EMULATOR="true" ;;
      --list-system-images) LIST_IMAGES_ONLY="true" ;;
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
  detect_arch
  detect_android_studio_and_sdk

  if [[ "$ABI_SET" == "false" ]]; then
    if [[ "$ARCH_TYPE" == "arm64" ]]; then
      ABI="arm64-v8a"
    else
      ABI="x86_64"
    fi
    log "ABI por defecto ajustado a ${ABI} según arquitectura."
  fi

  stage "dependencias-base"
  install_dependencies_by_os
  stage "cmdline-tools"
  install_cmdline_tools
  ensure_sdkmanager

  if [[ "$LIST_IMAGES_ONLY" == "true" ]]; then
    list_system_images
    exit 0
  fi

  stage "instalacion-sdk"
  install_sdk_components
  stage "creacion-avd"
  create_avd
  if [[ "$START_EMULATOR" == "true" ]]; then
    stage "inicio-emulador"
    start_emulator
  else
    log "AVD listo. Ejecuta '--start' o 'emulator -avd ${AVD_NAME}' para arrancar."
  fi
  log "Listo. SDK en ${ANDROID_HOME}"
}

main "$@"
