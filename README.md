# Android Emulator Scripts

Scripts Bash multiplataforma para instalar o borrar un emulador (AVD) en macOS, Ubuntu o Windows vía WSL.

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
