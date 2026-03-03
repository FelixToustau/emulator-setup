# Android Emulator Setup Script

Script Bash para instalar el SDK de Android y dejar un emulador (AVD) listo en macOS, Ubuntu o Windows vía WSL con mínimos pasos manuales.

## Uso rápido
```bash
chmod +x scripts/android-emulator-setup.sh
./scripts/android-emulator-setup.sh --start
```

## ¿Qué hace?
- Detecta el sistema operativo (macOS, Ubuntu, WSL).
- Instala dependencias: Java/OpenJDK, cmdline-tools, platform-tools y emulator.
- Ajusta `ANDROID_HOME` a `~/Library/Android/sdk` en macOS si existe, o `~/Android/Sdk` en otros casos.
- Descarga la imagen por defecto (Pixel 6, API 34, Google APIs) con ABI auto: `arm64-v8a` en ARM/Apple Silicon/Windows ARM, `x86_64` en Intel.
- Elige automáticamente un dispositivo válido (prioriza Pixel) al crear el AVD y opcionalmente lo arranca (`--start`).

## Configuración y ayuda
El script admite flags para ajustar nombre del AVD, API level, ABI, modo headless y listado de imágenes disponibles. Consulta la ayuda integrada:
```bash
./scripts/android-emulator-setup.sh --help
```

## Documentación detallada
Encuentra instrucciones paso a paso, ejemplos y troubleshooting en [`docs/android-emulator-setup.md`](docs/android-emulator-setup.md).

## Referencias
- Flujo inspirado en [YouTube](https://www.youtube.com/watch?v=PJItbh2fNl4&t=231s) y recursos de [Google Aimode](https://share.google/aimode/uQ12qDEsgAuKdzLBo).
