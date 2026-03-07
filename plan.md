# Plan de implementación: comportamiento único por especie

## Objetivo
Diseñar una arquitectura donde cada especie tenga:
1. Comportamiento propio (movimiento + decisiones).
2. Sonido propio como parte del perfil de especie.
3. Código aislado en **archivos separados por especie** para facilitar mantenimiento y expansión (pez, pulpo, tortuga, calamar, camarón, tiburón, etc.).
4. Escalar a múltiples ecosistemas (marino, granja, tundra, sabana, dinosaurios, etc.) sin reescribir el motor base.

---

## Principios de diseño
- **Separación de responsabilidades**:
  - `AnimalAgent` (estado físico y ciclo de vida común).
  - `SpeciesBehavior` (decisiones + steering + alimentación por especie).
  - `SpeciesAudio` (carga/uso de sonidos por especie).
- **Escalabilidad**: agregar nueva especie sin tocar el loop principal.
- **Compatibilidad incremental**: mantener el comportamiento actual como especie base (`FishClassic`) durante la migración.

---

## Estructura de archivos propuesta

### Núcleo común
- `AnimalAgent.pde`
  - Reemplaza/absorbe lo común de `FishAgent` (posición, velocidad, aceleración, límites, update/render base).
  - Mantiene campos compartidos y utilidades de steering.

- `SpeciesBehavior.pde`
  - Contrato/base para comportamiento por especie.
  - Métodos esperados:
    - `updateIntent(agent, world)`
    - `applyMovement(agent, world)`
    - `selectFood(agent, foods)`
    - `tryEat(agent, foods)`

- `SpeciesAudio.pde`
  - Modelo para sonido único por especie aplicado únicamente en la aparición (spawn).
  - API mínima para reproducir el sonido de spawn sin mezclar lógica en el agente.

- `SpeciesRegistry.pde`
  - Registro central de especies disponibles.
  - Mapea `speciesId -> {behavior, audio, metadatos}`.

### Un archivo por especie
- `species/FishClassicSpecies.pde`
- `species/TurtleSpecies.pde`
- `species/OctopusSpecies.pde`
- `species/SquidSpecies.pde`
- `species/ShrimpSpecies.pde`
- `species/SharkSpecies.pde`

Cada archivo define únicamente la lógica propia de esa especie y sus parámetros.

**Regla clave de aislamiento:** cada especie debe compilar y ejecutarse sin depender de código conductual o de animación de otra especie (sin heredar comportamiento entre especies hermanas, sin “ifs por tipo” en el loop principal).

> Nota: si Processing complica subcarpetas en tu setup, usar prefijo en raíz:
> - `Species_FishClassic.pde`, `Species_Turtle.pde`, etc.

---

## Modelo de especie (datos)
Cada especie debe definir una estructura con:
- `id`, `name`
- **Comportamiento**:
  - `baseMaxSpeed`, `baseMaxForce`
  - parámetros de wander/seek
  - reglas de prioridad de comida
  - restricción alimentaria estricta: sólo consumir pellets con `speciesId` igual al número de especie del animal
  - `locomotionType` (nado, cuadrúpedo, bípedo, salto, reptación, planeo, etc.)
  - estilo locomotor (suave, ráfagas, pausas, etc.)
- **Hábitat/Bioma**:
  - `biomeType` (marino, granja, tundra, sabana, jurásico, etc.)
  - parámetros de entorno que afectan el movimiento (`drag`, fricción/suelo, zonas navegables, obstáculos)
- **Audio**:
  - un único sonido de spawn por especie
  - volumen base de reproducción para el spawn
- **Visual/opcional**:
  - tamaño sugerido, frecuencia muscular base, tintes o presets.

Esto permite que el sonido quede formalmente dentro del perfil de especie y no como elemento independiente.

---


## Matriz concreta de perfiles iniciales (primera iteración)

Escala sugerida:
- Velocidad/Fuerza: relativa al rango actual de `FishAgent` (velocidad ~0.8–1.9, fuerza ~0.2).
- 0.0 = bajo, 1.0 = alto para rasgos conductuales.

| Especie | Rol conductual | baseMaxSpeed | baseMaxForce | foodSpeedMult | Reactividad a comida | Erraticidad | Pausas | Preferencia vertical | Radio de mordida relativo | Sonido de spawn |
|---|---|---:|---:|---:|---:|---:|---:|---|---:|---|
| Pez (`FishClassicSpecies`) | Balanceado, fluido | 1.35 | 0.20 | 1.80 | 0.75 | 0.35 | 0.10 | Media/columna completa | 1.00x | Spawn suave (único sonido de especie) |
| Tortuga (`TurtleSpecies`) | Lenta, estable, giros amplios | 0.70 | 0.10 | 1.15 | 0.45 | 0.10 | 0.45 | Baja-media (evitar superficie) | 1.25x | Spawn grave/corto (único sonido de especie) |
| Pulpo (`OctopusSpecies`) | Inteligente, impulsos + reposo | 1.05 | 0.30 | 1.35 | 0.65 | 0.75 | 0.55 | Media-baja con cambios bruscos | 1.15x | Spawn orgánico (único sonido de especie) |
| Calamar (`SquidSpecies`) | Sprint en ráfagas y drift | 1.75 | 0.26 | 2.05 | 0.85 | 0.65 | 0.25 | Media-alta (sube y baja rápido) | 0.90x | Spawn rápido (único sonido de especie) |
| Tiburón (`SharkSpecies`) | Cazador dominante, crucero + aceleraciones | 1.95 | 0.24 | 2.20 | 0.90 | 0.20 | 0.05 | Media-alta, patrullaje amplio | 1.35x | Spawn contundente (único sonido de especie) |
| Camarón (`ShrimpSpecies`) | Micro-movimientos, tímido, fondo | 0.95 | 0.22 | 1.30 | 0.55 | 0.80 | 0.35 | Baja (sesgo al fondo) | 0.75x | Spawn corto (único sonido de especie) |

### Reglas conductuales mínimas por especie
- **Regla global de alimentación**: cada especie debe comer únicamente el alimento correspondiente a su número de especie (`animal.speciesId == pellet.speciesId`).
- **Pez**: mantener lógica actual (baseline), con wander continuo y persecución moderada.
- **Tortuga**: introducir temporizador de pausa (ej. 0.8–1.6 s) y reducir cambio angular por frame; priorizar pellets cercanos sobre lejanos.
- **Pulpo**: alternar estado `burst` (0.2–0.4 s) y `glide/rest` (0.4–1.0 s), con cambios de rumbo más frecuentes cuando no hay comida.
- **Calamar**: ráfagas más largas en persecución y desaceleración tipo drift; penalizar giros cerrados para sentir inercia.
- **Tiburón**: patrón de patrullaje largo con giros amplios; cuando detecta comida, entra en aceleración sostenida y reduce erraticidad.
- **Camarón**: desplazamientos cortos en zig-zag, con saltos de dirección aleatorios y fuerte afinidad por zona baja del acuario.

### Casos de movimiento/animación particulares (definidos por especie)
- **Tortuga (`TurtleSpecies`)**: incluir ciclo de propulsión por aletas con fase de **retroceso corto** (carga) y fase de **avance con impulso**. Este patrón debe vivir en su archivo de especie, sin lógica compartida obligatoria con pez, pulpo o calamar.
- **Pulpo (`OctopusSpecies`)**: la animación debe concentrarse en la **zona inferior del cuerpo (tentáculos)**; el cuerpo superior puede mantener desplazamiento más estable.
- **Calamar (`SquidSpecies`)**: priorizar animación de la **parte baja/tentacular** y propulsión en ráfagas, sin acoplar su sistema de animación al de pulpo (cada uno en su archivo propio).
- **Regla transversal**: si una especie requiere pipeline visual/físico especial (deformación, rigs, offsets), se implementa dentro de su archivo de especie y se expone sólo mediante la interfaz común (`SpeciesBehavior`/`SpeciesAudio`).

### Parámetros de audio iniciales por especie (recomendación)
- Campos base en `SpeciesAudio`:
  - `spawnClip`
  - `spawnVolume`

- Valores de arranque sugeridos (`spawnVolume`):
  - **Pez**: 0.45–0.60
  - **Tortuga**: 0.35–0.50
  - **Pulpo**: 0.45–0.60
  - **Calamar**: 0.40–0.55
  - **Tiburón**: 0.60–0.80
  - **Camarón**: 0.30–0.45

### Criterio de “se sienten distintos” (aceptación primera iteración)
Se considera aceptable si, en 60–90 segundos de observación mixta:
1. Se distinguen visualmente por ritmo de locomoción sin mirar HUD.
2. Presentan distinta latencia para ir a comida.
3. Ocupan zonas verticales diferentes del acuario.
4. Cada especie reproduce únicamente su sonido de spawn, sin sonidos adicionales de movimiento o alimentación.

---

## Extensión para múltiples ecosistemas
Para soportar animales no marinos sin deuda técnica, se añaden tres ejes de generalización:
1. **`BiomeProfile`**: define reglas de entorno por ecosistema (drag, fricción, zonas agua/tierra, obstáculos, límites especiales).
2. **`LocomotionType`**: clasifica locomoción base (nado, bípedo, cuadrúpedo, salto, reptación, planeo) para reutilizar patrones entre especies.
3. **`FoodTaxonomy` (evolutiva)**:
   - Fase inicial: se mantiene regla estricta por `speciesId`.
   - Fase avanzada: habilitar categorías de dieta (herbívoro/carnívoro/omnívoro) sin romper compatibilidad.

---

## Cambios por etapas

### Etapa 1 — Preparación (sin romper funcionalidad)
1. Introducir contrato `SpeciesBehavior`.
2. Introducir contratos base `BiomeProfile` y `LocomotionType` (aunque inicialmente sólo se use perfil marino).
3. Crear especie `FishClassic` que replique el comportamiento actual.
4. Mantener `speciesId` actual para compatibilidad con pellets.

### Etapa 2 — Sonido dentro de especie
1. Extender perfil de especie para incluir audio (no sólo assets globales).
2. Mover selección/activación de sonidos desde `AssetsManager` a `SpeciesRegistry` + `SpeciesAudio`.
3. Limitar audio por especie a un único evento: `spawn`.

### Etapa 3 — Archivo por especie
1. Crear archivo dedicado para cada especie.
2. Migrar parámetros hardcoded a su archivo de especie.
3. Registrar todas las especies en `SpeciesRegistry`.
4. Asignar `biomeType` y `locomotionType` por especie para evitar lógica acoplada al ecosistema marino.
5. Verificar aislamiento: cada especie no debe depender del comportamiento/animación de otras especies.

### Etapa 4 — Integración del loop principal
1. En `draw()`, reemplazar llamadas directas (`seekClosestFood`, `wander`, `tryEatFoods`) por delegación al behavior activo de cada agente.
2. Mantener física/render común en `AnimalAgent`.

### Etapa 5 — Especies nuevas reales
Implementar al menos 2 especies no pez para validar arquitectura:
- `TurtleSpecies`: lenta, giros amplios, pausas.
- `OctopusSpecies` o `SquidSpecies`: movimiento en ráfagas.

Además, validar al menos 1 especie **no marina** (ej. sabana/granja/tundra) para probar `BiomeProfile` + `LocomotionType` fuera del agua.

### Etapa 6 — Afinación y limpieza
1. Eliminar duplicaciones antiguas en `FishAgent`.
2. Ajustar balance de parámetros por especie.
3. Documentar guía: “Cómo agregar una nueva especie en 1 archivo + registro”.
4. Preparar evolución de `FoodTaxonomy` (categorías de dieta) manteniendo compatibilidad con regla estricta por `speciesId`.

---

## Flujo operativo al crear una nueva especie
1. Crear archivo nuevo `Species_<Nombre>.pde`.
2. Implementar comportamiento y audio de la especie.
3. Registrar en `SpeciesRegistry` con `speciesId`.
4. Configurar `biomeType` y `locomotionType` de la especie.
5. Configurar assets/sonidos asociados.
6. Configurar y validar mapeo de alimento por número de especie (`speciesId` del animal contra `speciesId` del pellet).
7. Probar spawn, alimentación y reproducción exclusiva del sonido de spawn.
8. Confirmar que la especie funciona desactivando temporalmente otras especies (prueba de independencia).

Sin tocar el loop principal ni otras especies.

---

## Reglas de convivencia entre especies
- Cada especie decide:
  - cómo busca comida,
  - cómo se mueve,
  - qué sonido de spawn emite.
- El motor común sólo garantiza:
  - ciclo por frame,
  - límites del mundo,
  - integración física base,
  - render y colisiones básicas.

---

## Plan de validación

### Pruebas funcionales
- Spawn correcto por `speciesId`.
- Cada especie presenta patrón de movimiento distinto observable.
- Consumo de comida respeta reglas por especie y mapeo estricto por número de especie (`speciesId`).
- Sonido de spawn correcto por especie y ausencia de otros sonidos.
- Independencia por especie: al deshabilitar una especie, las demás no rompen su comportamiento ni animación.

### Pruebas técnicas
- Sin caída de FPS con múltiples especies activas.
- Sin errores al alternar especies con fiduciales.
- Sin regresión del comportamiento pez actual (`FishClassic`).
- Validación cruzada de ecosistemas: al activar una especie no marina, no se rompe el pipeline de especies marinas (y viceversa).

### Métricas sugeridas
- pellets consumidos por especie/minuto,
- velocidad media por especie,
- tiempo medio para adquirir target,
- conteo de spawns con audio reproducido correctamente por especie.
- tasa de rechazo de pellets incorrectos por especie (debe ser 100% rechazo cuando `pellet.speciesId != animal.speciesId`).

---

## Riesgos y mitigaciones
- **Riesgo**: exceso de complejidad inicial.
  - **Mitigación**: empezar con 1 especie legacy + 1 nueva distinta.
- **Riesgo**: acoplar audio a lógica de render.
  - **Mitigación**: usar `SpeciesAudio` con eventos desacoplados.
- **Riesgo**: fragmentación por muchos archivos.
  - **Mitigación**: contrato estricto + `SpeciesRegistry` central.

---

## Entregables
1. `plan.md` (este documento).
2. Estructura base `AnimalAgent + SpeciesBehavior + SpeciesAudio + SpeciesRegistry`.
3. Migración inicial de `FishClassic`.
4. Dos especies adicionales con comportamiento/sonido diferenciados.
5. Documentación breve para alta de nuevas especies.
