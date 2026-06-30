import processing.video.*;
import java.util.ArrayList;
import processing.sound.*;
import processing.serial.*;

int lastAnimalsPrinted = -1;
int[] lastFoodPrinted = null;

boolean arduinoBootSyncPending = false;
int arduinoBootSyncAtMs = 0;
final int ARDUINO_BOOT_SYNC_DELAY_MS = 2200;

void initStatsIfNeeded() {
  int foodTypeCount = max(1, cfgSpeciesFoodColors.length);
  if (lastFoodPrinted == null || lastFoodPrinted.length != foodTypeCount) {
    lastFoodPrinted = new int[foodTypeCount];
    for (int i = 0; i < lastFoodPrinted.length; i++) lastFoodPrinted[i] = -1;
  }
}

int[] countFoodBySpecies() {
  int[] counts = new int[max(1, cfgSpeciesFoodColors.length)];

  if (foodPellets != null) {
    for (int i = 0; i < foodPellets.size(); i++) {
      FoodPellet p = foodPellets.get(i);
      if (p == null) continue;
      int s = p.speciesId;
      if (s >= 0 && s < counts.length) counts[s]++;
    }
  }

  return counts;
}

void maybePrintStatsOnChange() {
  initStatsIfNeeded();

  int animals = (tlwanderers == null) ? 0 : tlwanderers.size();
  int[] food = countFoodBySpecies();

  boolean changed = false;

  if (animals != lastAnimalsPrinted) changed = true;

  if (!changed) {
    for (int i = 0; i < food.length; i++) {
      if (food[i] != lastFoodPrinted[i]) {
        changed = true;
        break;
      }
    }
  }

  if (!changed) return;

  String msg = "Animales: " + animals;

  int n = food.length;

  for (int s = 0; s < n; s++) {
    msg += ", Comida " + (s + 1) + ": " + food[s];
  }

  println(msg);
  lastAnimalsPrinted = animals;
  for (int i = 0; i < lastFoodPrinted.length; i++) lastFoodPrinted[i] = food[i];
}


// =========================
// Config global por instancia
// =========================
final Config CFG = new Config();

// =========================
// Assets centralizados
// =========================
AssetsManager assets;

BoofSquareBinaryManager fidu = null;


// =========================
// Segmentador por ROI + blobs
// =========================
BlobSegmenter blobber;

// =========================
// IO
// =========================
Serial arduino;
Capture cam;

// =========================
// Cámara buffer
// =========================
PGraphics camBuffer;
boolean camHasFrame = false;
String[] cams;
int selectedCam = 0;
UIOverlay uiOverlay;

// =========================
// UI, un solo modo activo
// =========================
static final int UI_NONE  = 0;
static final int UI_HELP  = 1;
static final int UI_CAM   = 2;
static final int UI_FONDO = 3;
static final int UI_GRID  = 4;
static final int UI_ROI   = 5;

int uiMode = UI_NONE;


void uiSet(int mode) {
  uiMode = mode;
}

void uiToggle(int mode) {
  uiMode = (uiMode == mode) ? UI_NONE : mode;
}


// =========================
// Spawn grid
// =========================
int activeCell = 12;
int selectedCell = 12;

// =========================
// Post captura
// =========================
boolean arduinoDisponible = false;
boolean ejecutarPost = false;
int tiempoDisparoPost = 0;

// Captura congelada
PImage frozenSnap = null;

boolean hwCaptureRequested = false;
boolean forceScanTestMode = false;

// =========================
// Render size pez
// =========================
int fishH = 280;
int fishW = 440;

// =========================
// Boids
// =========================
ArrayList<AnimalAgent> tlwanderers = new ArrayList<AnimalAgent>();

// =========================
// Comida
// =========================
ArrayList<FoodPellet> foodPellets = new ArrayList<FoodPellet>();

// =========================
// ROI calib UI
// =========================
int roiStep = 4; // paso de movimiento o tamaño en pixeles del buffer 640x480
FiducialHit lastFiducialHit = null;

void settings() {
  size(CFG.CANVAS_W, CFG.CANVAS_H, P2D);
}

void setup() {
  textureMode(IMAGE);
  imageMode(CENTER);

  loadRuntimeConfig();

  // 1) AssetsManager
  assets = new AssetsManager(this);
  assets.setFondoFiles(cfgFondoFiles);
  assets.setSpeciesProfiles(cfgSpeciesProfiles);
  uiOverlay = new UIOverlay(this);

  // 2) Fondo inicial
  assets.applyFondo(0);
  if (assets.getBgFondo() == null) {
    println("No se pudo cargar el fondo inicial");
    exit();
  }

  // 3) Lista webcams
  cams = Capture.list();
  if (cams == null || cams.length == 0) {
    println("No se encontraron webcams");
    exit();
  }

  selectedCam = constrain(cfgDefaultCamIndex, 0, cams.length - 1);

  println("Cámaras disponibles:");
  for (int i = 0; i < cams.length; i++) println((i + 1) + " -> " + cams[i]);
  println("Cámara activa: #" + selectedCam);

  // 4) Arduino
  try {
    arduino = new Serial(this, cfgArduinoCom, cfgArduinoBaud);
    arduinoDisponible = true;
    println("Arduino conectado en " + cfgArduinoCom);

    arduino.clear();
    arduino.buffer(1);
    syncLedConfigToArduino();
    // Al abrir el puerto serial, muchos Arduino se reinician y pueden perder
    // esta primera configuración. Se programa un reenvío tras el bootloader.
    arduinoBootSyncPending = true;
    arduinoBootSyncAtMs = millis() + ARDUINO_BOOT_SYNC_DELAY_MS;
  }
  catch (Exception e) {
    arduino = null;
    arduinoDisponible = false;
    println("Arduino NO detectado en " + cfgArduinoCom + ", el sketch continuará sin Arduino");
  }

  // 5) Cámara buffer
  camBuffer = createGraphics(CFG.CAM_BUFFER_W, CFG.CAM_BUFFER_H, P2D);
  camBuffer.beginDraw();
  camBuffer.background(0);
  camBuffer.endDraw();
  camHasFrame = false;

  switchCameraByIndex(selectedCam);

  // 6) Render size proporcional
  fishH = cfgFishSpawnHeight;
  normalizeFishSizeFromH();

  // 7) Blobber, cargar ROI desde roi.json si existe
  blobber = new BlobSegmenter(this, CFG.CAM_BUFFER_W, CFG.CAM_BUFFER_H);
  blobber.roiExtentX = CFG.ROI_W_DEFAULT;
  blobber.roiExtentY = CFG.ROI_H_DEFAULT;
  blobber.whiteThr = CFG.BLOB_WHITE_THR_DEFAULT;
  blobber.loadROI();
  syncLedConfigToArduino();
  
  // 9) Fiduciales BoofCV
  if (CFG.FIDUCIAL_ENABLED) {
    fidu = new BoofSquareBinaryManager(
      (double)CFG.FIDUCIAL_MARKER_SIZE_CM,
      CFG.FIDUCIAL_ID_MIN,
      CFG.FIDUCIAL_ID_MAX,
      CFG.FIDUCIAL_ROT_STEP_DEG,
      CFG.FIDUCIAL_DEBUG_PRINT
    );
  } else {
    fidu = null;
  }

}

void syncLedConfigToArduino() {
  syncStripLedCountToArduino();
  syncStripTravelStepMsToArduino();
  syncMatrixLedCountToArduino();
}

void syncStripLedCountToArduino() {
  if (!arduinoDisponible || arduino == null) return;
  arduino.write("L:" + cfgStripLedCount + "\n");
}

void syncStripTravelStepMsToArduino() {
  if (!arduinoDisponible || arduino == null) return;
  arduino.write("T:" + cfgStripTravelStepMs + "\n");
}

void syncMatrixLedCountToArduino() {
  if (!arduinoDisponible || arduino == null) return;
  if (blobber != null) {
    arduino.write("I:" + blobber.getMatrixLedCount() + "\n");
  } else {
    arduino.write("I:" + BlobSegmenter.MATRIX_LED_COUNT_DEFAULT + "\n");
  }
}

void draw() {
  if (arduinoBootSyncPending && millis() >= arduinoBootSyncAtMs) {
    syncLedConfigToArduino();
    arduinoBootSyncPending = false;
    println("Reenvío de config LED al Arduino tras reinicio de puerto serial");
  }

  // Fondo
  assets.drawBackgroundCover(width, height);

  // Cámara buffer
  updateCameraBuffer();

  // Si Arduino pidió captura, hazla aquí, después de actualizar camBuffer
  if (hwCaptureRequested) {
    hwCaptureRequested = false;

    if (camBuffer != null) frozenSnap = camBuffer.get();
    else frozenSnap = null;

    tiempoDisparoPost = millis() + cfgEsperaPostMs;
    ejecutarPost = true;
  }

  // Comida
  for (int i = foodPellets.size() - 1; i >= 0; i--) {
    FoodPellet p = foodPellets.get(i);
    p.update();
    p.display();
    if (p.isOffscreen()) foodPellets.remove(i);
  }

  // Boids
  for (int i = 0; i < tlwanderers.size(); i++) {
    AnimalAgent b = tlwanderers.get(i);
    b.updateBehavior(foodPellets);
    b.run();
    b.tryEat(foodPellets);
  }

  // =========================
  // UI, un solo modo activo
  // =========================
  if (uiMode == UI_CAM) {
    uiOverlay.drawWebcamPreview(10, 40, CFG.PREVIEW_W, CFG.PREVIEW_H, camBuffer, camHasFrame, (cams != null) ? cams.length : 0);
  } else if (uiMode == UI_FONDO) {
    uiOverlay.drawFondoPreview(10, 40, CFG.PREVIEW_W, CFG.PREVIEW_H, assets.getBgFondo(), assets.getFondoCount());
  } else if (uiMode == UI_GRID) {
    uiOverlay.drawGridOverlay(activeCell, selectedCell, CFG.GRID_COLS, CFG.GRID_ROWS);
  } else if (uiMode == UI_HELP) {
    uiOverlay.drawHelpMenu(assets.getSpeciesCount());
  } else if (uiMode == UI_ROI) {
    if (CFG.FIDUCIAL_ENABLED && fidu != null && camHasFrame && camBuffer != null) {
      FiducialHit uiHit = fidu.detect(camBuffer.get());
      if (uiHit != null && uiHit.found) {
        lastFiducialHit = uiHit;
        blobber.updateFromFiducialCorners(uiHit.corners);
      }
    }

    uiOverlay.drawRoiPreviewAndOverlay(10, 40, CFG.PREVIEW_W, CFG.PREVIEW_H,
      camBuffer, camHasFrame,
      blobber.getRoiX(), blobber.getRoiY(), blobber.getRoiW(), blobber.getRoiH(), blobber.getRoiQuad(),
      blobber.whiteThr, blobber.getMatrixLedCount());
  }

  // Post (fiducial + applySpeciesProfile + sonidos + spawn)
  if (ejecutarPost && millis() >= tiempoDisparoPost) {
    ejecutarPost = false;

    // Flujo post: segmentar con snapshot original y rotar solo el resultado final.
    float rotAfterProfileDeg = 0;
    boolean accepted = false;
    int markerId = -1;
    float rawDeg = 0;
    float snapDeg = 0;

    // 1) Detectar fiducial, si se acepta, aplicar especie y rotar, ANTES del audio
    if (CFG.FIDUCIAL_ENABLED && fidu != null && frozenSnap != null) {
      FiducialHit hit = fidu.detect(frozenSnap);

      if (hit != null && hit.found) {
        lastFiducialHit = hit;
        markerId = hit.id;
        rawDeg = hit.rawAngleDeg;
        snapDeg = hit.snappedAngleDeg;

        int idx = assets.findSpeciesIndexByFiducialId(markerId);
        if (idx >= 0 && idx < assets.getSpeciesCount()) {
          assets.applySpeciesProfile(idx);
          accepted = true;
          rotAfterProfileDeg = -snapDeg;
        }

        if (CFG.FIDUCIAL_DEBUG_PRINT) {
          if (accepted) {
            println("FIDUCIAL: OK id=" + markerId + ", raw=" + nf(rawDeg, 0, 1) + " deg, snap=" + nf(snapDeg, 0, 1) + " deg");
          } else {
            println("FIDUCIAL: detectado id=" + markerId + ", raw=" + nf(rawDeg, 0, 1) + " deg, snap=" + nf(snapDeg, 0, 1) + " deg, pero sin especie válida, ignorando");
          }
        }

      } else {
        if (CFG.FIDUCIAL_DEBUG_PRINT) {
          println("FIDUCIAL: no detectado, se mantiene selección manual, sin rotación");
        }
      }
    }

    boolean shouldForceScan = forceScanTestMode;
    boolean shouldScan = accepted || shouldForceScan;

    if (!shouldScan && CFG.FIDUCIAL_DEBUG_PRINT) {
      println("SCAN: omitido (sin código Boof válido y modo test desactivado)");
    }

    if (shouldScan) {
      if (lastFiducialHit != null && lastFiducialHit.corners != null) {
        blobber.updateFromFiducialCorners(lastFiducialHit.corners);
      }

      // 2) Reproducir sonidos DESPUÉS de applySpeciesProfile (si hubo)
      SoundFile s1 = assets.getSound1();
      SoundFile s2 = assets.getSound2();
      if (s1 != null) s1.play();
      if (s2 != null) s2.play();

      // Spawn desde snapshot original; rotación aplicada solo al pez segmentado.
      spawnNewFishFromSnapshot(frozenSnap, accepted ? rotAfterProfileDeg : 0);
    }


    frozenSnap = null;
  }

  drawTestModeIndicator();

}

void drawTestModeIndicator() {
  if (!forceScanTestMode) return;

  pushStyle();
  noStroke();
  fill(255, 18);
  ellipse(width - 10, 10, 6, 6);
  popStyle();
}

// =========================
// Cámara buffer
// =========================
void updateCameraBuffer() {
  if (cam == null || camBuffer == null) return;

  if (cam.available()) {
    cam.read();

    if (cam.width > 0 && cam.height > 0) {
      camBuffer.beginDraw();
      camBuffer.imageMode(CORNER);
      camBuffer.image(cam, 0, 0, camBuffer.width, camBuffer.height);
      camBuffer.endDraw();
      camHasFrame = true;
    }
  }
}

void switchCameraByIndex(int newIndex) {
  if (cams == null || cams.length == 0) return;

  newIndex = constrain(newIndex, 0, cams.length - 1);
  if (cam != null && newIndex == selectedCam) return;

  selectedCam = newIndex;

  if (cam != null) {
    cam.stop();
    cam = null;
  }

  cam = new Capture(this, cams[selectedCam]);
  cam.start();

  // Limpia buffer
  if (camBuffer != null) {
    camBuffer.beginDraw();
    camBuffer.background(0);
    camBuffer.endDraw();
    camHasFrame = false;
  }

  println("Cambiando a cámara " + (selectedCam + 1) + ": " + cams[selectedCam]);
}

// =========================
// Key handlers
// =========================
void keyPressed() {
  if (handleUiKeys()) return;
  handleActionKeys();
}

// =========================
// UI keys, un solo modo activo
// =========================
boolean handleUiKeys() {

  // ROI calibración
  if (uiMode == UI_ROI) {
 
  // Salir de ROI
  if (key == 'o' || key == 'O') { 
    uiSet(UI_NONE); 
    return true; 
  }
  
    // Ajuste thresholds
    if (key == ',') { blobber.whiteThr = max(0, blobber.whiteThr - 1); return true; }
    if (key == '.') { blobber.whiteThr = min(255, blobber.whiteThr + 1); return true; }

    // Ajuste de LEDs siempre encendidos en la matriz
    if (key == 'j' || key == 'J') {
      blobber.nudgeMatrixLedCount(-1);
      syncMatrixLedCountToArduino();
      return true;
    }
    if (key == 'k' || key == 'K') {
      blobber.nudgeMatrixLedCount(+1);
      syncMatrixLedCountToArduino();
      return true;
    }


    // Guardar / cargar
    if (key == 's' || key == 'S') { blobber.saveROI(); return true; }
    if (key == 'l' || key == 'L') {
      blobber.loadROI();
      syncMatrixLedCountToArduino();
      return true;
    }
    if (key == '1') { blobber.setMarkerPlacement(BlobSegmenter.MARKER_TOP_LEFT); return true; }
    if (key == '2') { blobber.setMarkerPlacement(BlobSegmenter.MARKER_TOP_RIGHT); return true; }
    if (key == '3') { blobber.setMarkerPlacement(BlobSegmenter.MARKER_BOTTOM_RIGHT); return true; }
    if (key == '4') { blobber.setMarkerPlacement(BlobSegmenter.MARKER_BOTTOM_LEFT); return true; }

    // Flechas: ajustar extents del ROI anclado
    if (key == CODED) {
      int dExtentX = 0;
      int dExtentY = 0;

      if (keyCode == LEFT)  dExtentX = +roiStep;
      if (keyCode == RIGHT) dExtentX = -roiStep;
      if (keyCode == DOWN)  dExtentY = +roiStep;
      if (keyCode == UP)    dExtentY = -roiStep;
      if (dExtentX != 0 || dExtentY != 0) {
        blobber.nudgeExtent(dExtentX, dExtentY);
        if (lastFiducialHit != null && lastFiducialHit.corners != null) {
          blobber.updateFromFiducialCorners(lastFiducialHit.corners);
        }
        return true;
      }
    }

    return false;
  }

  // Flechas y Enter solo en modo rejilla
  if (uiMode == UI_GRID) {
    if (key == CODED) {
      int col = activeCell % CFG.GRID_COLS;
      int row = activeCell / CFG.GRID_COLS;

      if (keyCode == LEFT)  col = max(0, col - 1);
      if (keyCode == RIGHT) col = min(CFG.GRID_COLS - 1, col + 1);
      if (keyCode == UP)    row = max(0, row - 1);
      if (keyCode == DOWN)  row = min(CFG.GRID_ROWS - 1, row + 1);

      activeCell = row * CFG.GRID_COLS + col;
      return true;
    }

    if (key == ENTER || key == RETURN) {
      selectedCell = activeCell;
      uiSet(UI_NONE);
      println("Celda seleccionada: " + (selectedCell + 1));
      return true;
    }
  }

  // F1..F9 solo si el preview correspondiente está activo
  if (key == CODED && keyCode >= 97 && keyCode <= 105) {
    int idx = keyCode - 97;

    if (uiMode == UI_CAM) {
      switchCameraByIndex(idx);
      return true;
    }
    if (uiMode == UI_FONDO) {
      assets.applyFondo(idx);
      return true;
    }
  }

  // Toggles de UI
  if (key == 'p' || key == 'P') { uiToggle(UI_CAM);   return true; }
  if (key == 'f' || key == 'F') { uiToggle(UI_FONDO); return true; }
  if (key == 'h' || key == 'H') { uiToggle(UI_HELP);  return true; }
  if (key == 'g' || key == 'G') { uiToggle(UI_GRID);  return true; }

  // Nuevo: modo ROI
  if (key == 'o' || key == 'O') { uiToggle(UI_ROI); return true; }

  return false;
}

void handleActionKeys() {
  // Soltar comida por especie
  int sFood = speciesFromFoodKey(key);
  if (sFood != -1) {
    spawnFoodForSpecies(sFood);
    return;
  }

  // Cambiar especie 1..9
  if (key >= '1' && key <= '9') {
    int num = (int)(key - '1');
    if (num < assets.getSpeciesCount()) assets.applySpeciesProfile(num);
    return;
  }

  // Clear
  if (key == 'c' || key == 'C') {
    clearAllFish();
    return;
  }

  // Eliminar último pez agregado (LIFO)
  if (key == 'u' || key == 'U') {
    removeLastFish();
    return;
  }

  // Captura (SPACE)
  if (key == ' ') {
    if (ejecutarPost) return;

    if (camBuffer != null) frozenSnap = camBuffer.get();
    else frozenSnap = null;

    if (arduinoDisponible && arduino != null) arduino.write("1\n");

    tiempoDisparoPost = millis() + cfgEsperaPostMs;
    ejecutarPost = true;
    return;
  }

  // Modo test: fuerza escaneo aunque no se detecte Boof.
  if (key == 't' || key == 'T') {
    forceScanTestMode = !forceScanTestMode;
    println("Modo test " + (forceScanTestMode ? "ACTIVO" : "INACTIVO"));
    return;
  }

  // Tamaño del pez
  if (key == '+' || key == '=') {
    fishH = min(CFG.MAX_FISH_H, fishH + 10);
    normalizeFishSizeFromH();
    updateAllBoidsSize();
    return;
  }

  if (key == '-') {
    fishH = max(CFG.MIN_FISH_H, fishH - 10);
    normalizeFishSizeFromH();
    updateAllBoidsSize();
    return;
  }
}

// =========================
// Tamaño pez
// =========================
void normalizeFishSizeFromH() {
  fishW = max(10, round(fishH * (float)CFG.BASE_ASPECT));
}

void updateAllBoidsSize() {
  for (int i = 0; i < tlwanderers.size(); i++) {
    tlwanderers.get(i).setRenderSize(fishW, fishH);
  }
}

// =========================
// Spawn pez desde captura
// =========================
AnimalAgent createAgentForSpecies(int speciesIndex, PImage skin, PVector spawnLocation, float maxSpeed, float maxForce) {
  int foodSpeciesId = speciesIndex;
  if (assets != null) foodSpeciesId = assets.getFoodIndexForSpecies(speciesIndex);

  AnimalAgent agent = new FishAgent(skin, spawnLocation, maxSpeed, maxForce, speciesIndex);
  agent.setFoodSpeciesId(foodSpeciesId);
  return agent;
}

void spawnNewFishFromSnapshot(PImage snapshot, float rotAfterProfileDeg) {

  int w = CFG.CAM_BUFFER_W;
  int h = CFG.CAM_BUFFER_H;

  if (snapshot == null || blobber == null) return;

  // Alpha por blobs usando el snapshot ya procesado (rotado o no)
  int[] alphaMap = blobber.buildAlphaFromSnapshot(snapshot);
  if (alphaMap == null) return;

  PImage snap = snapshot;
  snap.loadPixels();

  if (snap.pixels == null) return;
  if (snap.pixels.length != alphaMap.length) {
    println("Snapshot y alpha blob no coinciden en tamaño, revisa CAM_BUFFER_W,H");
    return;
  }

  PImage fishImage = createImage(w, h, ARGB);
  fishImage.loadPixels();

  for (int i = 0; i < fishImage.pixels.length; i++) {
    int a = alphaMap[i];
    int rgb = snap.pixels[i] & 0x00FFFFFF;
    fishImage.pixels[i] = (a << 24) | rgb;
  }

  fishImage.updatePixels();

  int speciesIndex = assets.getSpeciesIndex();

  // Rotación SOLO después de calcular la alpha con ROI estable.
  if (abs(rotAfterProfileDeg) > 0.0001) {
    fishImage = rotatePImageKeepSize(fishImage, rotAfterProfileDeg);
  }


  float ms = random(0.8, 1.9);
  float mf = 0.2;

  AnimalAgent b = createAgentForSpecies(
    speciesIndex,
    fishImage,
    new PVector(0, 0),
    ms,
    mf
  );

  SpawnBehavior spawnBehavior = b.getSpawnBehavior();
  PVector spawnPos = (spawnBehavior != null)
    ? spawnBehavior.getSpawnPosition(selectedCell)
    : new PVector(width * 0.5, height * 0.5);

  b.location.set(spawnPos);
  b.setRenderSize(fishW, fishH);

  if (spawnBehavior != null) {
    spawnBehavior.initializeAgent(b);
  } else {
    b.muscleFreq = random(CFG.MUSCLE_FREQ_MIN, CFG.MUSCLE_FREQ_MAX);
  }

  tlwanderers.add(b);
  maybePrintStatsOnChange();
}

// =========================
// Clear
// =========================
void clearAllFish() {
  tlwanderers.clear();
  maybePrintStatsOnChange();
}

void removeLastFish() {
  if (tlwanderers == null || tlwanderers.isEmpty()) return;

  tlwanderers.remove(tlwanderers.size() - 1);
  maybePrintStatsOnChange();
}

// =========================
// Comida helpers
// =========================
int speciesFromFoodKey(char k) {
  k = Character.toLowerCase(k);
  for (int i = 0; i < CFG.FOOD_KEYS.length; i++) {
    if (k == CFG.FOOD_KEYS[i]) return i;
  }
  return -1;
}

int countPelletsForSpecies(int speciesIdx) {
  if (foodPellets == null || foodPellets.isEmpty()) return 0;

  int c = 0;
  for (int i = 0; i < foodPellets.size(); i++) {
    FoodPellet p = foodPellets.get(i);
    if (p == null) continue;
    if (p.speciesId == speciesIdx) c++;
  }
  return c;
}


int getSpeciesColor(int speciesIdx) {
  if (cfgSpeciesFoodColors != null
    && cfgSpeciesFoodColorSet != null
    && speciesIdx >= 0
    && speciesIdx < cfgSpeciesFoodColors.length
    && speciesIdx < cfgSpeciesFoodColorSet.length
    && cfgSpeciesFoodColorSet[speciesIdx]) {
    return cfgSpeciesFoodColors[speciesIdx];
  }

  int denom = max(1, cfgSpeciesFoodColors.length);

  pushStyle();
  colorMode(HSB, 360, 100, 100, 255);
  float hue = (speciesIdx * 360.0) / denom;
  int c = color(hue % 360.0, 85, 100, 255);
  popStyle();
  return c;
}

int varyFoodColorTone(int baseColor) {
  float toneRange = constrain(cfgFoodColorToneRange, 0.0, 1.0);
  if (toneRange <= 0.0001) return baseColor;

  pushStyle();
  colorMode(HSB, 360, 100, 100, 255);

  float h = hue(baseColor);
  float s = saturation(baseColor);
  float b = brightness(baseColor);
  float a = alpha(baseColor);

  float hueDelta = 25.0 * toneRange;
  float satDelta = 18.0 * toneRange;
  float briDelta = 16.0 * toneRange;

  float newH = (h + random(-hueDelta, hueDelta) + 360.0) % 360.0;
  float newS = constrain(s + random(-satDelta, satDelta), 0, 100);
  float newB = constrain(b + random(-briDelta, briDelta), 0, 100);

  int varied = color(newH, newS, newB, a);
  popStyle();

  return varied;
}


float getFoodSpawnXForSpecies(int speciesIdx) {
  int n = max(1, cfgSpeciesFoodColors.length);
  float segmentW = width / (float)n;

  float x = (speciesIdx + 0.5) * segmentW;

  float jitter = segmentW * 0.12;
  x += random(-jitter, jitter);

  return constrain(x, 10, width - 10);
}

void spawnFoodForSpecies(int speciesIdx) {
  int foodTypeCount = cfgSpeciesFoodColors.length;
  if (foodTypeCount <= 0) return;
  if (speciesIdx < 0 || speciesIdx >= foodTypeCount) return;
  if (!cfgSpeciesFoodColorSet[speciesIdx]) return;

  // Límite por especie: si ya hay demasiados, ignorar el spawn
  int current = countPelletsForSpecies(speciesIdx);
  if (current >= CFG.FOOD_MAX_PER_SPECIES) {
    // opcional: imprimir una vez por intento
    // println("Límite alcanzado para comida " + (speciesIdx + 1) + ": " + current);
    return;
  }


  int c = getSpeciesColor(speciesIdx);

  int n = max(1, foodTypeCount);
  float segmentW = width / (float)n;

  float baseX = getFoodSpawnXForSpecies(speciesIdx);

  int count = CFG.FOOD_COUNT_MIN + (int)random(CFG.FOOD_COUNT_JITTER + 1);

  int room = CFG.FOOD_MAX_PER_SPECIES - current;
  if (room <= 0) return;
  if (count > room) count = room;

  float spreadX = segmentW * CFG.FOOD_SPREAD_SEGMENT;
  float maxStaggerY = CFG.FOOD_STAGGER_Y;

  for (int i = 0; i < count; i++) {
    float x = baseX + random(-spreadX, spreadX);
    x = constrain(x, 10, width - 10);

    float y = -random(10, maxStaggerY);

    float r = random(CFG.FOOD_R_MIN, CFG.FOOD_R_MAX);
    float fall = map(r, CFG.FOOD_R_MIN, CFG.FOOD_R_MAX, CFG.FOOD_FALL_FAST, CFG.FOOD_FALL_SLOW)
      + random(-CFG.FOOD_FALL_JITTER, CFG.FOOD_FALL_JITTER);

    int variedColor = varyFoodColorTone(c);
    foodPellets.add(new FoodPellet(x, y, speciesIdx, variedColor, r, fall));
  }
  maybePrintStatsOnChange();

}

void serialEvent(Serial s) {
  while (s != null && s.available() > 0) {
    char c = (char)s.read();
    handleArduinoChar(c);
  }
}

void handleArduinoChar(char c) {

  // Botón de captura: Arduino manda 'S'
  if (c == 'S' || c == 's') {
    triggerCaptureFromHardware();
    return;
  }

  // Botones de comida: Arduino manda 'z','x','v'
  int sFood = speciesFromFoodKey(c);
  if (sFood != -1) {
    spawnFoodForSpecies(sFood);
    return;
  }
}

void triggerCaptureFromHardware() {
  if (ejecutarPost) return;

  // La captura se toma en draw(), despues de actualizar camBuffer.
  hwCaptureRequested = true;
}
