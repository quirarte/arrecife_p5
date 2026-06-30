# Plan de Portación

## Revisión rápida del repo actual

### Processing actual

- `Arrecife.pde` concentra ciclo principal, cámara, serial, UI y flujo runtime.
- `RuntimeConfig.pde` ya separa la carga de `app_config.json`.
- `BlobSegmenter.pde` concentra ROI, threshold, máscara y persistencia de `roi.json`.
- `FiducialBoof.pde` encapsula la detección BoofCV.
- `SpeciesProfile.pde` y `AssetsManager.pde` ya empujan hacia una arquitectura más modular.

### C++ existente

- `prototype_cpp/` ya resuelve una parte importante del port temprano.
- Ya existe abstracción `HardwareController`.
- Ya existe lectura inicial de `app_config.json` y `roi.json`.
- Ya existe segmentación alpha basada en ROI + threshold.
- Aún no está dentro del flujo real de `openFrameworks`.

## Propuesta de etapas pequeñas y verificables

### Etapa 0: Base openFrameworks

Objetivo:
- abrir ventana
- abrir webcam
- cargar config
- dibujar ROI

Verificación:
- compila en Visual Studio
- muestra cámara y overlay

### Etapa 1: Integración OpenCV

Objetivo:
- conectar `ofPixels`/`ofTexture` con `cv::Mat`
- portar `AlphaSegmenter`

Verificación:
- vista de máscara threshold
- guardado/carga de `roi.json`

### Etapa 2: Controles de calibración ROI

Objetivo:
- teclas `,` `.` para threshold
- `J/K` para LEDs
- mover ancla y dimensiones de ROI

Verificación:
- overlay responde a teclado
- `roi.json` se actualiza correctamente

### Etapa 3: Hardware PC

Objetivo:
- backend simulado
- backend serial con protocolo actual Arduino

Verificación:
- envío de `I:n`
- envío de `1`
- recepción de `S`, `z`, `x`, `v`

### Etapa 4: Fiduciales

Objetivo:
- evaluar migración de BoofCV Square Binary a ArUco/OpenCV
- mantener etapa de compatibilidad si los marcadores actuales no sirven

Verificación:
- detección estable de ID
- actualización de ROI desde marcador

### Etapa 5: Render y comportamiento

Objetivo:
- fondos
- peces
- comida
- audio
- spawn y comportamiento básico

Verificación:
- flujo visual completo de una especie

### Etapa 6: Preparación Raspberry Pi

Objetivo:
- mover backend hardware a interfaz común
- preparar implementación GPIO sin Arduino

Verificación:
- sin dependencias de serial en la lógica de alto nivel

## Mapa de migración sugerido

- `RuntimeConfig.pde` -> `src/config/AppConfig.*`
- `BlobSegmenter.pde` -> `src/config/RoiConfig.*` + `src/vision/*`
- `processing.serial` -> `src/hardware/SerialHardwareController.*`
- `FiducialBoof.pde` -> `src/vision/FiducialTracker.*`
- `AssetsManager.pde` -> `src/scene/AssetsManager.*`
- `SpeciesProfile.pde` -> `src/scene/SpeciesProfile.*`

## Criterio rector

No intentar portar todo el sketch a la vez. Primero consolidar:

1. captura
2. calibración
3. segmentación
4. hardware
5. fiduciales
6. render y comportamiento

