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
CMDLINE_TOOLS_VERSION_DEFAULT="12266719"
CMDLINE_TOOLS_URL_LINUX="${CMDLINE_TOOLS_URL_LINUX:-https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION_DEFAULT}_latest.zip}"
CMDLINE_TOOLS_URL_DARWIN="${CMDLINE_TOOLS_URL_DARWIN:-https://dl.google.com/android/repository/commandlinetools-mac-${CMDLINE_TOOLS_VERSION_DEFAULT}_latest.zip}"

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
  # Si brew ya está en PATH, listo
  if command -v brew >/dev/null 2>&1; then
    return
  fi
  # Si Homebrew está instalado pero no en PATH (p. ej. misma sesión tras instalar), cargar entorno
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return
  fi
  if [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
    return
  fi
  if [[ "$AUTO_YES" == "false" ]]; then
    read -r -p "Homebrew no está instalado. ¿Instalarlo? [y/N] " r
    [[ "$r" =~ ^[Yy]$ ]] || { err "Homebrew requerido en macOS"; exit 1; }
  fi
  log "Instalando Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Cargar Homebrew en esta sesión para usar brew sin reiniciar la shell
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  log "Homebrew instalado."
}

setup_java_home() {
  # Función auxiliar para validar que JAVA_HOME sea una ruta válida de JDK
  validate_java_home() {
    local jhome="$1"
    if [[ -z "$jhome" ]]; then
      return 1
    fi
    # Rechazar rutas del sistema
    if [[ "$jhome" == "/usr" || "$jhome" == "/bin" || "$jhome" == "/usr/bin" ]]; then
      return 1
    fi
    # Debe tener bin/java ejecutable
    if [[ ! -x "$jhome/bin/java" ]]; then
      return 1
    fi
    # Debe tener lib/ o jre/ (estructura de JDK)
    # En macOS, algunos JDKs tienen Contents/Home, pero si estamos validando JAVA_HOME
    # ya debería apuntar a Contents/Home directamente
    if [[ -d "$jhome/lib" || -d "$jhome/jre" ]]; then
      return 0
    fi
    return 1
  }
  
  # Si JAVA_HOME ya está configurado y es válido, usarlo
  if [[ -n "${JAVA_HOME:-}" ]] && validate_java_home "$JAVA_HOME"; then
    log "JAVA_HOME ya configurado: $JAVA_HOME"
    export JAVA_HOME
    return
  fi

  # Intentar detectar JAVA_HOME según el SO
  case "$OS_TYPE" in
    macos)
      # macOS tiene una utilidad para encontrar Java
      if [[ -x /usr/libexec/java_home ]]; then
        local detected_home
        detected_home="$(/usr/libexec/java_home 2>/dev/null || true)"
        if validate_java_home "$detected_home"; then
          JAVA_HOME="$detected_home"
          export JAVA_HOME
          log "JAVA_HOME detectado (macOS java_home): $JAVA_HOME"
          return
        fi
      fi
      
      # Buscar en rutas comunes de Homebrew
      local brew_paths=(
        "/opt/homebrew/opt/openjdk"
        "/opt/homebrew/opt/openjdk@17"
        "/opt/homebrew/opt/openjdk@21"
        "/opt/homebrew/opt/openjdk@19"
        "/usr/local/opt/openjdk"
        "/usr/local/opt/openjdk@17"
        "/usr/local/opt/openjdk@21"
        "/usr/local/opt/openjdk@19"
      )
      
      for path in "${brew_paths[@]}"; do
        # Verificar si el path existe y tiene java
        if [[ -d "$path" ]]; then
          # Buscar java en bin/ o en libexec/openjdk.jdk/Contents/Home/bin/
          local java_bin=""
          if [[ -x "$path/bin/java" ]]; then
            java_bin="$path/bin/java"
          elif [[ -d "$path/libexec" ]]; then
            # Homebrew a veces instala en libexec/openjdk.jdk/Contents/Home/
            local jdk_home
            jdk_home="$(find "$path/libexec" -type d -path "*/Contents/Home" 2>/dev/null | head -n1)"
            if validate_java_home "$jdk_home"; then
              JAVA_HOME="$jdk_home"
              export JAVA_HOME
              log "JAVA_HOME detectado (Homebrew libexec): $JAVA_HOME"
              return
            fi
          fi
          if [[ -x "$path/bin/java" ]] && validate_java_home "$path"; then
            JAVA_HOME="$path"
            export JAVA_HOME
            log "JAVA_HOME detectado (Homebrew): $JAVA_HOME"
            return
          fi
        fi
      done
      
      # Si java está en PATH, intentar derivar JAVA_HOME
      if command -v java >/dev/null 2>&1; then
        local java_path
        java_path="$(command -v java)"
        # Resolver symlinks (compatible con macOS y Linux)
        if command -v realpath >/dev/null 2>&1; then
          java_path="$(realpath "$java_path" 2>/dev/null || echo "$java_path")"
        elif command -v readlink >/dev/null 2>&1; then
          # En macOS, readlink no tiene -f, pero podemos intentar resolver manualmente
          local resolved="$java_path"
          local max_depth=10 depth=0
          while [[ -L "$resolved" && $depth -lt $max_depth ]]; do
            resolved="$(readlink "$resolved")"
            if [[ "$resolved" != /* ]]; then
              resolved="$(dirname "$java_path")/$resolved"
            fi
            depth=$((depth + 1))
          done
          java_path="$resolved"
        fi
        # java_path debería ser algo como /path/to/java/bin/java
        if [[ "$java_path" == */bin/java ]]; then
          local derived_home="${java_path%/bin/java}"
          # Si está en Contents/Home, usar ese como JAVA_HOME
          if [[ -d "$derived_home/Contents/Home" ]]; then
            derived_home="$derived_home/Contents/Home"
          fi
          if validate_java_home "$derived_home"; then
            JAVA_HOME="$derived_home"
            export JAVA_HOME
            log "JAVA_HOME derivado desde PATH: $JAVA_HOME"
            return
          else
            warn "Ruta $derived_home no es un JDK válido, continuando búsqueda..."
          fi
        fi
      fi
      # Último intento en macOS: usar brew --prefix (evita bucle si openjdk@17 ya está instalado)
      if command -v brew >/dev/null 2>&1 && set_java_home_from_brew; then
        return
      fi
      ;;
    ubuntu|linux|wsl)
      # En Linux, buscar en rutas comunes
      local linux_paths=(
        "/usr/lib/jvm/java-17-openjdk-$(uname -m)"
        "/usr/lib/jvm/java-17-openjdk"
        "/usr/lib/jvm/java-11-openjdk-$(uname -m)"
        "/usr/lib/jvm/java-11-openjdk"
        "/usr/lib/jvm/default-java"
      )
      
      for path in "${linux_paths[@]}"; do
        if validate_java_home "$path"; then
          JAVA_HOME="$path"
          export JAVA_HOME
          log "JAVA_HOME detectado (Linux): $JAVA_HOME"
          return
        fi
      done
      
      # Intentar derivar desde PATH
      if command -v java >/dev/null 2>&1; then
        local java_path
        java_path="$(command -v java)"
        # Resolver symlinks (compatible con macOS y Linux)
        if command -v realpath >/dev/null 2>&1; then
          java_path="$(realpath "$java_path" 2>/dev/null || echo "$java_path")"
        elif command -v readlink >/dev/null 2>&1; then
          # readlink -f funciona en Linux pero no en macOS
          if readlink -f "$java_path" >/dev/null 2>&1; then
            java_path="$(readlink -f "$java_path")"
          else
            # Fallback para macOS
            local resolved="$java_path"
            local max_depth=10 depth=0
            while [[ -L "$resolved" && $depth -lt $max_depth ]]; do
              resolved="$(readlink "$resolved")"
              if [[ "$resolved" != /* ]]; then
                resolved="$(dirname "$java_path")/$resolved"
              fi
              depth=$((depth + 1))
            done
            java_path="$resolved"
          fi
        fi
        if [[ "$java_path" == */bin/java ]]; then
          local derived_home="${java_path%/bin/java}"
          if validate_java_home "$derived_home"; then
            JAVA_HOME="$derived_home"
            export JAVA_HOME
            log "JAVA_HOME derivado desde PATH: $JAVA_HOME"
            return
          else
            warn "Ruta $derived_home no es un JDK válido, continuando búsqueda..."
          fi
        fi
      fi
      ;;
  esac
  
  # Si llegamos aquí, no se pudo detectar JAVA_HOME
  if command -v java >/dev/null 2>&1; then
    warn "Java está en PATH pero no se pudo detectar JAVA_HOME. sdkmanager puede fallar."
    warn "Configura JAVA_HOME manualmente o instala Java con Homebrew (macOS) o apt (Linux)."
    
    # Intentar instalar Java automáticamente si es posible
    case "$OS_TYPE" in
      macos)
        if command -v brew >/dev/null 2>&1; then
          if [[ "$AUTO_YES" == "true" ]]; then
            log "Intentando instalar OpenJDK 17 con Homebrew..."
            ensure_homebrew
            brew install openjdk@17 || brew install openjdk
            if set_java_home_from_brew; then
              return
            fi
            setup_java_home
            return
          else
            err "Para instalar Java automáticamente, ejecuta:"
            err "  brew install openjdk@17"
            err "O configura JAVA_HOME manualmente apuntando a tu instalación de JDK."
          fi
        else
          err "Para instalar Java, primero instala Homebrew y luego ejecuta:"
          err "  brew install openjdk@17"
          err "O configura JAVA_HOME manualmente apuntando a tu instalación de JDK."
        fi
        ;;
      ubuntu|linux|wsl)
        if [[ "$AUTO_YES" == "true" ]]; then
          log "Intentando instalar OpenJDK 17..."
          sudo apt-get update
          sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-17-jdk
          setup_java_home
          return
        else
          err "Para instalar Java automáticamente, ejecuta:"
          err "  sudo apt-get update && sudo apt-get install -y openjdk-17-jdk"
          err "O configura JAVA_HOME manualmente apuntando a tu instalación de JDK."
        fi
        ;;
      *)
        err "Instala Java (OpenJDK 17+) manualmente antes de continuar."
        ;;
    esac
  else
    err "Java no está instalado ni en PATH. Instala Java antes de continuar."
    
    # Intentar instalar Java automáticamente si es posible
    case "$OS_TYPE" in
      macos)
        if command -v brew >/dev/null 2>&1; then
          if [[ "$AUTO_YES" == "true" ]]; then
            log "Intentando instalar OpenJDK 17 con Homebrew..."
            ensure_homebrew
            brew install openjdk@17 || brew install openjdk
            if set_java_home_from_brew; then
              return
            fi
            setup_java_home
            return
          else
            err "Para instalar Java automáticamente, ejecuta:"
            err "  brew install openjdk@17"
            err "O ejecuta el script con --yes para instalación automática."
          fi
        else
          err "Para instalar Java, primero instala Homebrew y luego ejecuta:"
          err "  brew install openjdk@17"
          err "O ejecuta el script con --yes para instalación automática."
        fi
        exit 1
        ;;
      ubuntu|linux|wsl)
        if [[ "$AUTO_YES" == "true" ]]; then
          log "Intentando instalar OpenJDK 17..."
          sudo apt-get update
          sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-17-jdk
          setup_java_home
          return
        else
          err "Para instalar Java automáticamente, ejecuta:"
          err "  sudo apt-get update && sudo apt-get install -y openjdk-17-jdk"
          err "O ejecuta el script con --yes para instalación automática."
        fi
        exit 1
        ;;
      *)
        err "Instala Java (OpenJDK 17+) manualmente antes de continuar."
        exit 1
        ;;
    esac
  fi
}

set_java_home_from_brew() {
  # Establece JAVA_HOME desde la instalación de Homebrew (misma sesión, sin depender de PATH).
  local prefix jdk_home
  for pkg in openjdk@17 openjdk@21 openjdk; do
    prefix="$(brew --prefix "$pkg" 2>/dev/null)" || continue
    [[ -d "$prefix" ]] || continue
    if [[ -x "$prefix/bin/java" ]] && [[ -d "$prefix/lib" || -d "$prefix/jre" ]]; then
      JAVA_HOME="$prefix"
      export JAVA_HOME
      export PATH="$JAVA_HOME/bin:$PATH"
      log "JAVA_HOME configurado desde Homebrew ($pkg): $JAVA_HOME"
      return 0
    fi
    jdk_home="$(find "$prefix/libexec" -type d -path "*/Contents/Home" 2>/dev/null | head -n1)"
    if [[ -n "$jdk_home" && -x "$jdk_home/bin/java" ]]; then
      JAVA_HOME="$jdk_home"
      export JAVA_HOME
      export PATH="$JAVA_HOME/bin:$PATH"
      log "JAVA_HOME configurado desde Homebrew ($pkg): $JAVA_HOME"
      return 0
    fi
  done
  return 1
}

ensure_java() {
  if command -v java >/dev/null 2>&1; then
    log "Java detectado."
    setup_java_home
    return
  fi
  case "$OS_TYPE" in
    macos)
      ensure_homebrew
      log "Instalando OpenJDK 17..."
      brew install openjdk@17 || brew install openjdk
      # Fijar JAVA_HOME en esta sesión (brew no siempre añade java al PATH de la misma corrida)
      if set_java_home_from_brew; then
        return
      fi
      setup_java_home
      ;;
    ubuntu|linux|wsl)
      log "Instalando OpenJDK..."
      sudo apt-get update
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-17-jdk curl unzip zip libglu1-mesa libpulse0
      # Después de instalar, configurar JAVA_HOME
      setup_java_home
      ;;
    *)
      err "Instala manualmente Java (OpenJDK 17+) antes de continuar."
      exit 1
      ;;
  esac
}

validate_cmdline_url() {
  # Valida forma básica y dominio oficial para cmdline-tools; devuelve 0 si coincide patrón oficial.
  local url="$1"
  local origin="$2"
  local expected_re='^https://dl\.google\.com/android/repository/commandlinetools-(mac|linux)-[0-9]+_latest\.zip$'

  if [[ -z "$url" ]]; then
    warn "URL de cmdline-tools vacía (origen=${origin})."
    return 1
  fi

  if [[ ! "$url" =~ ^https?:// ]]; then
    warn "URL de cmdline-tools sin esquema http/https (origen=${origin}): $url"
    return 1
  fi

  if [[ "$url" =~ ^https?://d1\.google\.com ]]; then
    warn "Dominio d1.google.com no es el oficial de descargas; podría fallar (origen=${origin})."
  fi

  if [[ ! "$url" =~ commandline ]]; then
    warn "La URL no contiene 'commandline' en el nombre esperado (origen=${origin}): $url"
    return 1
  fi

  if [[ "$url" =~ $expected_re ]]; then
    return 0
  fi

  warn "La URL no coincide con el patrón oficial esperado (origen=${origin}): $url"
  return 1
}

download_cmdline_tools() {
  local primary_url fallback_url dynamic_url tmpdir dest http_code stderr_file attempt_url size_bytes
  tmpdir="$(mktemp -d)"
  case "$OS_TYPE" in
    macos)
      primary_url="$CMDLINE_TOOLS_URL_DARWIN"
      fallback_url="https://dl.google.com/android/repository/commandlinetools-mac-${CMDLINE_TOOLS_VERSION_DEFAULT}_latest.zip"
      ;;
    ubuntu|linux|wsl)
      primary_url="$CMDLINE_TOOLS_URL_LINUX"
      fallback_url="https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION_DEFAULT}_latest.zip"
      ;;
    *)
      err "SO no soportado para descarga automática de cmdline-tools"
      exit 1
      ;;
  esac

  dest="$tmpdir/cmdline-tools.zip"
  stderr_file="$tmpdir/curl.stderr"

  # Intento dinámico: descubrir la última versión publicada en repository2-1.xml
  resolve_latest_cmdline_url_for_os() {
    local os_tag="$1" tmp xml_url resolved
    tmp="$(mktemp)"
    xml_url="https://dl.google.com/android/repository/repository2-1.xml"
    if curl -fsSL --connect-timeout 10 --max-time 25 "$xml_url" -o "$tmp"; then
      resolved="$(
        grep -o "commandlinetools-${os_tag}-[0-9]\\+_latest.zip" "$tmp" \
        | sort -t'-' -k3,3Vr \
        | head -n1
      )"
      rm -f "$tmp"
      if [[ -n "$resolved" ]]; then
        printf "https://dl.google.com/android/repository/%s" "$resolved"
        return 0
      fi
    fi
    rm -f "$tmp"
    return 1
  }

  # Lista de intentos: priorizar URL dinámica (más reciente), luego override/env, y finalmente fallback conocido.
  local attempts=()
  local dynamic_url=""

  if dynamic_url="$(resolve_latest_cmdline_url_for_os "$([[ "$OS_TYPE" == "macos" ]] && echo "mac" || echo "linux")")"; then
    if [[ "$dynamic_url" != "$primary_url" && "$dynamic_url" != "$fallback_url" ]]; then
      log "URL dinámica detectada para cmdline-tools: $dynamic_url"
      attempts+=("$dynamic_url")
    fi
  else
    warn "No se pudo resolver URL dinámica desde repository2-1.xml; usando fallback conocido."
  fi

  # Agregar URL primaria (override/env) si es diferente a la dinámica
  if [[ -n "$primary_url" && "$primary_url" != "$dynamic_url" ]]; then
    attempts+=("$primary_url")
  fi

  # Agregar fallback si es diferente a las anteriores
  if [[ "$fallback_url" != "$primary_url" && "$fallback_url" != "$dynamic_url" && -n "$fallback_url" ]]; then
    attempts+=("$fallback_url")
  fi

  local total_attempts="${#attempts[@]}"
  local idx

  for idx in "${!attempts[@]}"; do
    attempt_url="${attempts[$idx]}"
    [[ -z "$attempt_url" ]] && continue

    if validate_cmdline_url "$attempt_url" "env/default"; then
      log "Descargando cmdline-tools desde $attempt_url..."
    else
      warn "URL de cmdline-tools no parece oficial: $attempt_url (origen=env/default). Intentando descarga igualmente."
    fi

    http_code="$(curl -w '%{http_code}' -L --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 300 -o "$dest" "$attempt_url" 2>"$stderr_file" || true)"

    if [[ "$http_code" == "200" && -s "$dest" ]]; then
      size_bytes="$(wc -c <"$dest" | tr -d ' ')"
      log "Descarga completada (HTTP $http_code, ${size_bytes} bytes) -> $dest"
      printf "%s\n" "$dest"   # solo la ruta por stdout
      return
    fi

    warn "Descarga falló (HTTP ${http_code:-?}) desde $attempt_url"
    warn "Detalle curl: $(tr '\n' ' ' < "$stderr_file")"

    if (( idx + 1 < total_attempts )); then
      warn "Probando URL alternativa conocida para cmdline-tools..."
    fi
  done

  err "No se pudo descargar cmdline-tools tras probar URLs (último intento: ${attempt_url:-?}). Define CMDLINE_TOOLS_URL_DARWIN/CMDLINE_TOOLS_URL_LINUX o revisa conectividad."
  exit 1
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
  if [[ -z "$zip_path" ]]; then
    err "Descarga de cmdline-tools devolvió una ruta vacía."
    exit 1
  fi
  if [[ ! -f "$zip_path" ]]; then
    err "El archivo de cmdline-tools no se encontró en $zip_path. Revisa permisos o antivirus."
    exit 1
  fi
  if [[ ! -s "$zip_path" ]]; then
    err "El archivo descargado está vacío ($zip_path). Verifica la URL o la conectividad."
    exit 1
  fi
  local tmpdir
  tmpdir="$(mktemp -d)"
  if ! unzip -q "$zip_path" -d "$tmpdir"; then
    err "Fallo al descomprimir cmdline-tools desde $zip_path. Puedes reintentar definiendo CMDLINE_TOOLS_URL_DARWIN/CMDLINE_TOOLS_URL_LINUX."
    exit 1
  fi
  if [[ ! -d "$tmpdir/cmdline-tools" ]]; then
    err "El ZIP descargado no contiene la carpeta cmdline-tools esperada. Archivo: $zip_path"
    exit 1
  fi
  # Google distribuye como cmdline-tools; lo movemos a latest
  mv "$tmpdir/cmdline-tools" "$target"
  log "cmdline-tools instalado en $target"
}

ensure_paths() {
  export ANDROID_HOME
  export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
  export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
  # Asegurar que JAVA_HOME esté configurado y exportado
  if [[ -n "${JAVA_HOME:-}" ]]; then
    export JAVA_HOME
  fi
}

ensure_sdkmanager() {
  ensure_paths
  # Asegurar que JAVA_HOME esté configurado antes de usar sdkmanager
  if [[ -z "${JAVA_HOME:-}" ]]; then
    setup_java_home
  fi
  if ! command -v sdkmanager >/dev/null 2>&1; then
    err "sdkmanager no encontrado tras instalar cmdline-tools."
    exit 1
  fi
  # Verificar que sdkmanager puede encontrar Java
  if [[ -n "${JAVA_HOME:-}" ]]; then
    log "Usando JAVA_HOME: $JAVA_HOME"
  else
    warn "JAVA_HOME no configurado. sdkmanager puede fallar si no encuentra Java en PATH."
  fi
}

accept_licenses() {
  log "Aceptando licencias de Android SDK..."
  
  # Validar JAVA_HOME antes de continuar
  if [[ -z "${JAVA_HOME:-}" ]] || [[ ! -x "${JAVA_HOME}/bin/java" ]]; then
    err "JAVA_HOME no está configurado correctamente: ${JAVA_HOME:-unset}"
    return 1
  fi
  
  # Usar timeout si está disponible (timeout en Linux/macOS con coreutils)
  local timeout_cmd=""
  if command -v timeout >/dev/null 2>&1; then
    timeout_cmd="timeout 60"
  elif command -v gtimeout >/dev/null 2>&1; then
    timeout_cmd="gtimeout 60"
  fi
  
  # Intentar aceptar licencias con timeout (141 = SIGPIPE cuando yes termina, es éxito)
  local license_output license_exit=0
  license_output="$(mktemp)"
  
  if [[ -n "$timeout_cmd" ]]; then
    $timeout_cmd bash -c "yes | sdkmanager --licenses" >"$license_output" 2>&1 || license_exit=$?
  else
    (yes | head -n 200 | sdkmanager --licenses) >"$license_output" 2>&1 || license_exit=$?
  fi
  
  if [[ $license_exit -ne 0 && $license_exit -ne 141 ]]; then
    warn "No se pudieron aceptar todas las licencias automáticamente (exit=$license_exit)."
    cat "$license_output" >&2
    rm -f "$license_output"
    return 1
  fi
  
  rm -f "$license_output"
  return 0
}

install_sdk_components() {
  ensure_sdkmanager
  
  # Validar JAVA_HOME antes de continuar
  if [[ -z "${JAVA_HOME:-}" ]] || [[ ! -x "${JAVA_HOME}/bin/java" ]]; then
    err "JAVA_HOME no está configurado correctamente: ${JAVA_HOME:-unset}"
    err "sdkmanager requiere JAVA_HOME válido."
    
    # Intentar instalar/configurar Java automáticamente
    case "$OS_TYPE" in
      macos)
        if command -v brew >/dev/null 2>&1; then
          if [[ "$AUTO_YES" == "true" ]]; then
            log "Intentando instalar OpenJDK 17 con Homebrew..."
            ensure_homebrew
            brew install openjdk@17 || brew install openjdk
            set_java_home_from_brew || true
            setup_java_home
            # Verificar nuevamente después de la instalación
            if [[ -z "${JAVA_HOME:-}" ]] || [[ ! -x "${JAVA_HOME}/bin/java" ]]; then
              err "JAVA_HOME aún no está configurado después de instalar Java."
              err "Para configurar manualmente, ejecuta:"
              err "  brew install openjdk@17"
              err "  export JAVA_HOME=\$(/usr/libexec/java_home -v 17)"
              exit 1
            fi
          else
            err "Para instalar Java automáticamente, ejecuta:"
            err "  brew install openjdk@17"
            err "O ejecuta el script con --yes para instalación automática."
            exit 1
          fi
        else
          err "Para instalar Java, primero instala Homebrew y luego ejecuta:"
          err "  brew install openjdk@17"
          err "O ejecuta el script con --yes para instalación automática."
          exit 1
        fi
        ;;
      ubuntu|linux|wsl)
        if [[ "$AUTO_YES" == "true" ]]; then
          log "Intentando instalar OpenJDK 17..."
          sudo apt-get update
          sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-17-jdk
          setup_java_home
          # Verificar nuevamente después de la instalación
          if [[ -z "${JAVA_HOME:-}" ]] || [[ ! -x "${JAVA_HOME}/bin/java" ]]; then
            err "JAVA_HOME aún no está configurado después de instalar Java."
            err "Para configurar manualmente, ejecuta:"
            err "  sudo apt-get update && sudo apt-get install -y openjdk-17-jdk"
            err "  export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-\$(uname -m)"
            exit 1
          fi
        else
          err "Para instalar Java automáticamente, ejecuta:"
          err "  sudo apt-get update && sudo apt-get install -y openjdk-17-jdk"
          err "O ejecuta el script con --yes para instalación automática."
          exit 1
        fi
        ;;
      *)
        err "Instala Java (OpenJDK 17+) manualmente antes de continuar."
        exit 1
        ;;
    esac
  fi
  
  # Aceptar licencias antes de instalar componentes (requerido para instalación no interactiva)
  if ! accept_licenses; then
    warn "No se pudieron aceptar todas las licencias automáticamente. Algunos componentes pueden fallar."
  fi
  
  local platform="platforms;android-${API_LEVEL}"
  local sys_image="system-images;android-${API_LEVEL};google_apis;${ABI}"
  log "Instalando componentes SDK (platform-tools, emulator, ${platform}, ${sys_image})..."
  
  # Capturar salida de sdkmanager para mejor diagnóstico
  local sdk_output sdk_exit_code timeout_cmd
  sdk_output="$(mktemp)"
  
  # Usar timeout si está disponible
  timeout_cmd=""
  if command -v timeout >/dev/null 2>&1; then
    timeout_cmd="timeout 600"
  elif command -v gtimeout >/dev/null 2>&1; then
    timeout_cmd="gtimeout 600"
  fi
  
  # sdkmanager a veces devuelve 141 (SIGPIPE) pese a instalar correctamente. Permitimos 0 o 141.
  if [[ -n "$timeout_cmd" ]]; then
    if $timeout_cmd bash -c "yes | sdkmanager \"platform-tools\" \"emulator\" \"$platform\" \"$sys_image\"" >"$sdk_output" 2>&1; then
      sdk_exit_code=0
    else
      sdk_exit_code=$?
    fi
  else
    # Sin timeout, usar yes con límite de líneas
    if (yes | head -n 200 | sdkmanager "platform-tools" "emulator" "$platform" "$sys_image") >"$sdk_output" 2>&1; then
      sdk_exit_code=0
    else
      sdk_exit_code=$?
    fi
  fi
  
  # Mostrar salida si hay problemas
  if [[ $sdk_exit_code -ne 0 && $sdk_exit_code -ne 141 ]]; then
    err "Salida de sdkmanager:"
    cat "$sdk_output" >&2
    err "sdkmanager falló instalando componentes (exit=$sdk_exit_code). Revisa conectividad y permisos."
    err "JAVA_HOME actual: ${JAVA_HOME:-unset}"
    rm -f "$sdk_output"
    exit $sdk_exit_code
  fi
  
  if [[ $sdk_exit_code -eq 141 ]]; then
    warn "sdkmanager terminó con código 141 (SIGPIPE) pero puede haber instalado paquetes; continuando."
  fi
  
  rm -f "$sdk_output"
}

components_installed() {
  local missing=()

  [[ -x "$ANDROID_HOME/platform-tools/adb" ]] || missing+=("platform-tools")
  [[ -x "$ANDROID_HOME/emulator/emulator" ]]   || missing+=("emulator")
  [[ -d "$ANDROID_HOME/platforms/android-${API_LEVEL}" ]] || missing+=("platforms;android-${API_LEVEL}")
  [[ -d "$ANDROID_HOME/system-images/android-${API_LEVEL}/google_apis/${ABI}" ]] || missing+=("system-images;android-${API_LEVEL};google_apis;${ABI}")

  if [[ ${#missing[@]} -eq 0 ]]; then
    log "Componentes SDK requeridos ya presentes; se omite instalación."
    return 0
  else
    warn "Faltan componentes SDK: ${missing[*]}"
    return 1
  fi
}

list_system_images() {
  ensure_sdkmanager
  sdkmanager --list | grep "system-images;android-" || true
}

pick_device_id() {
  local device_list chosen
  device_list="$(avdmanager list device | awk -F '[: ]+' '/id:/{print $2}' | tr -d ' ')"
  # Prioriza Pixel 6/7 phone; evita tablets
  chosen="$(echo "$device_list" | grep -E '^pixel_6$|^pixel_7' | head -n1 || true)"
  if [[ -z "$chosen" ]]; then
    chosen="$(echo "$device_list" | grep -E '^pixel' | grep -vi 'tablet' | head -n1 || true)"
  fi
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

  # Solo elegir automáticamente si no se especificó device
  if [[ -z "${DEVICE_ID:-}" || "${DEVICE_ID}" == "auto" ]]; then
    pick_device_id
  else
    log "Usando dispositivo ${DEVICE_ID}"
  fi
  
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
      --start) START_EMULATOR="true"; AUTO_YES="true" ;;
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

  if components_installed; then
    log "Saltando descarga de componentes; continuando."
  else
    stage "instalacion-sdk"
    install_sdk_components
  fi
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
