# Especificación funcional — "Arrecife"

> Qué hace la aplicación, sin hablar de cómo está programada. Es la referencia
> para verificar, durante la migración, que el port en C++ se comporta igual
> que el original.

---

## 1. Qué es la instalación

Una instalación interactiva tipo "acuario aumentado" pensada para un evento con
niños. Cada niño colorea un dibujo impreso de un animal marino (los archivos
"para colorear" que están en el repo: pez, tortuga, tiburón, mantarraya, etc.).
El dibujo coloreado se coloca físicamente bajo una cámara, dentro de un área
delimitada (ROI) que además tiene pegado un **marcador fiducial** (una
pegatina cuadrada de 2×2 cm con un patrón binario, tipo código QR simplificado).
Al presionar un botón físico (o la barra espaciadora en modo desarrollo), la
app:

1. Fotografía el dibujo.
2. Lee el marcador fiducial para saber **qué especie de animal es** y **en qué
   orientación (rotación de 90° en 90°) quedó colocado el dibujo**.
3. Recorta el dibujo del fondo de papel blanco (segmentación por color/blob).
4. Convierte el recorte en un "pez" animado que nada por la pantalla.
5. Reproduce dos sonidos: uno de "splash" universal y uno específico de la
   especie detectada.

El resultado en pantalla es un acuario grande (proyectado o en TV) donde se
acumulan todos los animales que los niños han "capturado", nadando y
comiendo comida virtual que se puede soltar con botones físicos o teclas.

---

## 2. Ciclo de interacción principal (camino feliz)

```
Niño colorea dibujo
        │
Coloca dibujo bajo cámara, dentro del ROI, con el marcador fiducial visible
        │
Presiona botón de captura (Arduino) o SPACE
        │
App congela el frame de cámara (snapshot)
        │
Espera "espera_post_ms" (≈1.4s por defecto) ── mientras tanto, Arduino
        │                                        reproduce una animación de
        │                                        luces tipo "cometa" en la
        │                                        tira LED, dando feedback
        │                                        físico de que se procesó
        ▼
Detecta el marcador fiducial en el snapshot
        │
        ├─ Fiducial válido y registrado → aplica el perfil de esa especie
        │   (selecciona sus 2 sonidos, guarda el ángulo de rotación)
        │
        └─ Fiducial no encontrado / no registrado → NO se genera pez
            (excepto si está activo el "modo test", tecla T, que fuerza
             el escaneo aunque no haya marcador — solo para pruebas)
        │
Reproduce sonido 1 (splash) + sonido 2 (de la especie)
        │
Recorta el dibujo del fondo (todo lo "blanco" dentro del ROI se hace
transparente mediante flood-fill desde el borde; lo no-blanco queda opaco)
        │
Rota el recorte según el ángulo del marcador
        │
Crea un nuevo "pez" con esa imagen como piel, lo coloca en la celda de
la rejilla de spawn seleccionada (por defecto la central) y lo suelta al
acuario
```

Este flujo es **asíncrono y no bloqueante**: la app sigue dibujando y
animando todo lo demás mientras espera el `espera_post_ms` antes de procesar.
Solo puede haber **una captura en proceso a la vez** (una nueva petición de
captura mientras otra está pendiente se ignora).

---

## 3. Comportamiento de los animales ("peces")

- Cada pez tiene una **imagen recortada única** (la piel, viene del dibujo
  del niño) montada sobre un cuerpo animado de 16 segmentos que se curva como
  una cadena al nadar (efecto "serpenteante").
- **Sin comida cerca:** el pez deambula (*wander*) con movimiento suave y
  semi-aleatorio.
- **Con comida de su misma especie disponible:** el pez identifica el pellet
  de comida "mejor" (prioriza los que están abajo/cerca por encima de los
  lejanos) y nada hacia él acelerando ~1.8× su velocidad normal; frena
  suavemente si se acerca desde lejos, y si ya está muy cerca "engancha" su
  dirección directo hacia el pellet para no fallar el mordisco.
- **Comer:** cuando la "boca" del pez (un punto calculado sobre la imagen
  recortada, buscando el borde visible más a la izquierda del sprite) toca un
  pellet de su propia especie, el pellet desaparece.
- **Regla estricta de dieta:** cada pez SOLO come comida de su propia especie
  (`speciesId` del pez == `speciesId` del pellet). Nunca come comida ajena.
- **Velocidad de aleteo** (frecuencia de animación del cuerpo) sube y baja
  según qué tan rápido se está moviendo el pez en ese instante.
- **Bordes de pantalla:** los peces rebotan al llegar al borde (no lo cruzan).
- No hay un límite máximo configurado de peces simultáneos: se acumulan hasta
  que el usuario los borra manualmente.

---

## 4. Comida

- Se suelta en "lluvia" desde arriba de la pantalla, en una franja horizontal
  asociada a su especie/color (la pantalla se divide en tantas franjas como
  tipos de comida existan).
- Cada suelta genera un grupo de 25–40 pellets (cantidad aleatoria dentro de
  un rango).
- Forma aleatoria por pellet: círculo, pentágono, hexágono o heptágono.
- Color: el color base configurado para esa especie, con una variación
  aleatoria de tono/saturación/brillo para que no todos los pellets se vean
  idénticos.
- Caen con velocidad inversamente proporcional a su tamaño (pellets chicos
  caen más rápido) más un jitter lateral leve.
- Desaparecen si nadie se las come y salen por debajo de la pantalla.
- **Límite:** máximo 150 pellets simultáneos por especie — pasado ese límite,
  soltar más comida de esa especie no hace nada hasta que se coman algunos.

---

## 5. Estados / modos de la aplicación

La app tiene **un único modo de overlay de UI activo a la vez** (nunca dos al
mismo tiempo):

| Modo | Cómo se activa | Qué muestra / permite |
|---|---|---|
| **Ninguno** (normal) | estado por defecto | Solo el acuario, sin overlays. |
| **Ayuda** | tecla `H` | Lista de todos los atajos de teclado. |
| **Preview de cámara** | tecla `P` | Vista en vivo de la webcam; `F1`–`F9` cambian de cámara. |
| **Preview de fondo** | tecla `F` | Vista del fondo actual; `F1`–`F9` cambian de fondo. |
| **Rejilla de spawn** | tecla `G` | Cuadrícula 5×5 sobre el acuario; flechas mueven el cursor, `ENTER` fija en qué celda aparecerá el próximo pez capturado. |
| **Calibración de ROI** | tecla `O` | Vista en vivo de cámara + contorno del ROI + controles de threshold/LEDs (ver sección 6). Es el único modo con detección de fiducial corriendo en cada frame, para dar feedback visual en vivo. |

Además, hay **estados temporales que no son de UI**, controlados por
temporizadores internos (no bloquean el resto del programa):

- **Captura pendiente de procesar** (`ejecutarPost`): entre que se presiona
  captura y se cumple el `espera_post_ms`.
- **Resincronización de Arduino tras arranque**: al conectar el puerto serial,
  muchos Arduino se reinician solos y pierden la primera configuración
  enviada; la app reenvía automáticamente esa configuración 2.2 segundos
  después de abrir el puerto, por si acaso.
- **Modo test** (tecla `T`, toggle): fuerza que toda captura genere un pez
  aunque no se detecte ningún marcador fiducial válido — pensado para probar
  el flujo sin tener que imprimir/pegar marcadores.

---

## 6. Calibración de ROI (ajuste técnico, no para el usuario final)

Pantalla de configuración pensada para quien instala/ajusta el sistema
físicamente, no para los niños:

- `,` / `.` — baja/sube el umbral de "blanco" usado para recortar el dibujo
  del fondo de papel.
- `J` / `K` — baja/sube cuántos LEDs de la matriz 8×8 quedan encendidos fijos
  (luz de iluminación constante sobre el dibujo, no la animación).
- Flechas — cambian el tamaño (extents) del área ROI.
- `1`–`4` — indican en qué esquina del marcador fiducial está anclado el ROI
  (top-left/top-right/bottom-right/bottom-left), para que el recorte se
  oriente bien sin importar cómo esté pegado el marcador.
- `S` — guarda la calibración actual en `roi.json`.
- `L` — recarga la calibración guardada.
- `O` — sale de este modo.

Mientras este modo está activo, si hay un marcador fiducial visible, el ROI
se reposiciona/rota automáticamente en vivo siguiendo el marcador (además de
los ajustes manuales).

---

## 7. Selección manual de especie

Las teclas `1`–`9` cambian la "especie activa" manualmente (sin pasar por
detección de fiducial) — útil para pruebas o para forzar una especie
específica. Esto solo cambia qué sonidos se usarán y qué perfil está
"seleccionado"; no dispara una captura ni genera un pez por sí solo.

---

## 8. Entradas de hardware físico (Arduino)

La instalación tiene botones arcade físicos, además del teclado:

| Botón físico | Envía a la app | Efecto |
|---|---|---|
| Botón de captura | carácter `S` | Dispara el mismo flujo de captura que `SPACE`. Arduino además dispara su propia animación de luces en la tira, independientemente de la app. |
| Botón "Z" | carácter `z` | Suelta comida de la especie 1. |
| Botón "X" | carácter `x` | Suelta comida de la especie 2. |
| Botón "V" | carácter `v` | Suelta comida de la especie 3. |

(El firmware actual de Arduino solo tiene 3 botones de comida cableados,
aunque la app está preparada para hasta 5 —`Config.FOOD_KEYS = z,x,v,b,n`—
por si se agregan más botones físicos a futuro.)

La app, a su vez, le manda configuración al Arduino al arrancar (y de nuevo
tras el reinicio del puerto): cuántos LEDs tiene la tira, qué tan rápido viaja
la animación, y cuántos LEDs de la matriz deben quedar encendidos fijos.

Si el Arduino no está conectado o el puerto falla, **la app sigue funcionando
igual mediante teclado**, solo sin control físico.

---

## 9. Requisitos duros para arrancar

- **Debe existir al menos una webcam** — si no, la app termina (`exit()`).
- **Debe poder cargar el primer fondo configurado** — si no, la app termina.
- El Arduino es **opcional**: si falla la conexión serial, la app avisa por
  consola y continúa sin hardware físico.

---

## 10. Persistencia entre sesiones

- `app_config.json`: se lee una sola vez al arrancar. Define: puerto/baudrate
  de Arduino, índice de cámara por defecto, tamaño de spawn del pez, delay
  post-captura, colores de comida por especie, lista de fondos, y el mapeo
  especie↔fiducial↔sonidos↔comida. **No se reescribe nunca desde la app.**
- `roi.json`: se lee al arrancar y se puede **sobrescribir en caliente** desde
  la pantalla de calibración de ROI (tecla `S`). Guarda: esquina de anclaje
  del marcador, extents del ROI, umbral de blanco, y LEDs fijos de la matriz.

No hay ningún otro tipo de guardado — los peces y la comida en pantalla
**no persisten** entre ejecuciones del programa; cada arranque empieza con el
acuario vacío.
