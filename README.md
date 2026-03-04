# Android Emulator Scripts

Scripts Bash multiplataforma para instalar o borrar un emulador (AVD) en macOS, Ubuntu o Windows vía WSL.

## Requisitos previos

- **Bash** y permisos de ejecución en el script (p. ej. `chmod +x scripts/android-emulator-setup.sh`).
- **Conexión a internet** (descargas del SDK, cmdline-tools, etc.).
- **macOS**: se recomienda tener **Homebrew** instalado; el script puede instalarlo si falta. Si quieres instalarlo tú mismo:
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```
- **Ubuntu/WSL**: se necesita `sudo` y `apt` para instalar OpenJDK y dependencias.

Con esto, el script se encarga de instalar **Java (OpenJDK 17)** automáticamente si no está presente.

## Uso rápido
- Instalar y crear/arrancar el AVD por defecto:
  ```bash
  chmod +x scripts/android-emulator-setup.sh
  ./scripts/android-emulator-setup.sh --start
  ```
- Borrar el AVD por defecto (sin tocar el SDK):
  ```bash
  chmod +x scripts/android-emulator-uninstall.sh
  ./scripts/android-emulator-uninstall.sh
  ```

## Qué incluye
- `android-emulator-setup.sh`: instala dependencias (Java/OpenJDK, cmdline-tools, platform-tools, emulator), descarga imagen Pixel 6 API 34 con ABI acorde a la arquitectura, crea el AVD y opcionalmente lo arranca.
- `android-emulator-uninstall.sh`: elimina un AVD existente (por defecto `pixel6-api34`) y limpia sus archivos locales sin desinstalar el SDK ni cmdline-tools.

## Ayuda y opciones
- Setup: `./scripts/android-emulator-setup.sh --help`
- Uninstall: `./scripts/android-emulator-uninstall.sh --help`

## Documentación
- Guía de instalación y uso del setup: [`docs/android-emulator-setup.md`](docs/android-emulator-setup.md)
- Guía de desinstalación del AVD: [`docs/android-emulator-uninstall.md`](docs/android-emulator-uninstall.md)
