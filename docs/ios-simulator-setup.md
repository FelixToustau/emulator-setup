# Guía: ios-simulator-setup.sh

Script Bash para macOS que verifica/instala Xcode Command Line Tools y prepara un simulador iOS listo para usar con la menor fricción posible.

## Requisitos rápidos

- **macOS** (cualquier versión reciente). Los simuladores iOS solo funcionan en macOS.
- **Conexión a internet** para descargar Command Line Tools si es necesario.
- **Permisos de administrador** (puede requerirse para instalar Command Line Tools).

## Uso básico

```bash
chmod +x scripts/ios-simulator-setup.sh
./scripts/ios-simulator-setup.sh --start
```

## Flags principales

- `--simulator-name NAME` nombre del simulador (default `iphone-ios-latest`).
- `--device-type TYPE` tipo de dispositivo (default `auto` - detecta automáticamente el más reciente, prioriza iPhone 15/15 Pro).
- `--ios-version VERSION` versión de iOS (default `latest` - detecta automáticamente la más reciente disponible).
- `--list-runtimes` lista runtimes iOS disponibles y termina.
- `--start` arranca el simulador tras la creación/verificación.
- `--yes` suprime confirmaciones (modo no interactivo).
- `--help` muestra ayuda.

## Ejemplos

- Crear y arrancar con defaults (iPhone más reciente, iOS más reciente):
  ```bash
  ./scripts/ios-simulator-setup.sh --start
  ```

- Crear simulador con dispositivo y versión específicos:
  ```bash
  ./scripts/ios-simulator-setup.sh --device-type "iPhone 15 Pro" --ios-version "iOS 17.0" --start
  ```

- Solo listar runtimes disponibles:
  ```bash
  ./scripts/ios-simulator-setup.sh --list-runtimes
  ```

- Crear simulador sin arrancar:
  ```bash
  ./scripts/ios-simulator-setup.sh --simulator-name "mi-iphone"
  ```

## Notas específicas de macOS

- **Xcode vs Command Line Tools**: El script funciona con Xcode completo o solo con Command Line Tools. Si no tienes Xcode instalado, el script instalará Command Line Tools (más ligero y suficiente para `simctl`).
- **Instalación de Command Line Tools**: Si no están instalados, el script abrirá un diálogo del sistema. Debes completar la instalación manualmente en ese diálogo.
- **Arquitectura**: Funciona tanto en Intel (x86_64) como en Apple Silicon (arm64). Los simuladores se ejecutan nativamente en ambas arquitecturas.
- **Runtimes iOS**: Los runtimes iOS deben estar instalados. Si no tienes runtimes instalados, instálalos desde Xcode: Xcode > Settings > Platforms (o Platforms and Simulators).

## Cómo se elige el dispositivo y el runtime

- **Runtime iOS**: Si no especificas `--ios-version`, el script detecta automáticamente el runtime iOS más reciente disponible en tu sistema.
- **Tipo de dispositivo**: Si no especificas `--device-type` (o usas `auto`), el script prioriza:
  1. iPhone 15 Pro
  2. iPhone 15
  3. iPhone 14 Pro
  4. iPhone 14
  5. Cualquier otro iPhone disponible

## Archivos y rutas importantes

- **Simuladores**: Los simuladores se almacenan en `~/Library/Developer/CoreSimulator/Devices/`.
- **Command Line Tools**: Se instalan en `/Library/Developer/CommandLineTools/` (o la ruta que devuelva `xcode-select -p`).
- **Xcode**: Si está instalado, en `/Applications/Xcode.app`.

## Cómo arrancar o administrar después

- Arrancar un simulador existente:
  ```bash
  xcrun simctl boot iphone-ios-latest
  open -a Simulator
  ```

- Listar simuladores:
  ```bash
  xcrun simctl list devices
  ```

- Apagar un simulador:
  ```bash
  xcrun simctl shutdown iphone-ios-latest
  ```

- Eliminar un simulador:
  ```bash
  ./scripts/ios-simulator-uninstall.sh --simulator-name iphone-ios-latest
  ```

## Troubleshooting rápido

- **"Command Line Tools no se pudieron verificar"**: Completa la instalación en el diálogo del sistema y vuelve a ejecutar el script. Si el problema persiste, ejecuta manualmente: `xcode-select --install`.
- **"No se encontraron runtimes iOS disponibles"**: Instala un runtime iOS desde Xcode: Xcode > Settings > Platforms. O instala Xcode completo desde la App Store.
- **"Tipo de dispositivo no encontrado"**: Verifica que el nombre del dispositivo sea exacto. Lista los disponibles con: `xcrun simctl list devicetypes`.
- **"Runtime no encontrado"**: Verifica que la versión de iOS esté instalada. Lista los disponibles con: `xcrun simctl runtime list` o usa `--list-runtimes`.
- **El simulador no arranca**: Verifica que Simulator.app esté disponible. Si usas solo Command Line Tools, puede que necesites instalar Xcode completo para la interfaz gráfica.

## Diferencias con Android

- **Solo macOS**: A diferencia de Android, los simuladores iOS solo funcionan en macOS.
- **No descarga SDK**: Xcode/Command Line Tools ya incluyen todo lo necesario.
- **Runtimes vs System Images**: iOS usa "runtimes" (iOS 17.0, iOS 18.0, etc.) en lugar de "system images".
- **Nombres de dispositivos**: Los tipos de dispositivos usan nombres legibles como "iPhone 15 Pro" en lugar de IDs como en Android.
