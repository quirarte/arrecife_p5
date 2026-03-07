class AssetsManager {

  // =========================
  // Config interna
  // =========================
  class SpeciesConfig {
    String sound1File;
    String sound2File;

    SpeciesConfig(String sound1File, String sound2File) {
      this.sound1File = sound1File;
      this.sound2File = sound2File;
    }
  }

  final PApplet p;

  // Dimensiones del buffer base (por ejemplo 640x480)
  final int CAM_BUFFER_W;
  final int CAM_BUFFER_H;

  // =========================
  // Listas de assets (runtime desde app_config.json)
  // =========================
  SpeciesConfig[] speciesProfiles = new SpeciesConfig[0];

  String[] fondoFiles = new String[0];

  // =========================
  // Estado actual
  // =========================
  int speciesIndex = 0;

  // =========================
  // Assets cargados
  // =========================
  PImage bgFondo = null;

  SoundFile sound1 = null;
  SoundFile sound2 = null;

  // =========================
  // Cache background cover
  // =========================
  int bgCacheCanvasW = -1;
  int bgCacheCanvasH = -1;
  PImage bgCacheImg = null;
  PGraphics bgCoverCache = null;

  // =========================
  // Constructores
  // =========================

  AssetsManager(PApplet p, int camW, int camH) {
    this.p = p;
    CAM_BUFFER_W = max(10, camW);
    CAM_BUFFER_H = max(10, camH);
  }


  void setSpeciesProfiles(String[][] soundPairs) {
    if (soundPairs == null || soundPairs.length == 0) {
      speciesProfiles = new SpeciesConfig[0];
      speciesIndex = 0;
      sound1 = null;
      sound2 = null;
      println("No se cargaron perfiles de especie desde configuración runtime");
      return;
    }

    SpeciesConfig[] loaded = new SpeciesConfig[soundPairs.length];
    int valid = 0;

    for (int i = 0; i < soundPairs.length; i++) {
      String s1 = null;
      String s2 = null;

      if (soundPairs[i] != null && soundPairs[i].length > 0) s1 = soundPairs[i][0];
      if (soundPairs[i] != null && soundPairs[i].length > 1) s2 = soundPairs[i][1];

      if (s1 == null || trim(s1).length() == 0) continue;
      if (s2 == null || trim(s2).length() == 0) continue;

      loaded[valid++] = new SpeciesConfig(trim(s1), trim(s2));
    }

    speciesProfiles = new SpeciesConfig[valid];
    for (int i = 0; i < valid; i++) speciesProfiles[i] = loaded[i];

    speciesIndex = 0;
    if (valid > 0) applySpeciesProfile(0);
    else {
      sound1 = null;
      sound2 = null;
      println("No quedaron perfiles de especie válidos tras parsear configuración runtime");
    }
  }

  void setFondoFiles(String[] files) {
    if (files == null || files.length == 0) {
      fondoFiles = new String[0];
      bgFondo = null;
      println("No se cargaron fondos desde configuración runtime");
      return;
    }

    String[] loaded = new String[files.length];
    int valid = 0;

    for (int i = 0; i < files.length; i++) {
      String f = files[i];
      if (f == null || trim(f).length() == 0) continue;
      loaded[valid++] = trim(f);
    }

    fondoFiles = new String[valid];
    for (int i = 0; i < valid; i++) fondoFiles[i] = loaded[i];

    bgFondo = null;
  }

  // =========================
  // Fondos
  // =========================
  void applyFondo(int idx) {
    if (fondoFiles == null || fondoFiles.length == 0) return;

    idx = constrain(idx, 0, fondoFiles.length - 1);
    PImage img = p.loadImage(fondoFiles[idx]);
    if (img == null) {
      println("No se pudo cargar fondo: " + fondoFiles[idx]);
      return;
    }

    bgFondo = img;

    // Invalida cache
    bgCacheImg = null;
    bgCoverCache = null;

    println("Fondo activo: #" + (idx + 1) + " , " + fondoFiles[idx]);
  }

  void drawBackgroundCover(int canvasW, int canvasH) {
    if (bgFondo == null) return;

    updateBackgroundCoverCache(canvasW, canvasH);
    if (bgCoverCache == null) return;

    p.imageMode(CORNER);
    p.image(bgCoverCache, 0, 0);
  }

  void updateBackgroundCoverCache(int canvasW, int canvasH) {
    if (bgFondo == null) return;

    boolean needsRebuild =
      (bgCacheImg != bgFondo) ||
      (bgCacheCanvasW != canvasW) ||
      (bgCacheCanvasH != canvasH) ||
      (bgCoverCache == null);

    if (!needsRebuild) return;

    float sx = (float) canvasW / (float) bgFondo.width;
    float sy = (float) canvasH / (float) bgFondo.height;
    float s = max(sx, sy);

    int drawW = round(bgFondo.width * s);
    int drawH = round(bgFondo.height * s);

    float x = (canvasW - drawW) * 0.5;
    float y = (canvasH - drawH) * 0.5;

    bgCoverCache = p.createGraphics(canvasW, canvasH, P2D);
    bgCoverCache.beginDraw();
    bgCoverCache.imageMode(CORNER);
    bgCoverCache.background(0);
    bgCoverCache.image(bgFondo, x, y, drawW, drawH);
    bgCoverCache.endDraw();

    bgCacheImg = bgFondo;
    bgCacheCanvasW = canvasW;
    bgCacheCanvasH = canvasH;
  }

  // =========================
  // Perfiles de especie
  // =========================
  void applySpeciesProfile(int idx) {
    if (speciesProfiles == null || speciesProfiles.length == 0) return;

    idx = constrain(idx, 0, speciesProfiles.length - 1);
    speciesIndex = idx;

    SpeciesConfig cfg = speciesProfiles[speciesIndex];

    applySounds(cfg.sound1File, cfg.sound2File);

    println("Especie activa: #" + (speciesIndex + 1));
  }

  // =========================
  // Sonidos
  // =========================
  void applySounds(String s1, String s2) {
    try { if (sound1 != null) sound1.stop(); } catch (Exception e) {}
    try { if (sound2 != null) sound2.stop(); } catch (Exception e) {}

    SoundFile a = null;
    SoundFile b = null;

    try { a = new SoundFile(p, s1); }
    catch (Exception e) { println("No se pudo cargar sonido 1: " + s1); }

    try { b = new SoundFile(p, s2); }
    catch (Exception e) { println("No se pudo cargar sonido 2: " + s2); }

    sound1 = a;
    sound2 = b;

    println("Sonidos activos: " + s1 + " , " + s2);
  }

  // =========================
  // Getters
  // =========================
  int getSpeciesIndex() { return speciesIndex; }

  int getSpeciesCount() { return (speciesProfiles == null) ? 0 : speciesProfiles.length; }

  int getFondoCount() { return (fondoFiles == null) ? 0 : fondoFiles.length; }

  PImage getBgFondo() { return bgFondo; }

  SoundFile getSound1() { return sound1; }

  SoundFile getSound2() { return sound2; }

  int getCamBufferW() { return CAM_BUFFER_W; }

  int getCamBufferH() { return CAM_BUFFER_H; }
}
