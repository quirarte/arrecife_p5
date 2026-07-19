# Inventario técnico — sketch de Processing "Arrecife"

> Generado el 2026-07-17 a partir de lectura completa de los 16 archivos `.pde`,
> `app_config.json`, `roi.json` y `luces/luces.ino`. Es el inventario de referencia
> para decidir, archivo por archivo, cómo se traduce a openFrameworks/C++.

---

## 1. Librerías externas (imports)

| Librería Processing | Dónde se usa | Rol |
|---|---|---|
| `processing.video.*` | `Arrecife.pde` | Captura de webcam (`Capture`). |
| `processing.sound.*` | `Arrecife.pde`, `AssetsManager.pde` | Reproducción de audio (`SoundFile`). |
| `processing.serial.*` | `Arrecife.pde` | Comunicación con Arduino (`Serial`). |
| `java.util.ArrayList` | `Arrecife.pde` | Colecciones (peces, comida). |
| `java.io.File` | `BlobSegmenter.pde` | Verificar existencia de `roi.json`. |
| `java.awt.image.BufferedImage` | `FiducialBoof.pde` | Puente Processing → BoofCV. |
| **BoofCV** (`boofcv.abst.fiducial.*`, `boofcv.factory.fiducial.*`, `boofcv.struct.image.GrayU8`, `boofcv.io.image.ConvertBufferedImage`) | `FiducialBoof.pde` | Detección de marcadores fiduciales "Square Binary". |
| **GeoRegression** (`georegression.struct.shapes.Polygon2D_F64`, `georegression.struct.point.Point2D_F64`) | `FiducialBoof.pde` | Tipos geométricos que devuelve BoofCV. |

**Nota importante:** BoofCV + GeoRegression son librerías Java puras — **no existen para C++**. Es la única dependencia sin traducción directa (ver sección 6).

---

## 2. APIs de Processing usadas, por categoría

### 2.1 Ciclo de vida / ventana
- `settings()`, `setup()`, `draw()` — ciclo estándar.
- `size(w, h, P2D)` — ventana 1280×720, renderer P2D (acelerado por GPU, equivalente conceptual a `ofSetupOpenGL` + `ofBackground`/render normal en oF).
- `exit()` — usado si falla la carga del fondo inicial o no hay webcams.

### 2.2 Dibujo 2D
- `background()`, `image()`, `imageMode(CENTER/CORNER)`.
- `beginShape(QUAD_STRIP)` / `vertex(x,y,u,v)` / `endShape()` — cuerpo del pez (textura estirada sobre una tira de quads).
- `beginShape()` / `vertex(x,y)` / `endShape(CLOSE)` — polígonos regulares de la comida.
- `ellipse()`, `rect()` (con esquinas redondeadas), `line()`.
- `fill()`, `noFill()`, `stroke()`, `noStroke()`, `strokeWeight()`, `pushStyle()`/`popStyle()`.
- `pushMatrix()`/`popMatrix()`, `translate()`, `rotate()`.
- `texture()`, `textureMode(IMAGE)`.
- `colorMode(HSB, 360,100,100,255)`, `color()`, `hue()`, `saturation()`, `brightness()`, `alpha()` — para variar tonos de comida.
- `text()`, `textSize()`, `textAlign()`, `textWidth()` — toda la UI de overlay.
- `PGraphics` / `createGraphics()` — usado para: buffer de cámara (`camBuffer`), caché de fondo escalado (`bgCoverCache`), y renderizado auxiliar de rotación de imágenes.

### 2.3 Imagen / píxeles
- `PImage`, `loadImage()`, `createImage(w,h,ARGB)`.
- `loadPixels()` / `.pixels[]` / `updatePixels()` — manipulación directa de píxeles ARGB (usado intensivamente en segmentación de blobs y en construir el "recorte" del pez).
- `.get()` — snapshot de un `PGraphics`/`PImage`.

### 2.4 Input
- `keyPressed()`, `key`, `keyCode`, `CODED`, flechas (`LEFT/RIGHT/UP/DOWN`), `ENTER`/`RETURN`.
- Sin uso de mouse en absoluto (toda la interacción es teclado + hardware serial).

### 2.5 Video / cámara
- `Capture` (`processing.video`): `Capture.list()`, constructor, `.start()`, `.stop()`, `.available()`, `.read()`, `.width/.height`.

### 2.6 Audio
- `SoundFile` (`processing.sound`): constructor `(this, archivo)`, `.play()`, `.stop()`.
- Dos sonidos simultáneos por captura: uno "universal" (`sound1`, siempre `splash.wav`) + uno por especie (`sound2`).

### 2.7 Serial / hardware
- `Serial` (`processing.serial`): constructor `(this, puerto, baud)`, `.clear()`, `.buffer(n)`, `.write()`, `.available()`, `.read()`.
- `serialEvent(Serial s)` — callback de Processing que se dispara cuando llegan bytes (patrón que hay que reemplazar por polling o hilo en C++).

### 2.8 JSON / archivos
- `loadJSONObject()`, `saveJSONObject()`, `JSONObject`, `JSONArray` — usado para `app_config.json` (solo lectura) y `roi.json` (lectura + escritura).
- `sketchPath()` — resuelve rutas relativas a la carpeta del sketch.

### 2.9 Utilidades matemáticas (uso extensivo, todo el código las usa)
`PVector`, `sin/cos/atan2/sqrt/degrees/radians`, `lerp()`, `map()`, `constrain()`, `random()`, `round/floor/ceil/abs/max/min`, `millis()`, `println()`, `nf()`.

---

## 3. Assets

| Tipo | Archivos | Notas |
|---|---|---|
| **Fondos** (imágenes) | `arrecife photo.png` (2048×1168), `arrecife.png` (1344×768), `mar.png` (1536×1024), `rio.png` (1024×1024) | Configurables en `app_config.json → fondo_files`. Se escalan "cover" al tamaño del canvas y se cachean. |
| **Sonidos** | `splash.wav` (82 KB), `yahoo.wav` (198 KB), `hai-hai.mp3` (25 KB), `caballito.mp3` (26 KB), `shark.mp3` (33 KB) | `splash.wav` es el sonido universal; el resto son "sonido 2" por especie, mapeados en `app_config.json → species_profiles`. |
| **Config runtime** | `app_config.json` | Puerto/baud Arduino, índice de cámara default, tamaño de LEDs, altura de spawn del pez, delay post-captura, colores de comida, fondos, perfiles de especie (fiducial→sonidos→comida). |
| **Config de calibración** | `roi.json` | Se escribe/lee en vivo desde la app: posición de esquina del marcador, extents del ROI, umbral de blanco, cantidad de LEDs de matriz. |
| **No usados por el sketch principal** (assets de otro flujo, para colorear/imprimir) | `Caballitos para colorear.svg`, `Caguamas para colorear.pdf/svg`, `Mantarrayas para colorear.svg`, `Nemos para colorear.svg`, `Peces para colorear.svg`, `submarino para colorear.svg`, `Tiburones para colorear.pdf/svg`, `Tortugas para colorear.svg` | Plantillas imprimibles para que los niños dibujen — no se cargan en tiempo de ejecución. |
| Sin fuentes tipográficas cargadas | — | Todo el texto usa la fuente por defecto de Processing. |

---

## 4. Resolución y tamaños clave

| Parámetro | Valor | Constante |
|---|---|---|
| Canvas (ventana) | 1280×720 | `Config.CANVAS_W/H` |
| Buffer de cámara | 640×480 | `Config.CAM_BUFFER_W/H` (independiente de la resolución nativa de la webcam; todo frame se reescala a esto) |
| Previews de UI | 240×180 | `Config.PREVIEW_W/H` |
| Altura de spawn del pez | 380 px (config actual) | `app_config.json → fish_spawn_height`, rango 40–900 |
| Ancho del pez | derivado de la altura × aspect 640/480 | `Config.BASE_ASPECT` |
| Grid de spawn | 5×5 celdas | `Config.GRID_COLS/ROWS` |
| ROI actual guardada | extentX 452, extentY 228, whiteThr 129, matrixLedCount 13 | `roi.json` (valores de la última calibración) |
| Cuerpo del pez | cadena de 16 nodos (`FishBody.numNodes`) | — |

---

## 5. Dónde se concentra el cómputo por frame

Ordenado de mayor a menor impacto esperado:

1. **Detección de fiduciales (BoofCV) en vivo durante calibración de ROI.**
   En `Arrecife.pde`, dentro de `draw()`, cuando `uiMode == UI_ROI` se llama
   `fidu.detect(camBuffer.get())` **en cada frame** mientras esa pantalla está
   abierta. Es la única detección de visión por computadora que corre de forma
   continua (60 veces por segundo) en vez de una sola vez al capturar. Es la
   operación más pesada del sketch, aunque acotada a cuando el usuario está
   calibrando.

2. **Búsqueda de comida por pez, cada frame — sin estructura espacial.**
   `FishClassicBehavior.seekClosestFood()` recorre **todos** los `foodPellets`
   por cada pez, cada frame (`O(peces × comida)`). Con el límite de 150 pellets
   por especie × 4 especies (hasta 600 pellets) y un número de peces que puede
   crecer sin tope automático (solo se borran con las teclas `C`/`U`), este
   bucle es el que más escala mal. `tryEat()` repite un recorrido similar.

3. **Segmentación por blobs (flood fill) al capturar.**
   `BlobSegmenter.buildAlphaFromSnapshot()` procesa los 640×480 = 307,200
   píxeles del snapshot con un flood-fill BFS desde el borde del ROI. Es
   `O(ancho×alto)`, pero **solo ocurre una vez por captura** (tecla ESPACIO o
   botón de Arduino), no por frame — no es un cuello de botella sostenido.

4. **Animación y render del cuerpo de cada pez.**
   `FishBody.move()` recalcula la cadena de 16 nodos y `display()` dibuja un
   `QUAD_STRIP` texturizado, por cada pez, cada frame. Individualmente barato,
   pero sin límite máximo de peces esto crece linealmente sin freno.

5. **Copia del frame de cámara al buffer.**
   `updateCameraBuffer()` hace un `image()` de la cámara al `PGraphics` cada
   vez que hay un frame nuevo disponible — operación GPU, barata.

6. **Caché de fondo.**
   `AssetsManager` ya cachea el fondo escalado (`bgCoverCache`) y solo lo
   reconstruye si cambia el fondo o el tamaño del canvas — bien resuelto, no es
   un problema.

**Conclusión de rendimiento:** el sketch está razonablemente escrito (usa
caché de fondo, aloca buffers de segmentación una sola vez y los reutiliza),
pero **no tiene límite máximo de peces vivos** ni **estructura espacial para
buscar comida cercana** — en una sesión larga con muchas capturas, el costo
por frame crece linealmente con peces × comida. En C++ nativo esto va a ser
imperceptible incluso sin optimizar, pero es bueno saberlo si algún día se
agregan muchas más especies o un límite de tiempo de exhibición largo.

---

## 6. Piezas sin equivalente directo en C++/openFrameworks

| Pieza Processing | Problema | Ruta de migración |
|---|---|---|
| **BoofCV Square Binary fiducial detector** | Es Java puro, no existe binding a C++. | Reemplazar por **ArUco de OpenCV** (`cv::aruco`), como ya lo anticipa `arrecife_cpp/PORTING_PLAN.md`. Implica generar/reimprimir marcadores nuevos compatibles con ArUco (los de BoofCV no son compatibles bit a bit con ArUco). |
| **`serialEvent()` (callback automático de Processing)** | Patrón específico del runtime de Processing. | En oF se hace *polling* del puerto serial dentro de `update()` con `ofSerial`, revisando bytes disponibles cada frame — mecánicamente simple, ya contemplado en `HardwareController.h`. |
| **`processing.sound.SoundFile`** | API de alto nivel de Processing. | `ofSoundPlayer` en oF (usa FMOD en la build de Windows — ya se compiló como parte de la librería, se vio `ofFmodSoundPlayer.cpp` en el build de prueba). Casi 1:1: `play()`/`stop()` existen igual. |
| **`processing.video.Capture`** | API de alto nivel de Processing (GStreamer por debajo). | `ofVideoGrabber` en oF (DirectShow/Media Foundation en Windows) — mismo concepto: listar cámaras, iniciar, leer frame a frame. |
