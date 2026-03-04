# Guía: ios-simulator-uninstall.sh

Script Bash para macOS que borra el simulador creado por `ios-simulator-setup.sh` sin tocar Xcode ni Command Line Tools. Funciona solo en macOS.

## Requisitos rápidos

- Tener Command Line Tools o Xcode instalado (lo deja listo el script de setup).
- Simulador creado previamente (por defecto `iphone-ios-latest`).

## Uso básico

```bash
chmod +x scripts/ios-simulator-uninstall.sh
./scripts/ios-simulator-uninstall.sh
```

## Opciones

- `--simulator-name NAME` nombre del simulador a borrar (default `iphone-ios-latest`).
- `--yes` no pedir confirmación.
- `--help` muestra ayuda.

## Ejemplos

- Borrar el simulador por defecto:
  ```bash
  ./scripts/ios-simulator-uninstall.sh
  ```

- Borrar un simulador personalizado sin pedir confirmación:
  ```bash
  ./scripts/ios-simulator-uninstall.sh --simulator-name mi-iphone --yes
  ```

## Qué elimina

- Elimina el simulador indicado mediante `xcrun simctl delete <uuid>`.
- Apaga el simulador automáticamente si está arrancado antes de eliminarlo.
- No desinstala Xcode, Command Line Tools ni otros simuladores.

## Notas específicas de macOS

- **Solo macOS**: Este script solo funciona en macOS, ya que los simuladores iOS son exclusivos de macOS.
- **Command Line Tools requeridos**: El script requiere que Command Line Tools estén instalados para usar `xcrun simctl`.
- **Ubicación de simuladores**: Los simuladores se almacenan en `~/Library/Developer/CoreSimulator/Devices/`, pero el script los elimina usando `simctl`, que es la forma recomendada.

## Troubleshooting rápido

- **"Simulador no encontrado"**: Verifica que el nombre coincida. Lista los simuladores disponibles con: `xcrun simctl list devices`. Si el simulador ya no existe, el script saldrá indicando que no hay nada que borrar.
- **"Command Line Tools no están instalados"**: Instala Command Line Tools ejecutando: `xcode-select --install`.
- **"xcrun simctl no funciona"**: Verifica que Command Line Tools estén correctamente instalados. Puede requerir reinstalar: `xcode-select --install`.
- **El simulador aún aparece después de eliminar**: Cierra y vuelve a abrir Simulator.app para refrescar la lista.
