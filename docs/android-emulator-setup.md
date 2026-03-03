# Guía: android-emulator-setup.sh

Script Bash multiplataforma para instalar el SDK de Android y preparar un emulador listo para usar (AVD) con la menor fricción posible.

## Requisitos rápidos
- macOS, Ubuntu o Windows vía WSL.
- Conectividad a internet para descargar SDK y dependencias.
- Virtualización habilitada (VT-x/AMD-V) para ejecutar el emulador.

## Uso básico
```bash
chmod +x scripts/android-emulator-setup.sh
./scripts/android-emulator-setup.sh --start
```

## Flags principales
- `--avd-name NAME` nombre del AVD (default `pixel6-api34`).
- `--api-level N` nivel de API (default `34`).
- `--device ID` dispositivo de `avdmanager` (default `pixel_6`).
- `--abi ABI` ABI de la imagen (default `x86_64`).
- `--headless` inicia el emulador sin ventana (`-no-window`).
- `--start` arranca el emulador tras la instalación/creación del AVD.
- `--list-system-images` lista imágenes disponibles y termina.
- `--yes` suprime confirmaciones (modo no interactivo).
- `--help` muestra ayuda.

Variables útiles:
- `ANDROID_HOME` o `ANDROID_SDK_ROOT` para personalizar la ruta del SDK.

## Ejemplos
- Crear y arrancar con defaults:
  ```bash
  ./scripts/android-emulator-setup.sh --start
  ```
- Crear AVD ARM y sin ventana:
  ```bash
  ./scripts/android-emulator-setup.sh --abi arm64-v8a --avd-name pixel6-arm --headless
  ```
- Solo listar imágenes disponibles:
  ```bash
  ./scripts/android-emulator-setup.sh --list-system-images
  ```

## Notas por sistema operativo
- **macOS**: usa Homebrew para instalar Java si no está presente. El SDK se coloca en `~/Android/Sdk`.
- **Ubuntu/WSL**: instala OpenJDK 17 y dependencias gráficas mínimas (`libglu1-mesa`, `libpulse0`). En WSL, el emulador gráfico puede requerir WSLg; en headless funciona con `--headless`.
- **Otras distros**: se intentará con `apt`; si no es Ubuntu, instala manualmente Java 17+ y dependencias gráficas equivalentes.

## Archivos y rutas importantes
- SDK y AVDs: `~/Android/Sdk` (configurable con `ANDROID_HOME`).
- AVDs creados: `~/.android/avd/`.
- Binarios clave añadidos al PATH en la sesión del script:
  - `cmdline-tools/latest/bin` (sdkmanager, avdmanager)
  - `platform-tools` (adb)
  - `emulator`

## Cómo arrancar o administrar después
- Arrancar un AVD existente:
  ```bash
  emulator -avd pixel6-api34
  ```
- Listar AVDs:
  ```bash
  avdmanager list avd
  ```
- Ver dispositivos conectados:
  ```bash
  adb devices
  ```

## Troubleshooting rápido
- **No arranca el emulador**: verifica que la virtualización esté habilitada en BIOS/firmware. Usa `--headless` en entornos sin soporte gráfico.
- **Faltan librerías** (Ubuntu/WSL): instala `libgl1-mesa-dev`, `qemu-kvm`, `libvirt-daemon-system` si usas KVM.
- **Timeout al descargar**: reintenta con una red más estable; el script descarga cmdline-tools directamente desde Google.

## Referencias
- Guía inspirada en flujos mostrados en [YouTube](https://www.youtube.com/watch?v=PJItbh2fNl4&t=231s) y accesos auxiliares en [Google Aimode](https://share.google/aimode/uQ12qDEsgAuKdzLBo).
