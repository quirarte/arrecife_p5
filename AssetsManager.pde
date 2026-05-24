class AssetsManager {

  final PApplet p;

  // Listas de assets (runtime desde app_config.json)
  SpeciesProfile[] speciesProfiles = new SpeciesProfile[0];
  String[] fondoFiles = new String[0];

  // Estado actual
  int speciesIndex = 0;

  // Assets cargados
  PImage bgFondo = null;
  SoundFile sound1 = null;
  SoundFile sound2 = null;

  // Cache background cover
  int bgCacheCanvasW = -1;
  int bgCacheCanvasH = -1;
  PImage bgCacheImg = null;
  PGraphics bgCoverCache = null;

  AssetsManager(PApplet p) {
    this.p = p;
  }

  void setSpeciesProfiles(SpeciesProfile[] profiles) {
    if (profiles == null || profiles.length == 0) {
      speciesProfiles = new SpeciesProfile[0];
      speciesIndex = 0;
      sound1 = null;
      sound2 = null;
      println("No se cargaron perfiles de especie desde configuracion runtime");
      return;
    }

    SpeciesProfile[] loaded = new SpeciesProfile[profiles.length];
    int valid = 0;

    for (int i = 0; i < profiles.length; i++) {
      if (profiles[i] == null) continue;
      loaded[valid++] = profiles[i];
    }

    speciesProfiles = new SpeciesProfile[valid];
    for (int i = 0; i < valid; i++) speciesProfiles[i] = loaded[i];

    speciesIndex = 0;
    if (valid > 0) applySpeciesProfile(0);
    else {
      sound1 = null;
      sound2 = null;
      println("No quedaron perfiles de especie validos tras parsear configuracion runtime");
    }
  }

  void setFondoFiles(String[] files) {
    if (files == null || files.length == 0) {
      fondoFiles = new String[0];
      bgFondo = null;
      println("No se cargaron fondos desde configuracion runtime");
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

  void applyFondo(int idx) {
    if (fondoFiles == null || fondoFiles.length == 0) return;

    idx = constrain(idx, 0, fondoFiles.length - 1);
    PImage img = p.loadImage(fondoFiles[idx]);
    if (img == null) {
      println("No se pudo cargar fondo: " + fondoFiles[idx]);
      return;
    }

    bgFondo = img;
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

  void applySpeciesProfile(int idx) {
    if (speciesProfiles == null || speciesProfiles.length == 0) return;

    idx = constrain(idx, 0, speciesProfiles.length - 1);
    speciesIndex = idx;

    SpeciesProfile cfg = speciesProfiles[speciesIndex];
    applySounds(cfg.sound1File, cfg.sound2File);

    println("Especie activa: #" + (speciesIndex + 1) + " (fiducial_id=" + cfg.fiducialId + ")");
  }

  int findSpeciesIndexByFiducialId(int fiducialId) {
    if (speciesProfiles == null || speciesProfiles.length == 0) return -1;

    for (int i = 0; i < speciesProfiles.length; i++) {
      SpeciesProfile cfg = speciesProfiles[i];
      if (cfg == null) continue;
      if (cfg.fiducialId == fiducialId) return i;
    }
    return -1;
  }

  int getFoodIndexForSpecies(int idx) {
    if (speciesProfiles == null || idx < 0 || idx >= speciesProfiles.length) return idx;
    SpeciesProfile cfg = speciesProfiles[idx];
    return (cfg == null) ? idx : cfg.foodIndex;
  }

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

  int getSpeciesIndex() { return speciesIndex; }

  int getSpeciesCount() { return (speciesProfiles == null) ? 0 : speciesProfiles.length; }

  int getFondoCount() { return (fondoFiles == null) ? 0 : fondoFiles.length; }

  PImage getBgFondo() { return bgFondo; }

  SoundFile getSound1() { return sound1; }

  SoundFile getSound2() { return sound2; }

}
