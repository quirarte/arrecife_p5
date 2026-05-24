# Arrecife C++ Prototype

Primer prototipo PC-first para iniciar la portación desde Processing/Java hacia C++.

Objetivos de esta etapa:

- Abrir webcam en una ventana nativa.
- Cargar `roi.json` y `app_config.json`.
- Dibujar una ROI orientada.
- Construir una máscara alpha basada en threshold de blanco y flood fill desde el borde del ROI.
- Definir una interfaz `HardwareController` desacoplada del backend real.

## Dependencias

- CMake 3.20+
- OpenCV 4.x

## Build

```bash
cmake -S prototype_cpp -B prototype_cpp/build
cmake --build prototype_cpp/build --config Release
```

## Run

```bash
prototype_cpp/build/arrecife_vision_prototype.exe
```

El ejecutable espera correrse desde la raíz del repo para encontrar `app_config.json` y `roi.json`.

## Teclas

- `ESC`: salir
- `,` `.`: bajar/subir `whiteThr`
- `j` `k`: bajar/subir `matrixLedCount`
- `1` `2` `3` `4`: cambiar `markerPlacement`
- Flechas: mover ancla del ROI
- `Q` `E`: rotar ROI manualmente
- `[` `]`: reducir/aumentar `extentX`
- `-` `=`: reducir/aumentar `extentY`
- `L`: recargar `roi.json`
- `S`: guardar `roi.json`
- `ESPACIO`: disparar animación de tira en hardware simulado

## Notas

- Todavía no detecta fiduciales. La rotación del ROI es manual para probar la etapa de segmentación antes de integrar ArUco.
- `HardwareController` hoy usa una implementación simulada. El siguiente paso natural es añadir `SerialHardwareController` conservando el protocolo actual (`I:n`, `1`, `S`, `z/x/v`).
