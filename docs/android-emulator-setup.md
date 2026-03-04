# Guía: android-emulator-setup.sh

Script Bash multiplataforma para instalar el SDK de Android y preparar un emulador listo para usar (AVD) con la menor fricción posible.

## Requisitos rápidos
- **Bash**, macOS, Ubuntu o Windows vía WSL.
- **Conexión a internet** para descargar SDK y dependencias.
- **Virtualización habilitada** (VT-x/AMD-V) para ejecutar el emulador.
- **macOS**: se recomienda tener **Homebrew**; si no está instalado, el script puede instalarlo o puedes hacerlo con:
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```
- El script instala **Java (OpenJDK 17)** automáticamente si no está presente.

## Uso básico
```bash
chmod +x scripts/android-emulator-setup.sh
./scripts/android-emulator-setup.sh --start
```

## Flags principales
- `--avd-name NAME` nombre del AVD (default `pixel6-api34`).
- `--api-level N` nivel de API (default `34`).
- `--device ID` dispositivo de `avdmanager` (default `pixel_6`).
- `--abi ABI` ABI de la imagen (default auto: `arm64-v8a` en ARM/Apple Silicon/Windows ARM, `x86_64` en Intel).
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
- **macOS**: usa Homebrew para instalar Java si no está presente. Si existe `~/Library/Android/sdk`, se usa como SDK por defecto; si no, `~/Android/Sdk`. En Apple Silicon se selecciona `arm64-v8a` por defecto.
- **Ubuntu/WSL**: instala OpenJDK 17 y dependencias gráficas mínimas (`libglu1-mesa`, `libpulse0`). En WSL, el emulador gráfico puede requerir WSLg; en headless funciona con `--headless`. En hosts ARM elegirá `arm64-v8a`.
- **Otras distros**: se intentará con `apt`; si no es Ubuntu, instala manualmente Java 17+ y dependencias gráficas equivalentes.

## Cómo se elige el dispositivo y la ABI
- ABI: si no especificas `--abi`, el script detecta la arquitectura y usa `arm64-v8a` en ARM y `x86_64` en Intel.
- Device: se elige automáticamente el primer dispositivo Pixel disponible desde `avdmanager list device`; si no hay Pixel, el primero de la lista.

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
