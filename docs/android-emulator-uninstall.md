# Guía: android-emulator-uninstall.sh

Script Bash multiplataforma para borrar el AVD creado por `android-emulator-setup.sh` sin tocar el SDK ni las herramientas instaladas. Funciona en macOS, Ubuntu y Windows vía WSL.

## Requisitos rápidos
- Tener instalado el SDK de Android (lo deja listo el script de setup).
- AVD creado previamente (por defecto `pixel6-api34`).

## Uso básico
```bash
chmod +x scripts/android-emulator-uninstall.sh
./scripts/android-emulator-uninstall.sh
```

## Opciones
- `--avd-name NAME` nombre del AVD a borrar (default `pixel6-api34`).
- `--yes` no pedir confirmación.
- `--help` muestra ayuda.

## Ejemplos
- Borrar el AVD por defecto:
  ```bash
  ./scripts/android-emulator-uninstall.sh
  ```
- Borrar un AVD personalizado sin pedir confirmación:
  ```bash
  ./scripts/android-emulator-uninstall.sh --avd-name pixel6-arm --yes
  ```

## Qué elimina
- Elimina el AVD indicado mediante `avdmanager delete avd -n NAME` si está disponible.
- Limpia los archivos locales restantes en `~/.android/avd/NAME.ini` y `~/.android/avd/NAME.avd/`.
- No desinstala el SDK, cmdline-tools ni otras herramientas.

## Notas por sistema operativo
- **macOS**: si existe `~/Library/Android/sdk`, se usa como `ANDROID_HOME`. No se requiere Homebrew para la desinstalación.
- **Ubuntu/WSL**: usa el SDK en `~/Android/Sdk` si está presente. Si `avdmanager` no está en el PATH, el script igualmente limpia los archivos locales.
- **Otras rutas**: puedes definir `ANDROID_HOME` o `ANDROID_SDK_ROOT` antes de ejecutar si tu SDK está en otra ubicación.

## Troubleshooting rápido
- **No encuentra el AVD**: verifica que el nombre coincida (`avdmanager list avd`). Si ya no existe, el script saldrá indicando que no hay nada que borrar.
- **avdmanager no disponible**: el script intentará borrar los archivos locales, pero no podrá actualizar los índices del SDK; considera reinstalar cmdline-tools si necesitas volver a gestionarlos.
