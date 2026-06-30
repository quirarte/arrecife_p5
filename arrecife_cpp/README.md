# arrecife_cpp

Primera base del port a C++ usando `openFrameworks`, con enfoque PC-first en Windows.

## Objetivo de esta etapa

Esta carpeta arranca la portación real en pasos pequeños:

1. Crear proyecto base en `openFrameworks`.
2. Verificar webcam.
3. Cargar `app_config.json` y `roi.json`.
4. Dibujar ROI y controles base.
5. Integrar OpenCV en la siguiente etapa para threshold y alpha mask.

## Decisión de arquitectura

El repo ya tiene un `prototype_cpp/` útil. Lo tomamos como laboratorio de visión y referencia de lógica, pero el proyecto principal nuevo queda aquí en `arrecife_cpp/` con estructura orientada a crecer hacia:

- `config`: carga de `app_config.json` y `roi.json`
- `hardware`: interfaz abstracta y backend simulado/serial/GPIO
- `vision`: pipeline de cámara, ROI, threshold, segmentación y luego fiduciales
- `scene`: render, fondos, peces, comida y comportamiento
- `audio`: reproducción y mapeo por especie

## Estructura inicial

```text
arrecife_cpp/
  README.md
  PORTING_PLAN.md
  src/
    main.cpp
    ofApp.h
    ofApp.cpp
    config/
      AppConfig.h
      AppConfig.cpp
      RoiConfig.h
      RoiConfig.cpp
    hardware/
      HardwareController.h
    vision/
      VisionPipeline.h
      VisionPipeline.cpp
```

## Estado actual de este corte

- Abre webcam con `ofVideoGrabber`.
- Lee `../app_config.json` y `../roi.json` desde la raíz del repo.
- Dibuja overlay con ROI orientada.
- Mantiene `HardwareController` desacoplado desde el inicio.
- Deja `VisionPipeline` como punto de extensión para la etapa OpenCV.

## Cómo crear el proyecto de openFrameworks

Usa esta carpeta como contenido de `src/` para un proyecto nuevo llamado `arrecife_cpp` en `openFrameworks`.

Sugerencia práctica:

1. Crear un proyecto vacío `openFrameworks` llamado `arrecife_cpp`.
2. Sustituir su carpeta `src` por `arrecife_cpp/src`.
3. Abrir la solución en Visual Studio.
4. Verificar que compila y que la webcam abre.

## Primera verificación esperada

Al correr esta base deberías ver:

- cámara en vivo
- texto con `camIndex`, `whiteThr`, `matrixLedCount`
- polígono verde de ROI
- ancla amarilla

## Siguiente paso recomendado

Integrar OpenCV dentro de este mismo proyecto para mover a `vision/` la lógica que hoy vive en `prototype_cpp`:

- `RoiConfig`
- threshold
- máscara alpha
- flood fill desde borde

