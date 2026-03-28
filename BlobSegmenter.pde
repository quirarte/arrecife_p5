import java.io.File;

class BlobSegmenter {

  final PApplet p;
  final int W;
  final int H;

  static final int MARKER_TOP_LEFT = 1;
  static final int MARKER_TOP_RIGHT = 2;
  static final int MARKER_BOTTOM_RIGHT = 3;
  static final int MARKER_BOTTOM_LEFT = 4;

  // ROI en coords del buffer (W,H)
  int roiX, roiY, roiW, roiH;
  int roiExtentX, roiExtentY;
  int markerPlacement = MARKER_TOP_LEFT;

  // Umbral para considerar "blanco"
  // Foreground si maxRGB < whiteThr
  int whiteThr = 225;

  // Buffers reutilizables
  int[] binary;   // 0 o 1, tamaño W*H
  int[] visited;  // 0 o 1, tamaño W*H
  int[] outAlpha; // 0..255, tamaño W*H
  int[] queue;    // indices (i = y*W + x), tamaño W*H

  BlobSegmenter(PApplet p, int w, int h) {
    this.p = p;
    this.W = max(10, w);
    this.H = max(10, h);

    // Defaults razonables si no hay roi.json
    this.roiX = (int)(W * 0.20);
    this.roiY = (int)(H * 0.15);
    this.roiW = (int)(W * 0.60);
    this.roiH = (int)(H * 0.70);
    this.roiExtentX = this.roiW;
    this.roiExtentY = this.roiH;

    int n = W * H;
    binary = new int[n];
    visited = new int[n];
    outAlpha = new int[n];
    queue = new int[n];

    clampROI();
  }

  String roiPath() {
    return p.sketchPath("roi.json");
  }

  void clampROI() {
    roiW = max(10, min(roiW, W));
    roiH = max(10, min(roiH, H));

    roiX = constrain(roiX, 0, W - roiW);
    roiY = constrain(roiY, 0, H - roiH);
  }

  int getAnchorCornerIndex() {
    if (markerPlacement == MARKER_TOP_LEFT) return 2;      // BR
    if (markerPlacement == MARKER_TOP_RIGHT) return 3;     // BL
    if (markerPlacement == MARKER_BOTTOM_RIGHT) return 0;  // TL
    return 1;                                               // TR
  }

  int getGrowXSign() {
    if (markerPlacement == MARKER_BOTTOM_LEFT) return 1;
    return -1;
  }

  int getGrowYSign() {
    if (markerPlacement == MARKER_BOTTOM_RIGHT || markerPlacement == MARKER_BOTTOM_LEFT) return -1;
    return 1;
  }

  void setMarkerPlacement(int placement) {
    if (placement < MARKER_TOP_LEFT || placement > MARKER_BOTTOM_LEFT) return;
    markerPlacement = placement;
  }

  void nudgeExtent(int dx, int dy) {
    roiExtentX = max(10, min(W, roiExtentX + dx));
    roiExtentY = max(10, min(H, roiExtentY + dy));
  }

  void updateFromFiducialCorners(float[] corners) {
    if (corners == null || corners.length < 8) return;

    int anchorIdx = getAnchorCornerIndex();
    int base = anchorIdx * 2;
    float ax = corners[base];
    float ay = corners[base + 1];

    float x2 = ax + getGrowXSign() * roiExtentX;
    float y2 = ay + getGrowYSign() * roiExtentY;

    int minX = round(min(ax, x2));
    int maxX = round(max(ax, x2));
    int minY = round(min(ay, y2));
    int maxY = round(max(ay, y2));

    roiX = constrain(minX, 0, W - 1);
    roiY = constrain(minY, 0, H - 1);
    roiW = max(10, min(W - roiX, maxX - minX));
    roiH = max(10, min(H - roiY, maxY - minY));
    clampROI();
  }

  boolean loadROI() {
    String path = roiPath();
    File f = new File(path);
    if (!f.exists()) {
      println("roi.json no existe aún, usando defaults");
      return false;
    }

    try {
      JSONObject j = p.loadJSONObject(path);
      if (j == null) return false;

      int loadedPlacement = j.getInt("markerPlacement");
      int loadedExtentX = j.getInt("extentX");
      int loadedExtentY = j.getInt("extentY");

      setMarkerPlacement(loadedPlacement);
      roiExtentX = loadedExtentX;
      roiExtentY = loadedExtentY;
      whiteThr = j.getInt("whiteThr", whiteThr);
      roiExtentX = max(10, min(W, roiExtentX));
      roiExtentY = max(10, min(H, roiExtentY));
      println("ROI cargado desde roi.json: markerPlacement=" + markerPlacement
        + " extentX=" + roiExtentX + " extentY=" + roiExtentY + " whiteThr=" + whiteThr);
      return true;
    } catch (Exception e) {
      println("Error al cargar roi.json (formato nuevo requerido): " + e);
      return false;
    }
  }

  boolean saveROI() {
    try {
      JSONObject j = new JSONObject();
      j.setInt("markerPlacement", markerPlacement);
      j.setInt("extentX", roiExtentX);
      j.setInt("extentY", roiExtentY);
      j.setInt("whiteThr", whiteThr);
      p.saveJSONObject(j, roiPath());
      println("ROI guardado en roi.json");
      return true;
    } catch (Exception e) {
      println("Error al guardar roi.json: " + e);
      return false;
    }
  }

int[] buildAlphaFromSnapshot(PImage snap) {
  if (snap == null) return null;

  snap.loadPixels();
  if (snap.pixels == null) return null;
  if (snap.width != W || snap.height != H) {
    println("Snapshot no coincide con tamaño esperado: snap=" + snap.width + "x" + snap.height + " esperado=" + W + "x" + H);
    return null;
  }

  final int n = W * H;

  // Reset buffers
  for (int i = 0; i < n; i++) {
    visited[i] = 0;  // reutilizamos visited como "whiteVisited"
    outAlpha[i] = 0; // por default fuera del ROI queda transparente
    binary[i] = 0;   // aquí binary = 1 significa "es blanco"
  }

  int x0 = roiX;
  int y0 = roiY;
  int x1 = roiX + roiW;
  int y1 = roiY + roiH;

  // 1) Dentro del ROI, por default TODO es pez (opaco)
  // 2) Detectamos qué pixeles son "blanco" para poder flood-fill desde el borde
  for (int y = y0; y < y1; y++) {
    int row = y * W;
    for (int x = x0; x < x1; x++) {
      int idx = row + x;
      outAlpha[idx] = 255;

      int c = snap.pixels[idx];
      int r = (c >> 16) & 0xFF;
      int g = (c >> 8) & 0xFF;
      int b = c & 0xFF;

      // "Blanco" si los 3 canales son altos (papel)
      // Si tus colores claros se recortan, SUBE whiteThr poco a poco en modo ROI
      if (r >= whiteThr && g >= whiteThr && b >= whiteThr) {
        binary[idx] = 1; // es blanco
      }
    }
  }

  // 3) Flood fill de "blanco" desde el perímetro del ROI.
  // Todo blanco conectado al borde se considera "exterior" y se hace transparente.
  int qh = 0;
  int qt = 0;

  // Encolar blancos del perímetro (arriba y abajo)
  for (int x = x0; x < x1; x++) {
    int idxTop = y0 * W + x;
    if (binary[idxTop] == 1 && visited[idxTop] == 0) {
      visited[idxTop] = 1;
      queue[qt++] = idxTop;
    }

    int idxBot = (y1 - 1) * W + x;
    if (binary[idxBot] == 1 && visited[idxBot] == 0) {
      visited[idxBot] = 1;
      queue[qt++] = idxBot;
    }
  }

  // Encolar blancos del perímetro (izquierda y derecha)
  for (int y = y0; y < y1; y++) {
    int idxL = y * W + x0;
    if (binary[idxL] == 1 && visited[idxL] == 0) {
      visited[idxL] = 1;
      queue[qt++] = idxL;
    }

    int idxR = y * W + (x1 - 1);
    if (binary[idxR] == 1 && visited[idxR] == 0) {
      visited[idxR] = 1;
      queue[qt++] = idxR;
    }
  }

  // BFS 4-conectado limitado al ROI, solo sobre pixeles blancos
  while (qh < qt) {
    int idx = queue[qh++];
    int px = idx % W;
    int py = idx / W;

    // Este blanco es exterior: hacerlo transparente
    outAlpha[idx] = 0;

    // izquierda
    if (px > x0) {
      int ni = idx - 1;
      if (binary[ni] == 1 && visited[ni] == 0) {
        visited[ni] = 1;
        queue[qt++] = ni;
      }
    }
    // derecha
    if (px < x1 - 1) {
      int ni = idx + 1;
      if (binary[ni] == 1 && visited[ni] == 0) {
        visited[ni] = 1;
        queue[qt++] = ni;
      }
    }
    // arriba
    if (py > y0) {
      int ni = idx - W;
      if (binary[ni] == 1 && visited[ni] == 0) {
        visited[ni] = 1;
        queue[qt++] = ni;
      }
    }
    // abajo
    if (py < y1 - 1) {
      int ni = idx + W;
      if (binary[ni] == 1 && visited[ni] == 0) {
        visited[ni] = 1;
        queue[qt++] = ni;
      }
    }
  }

  return outAlpha;
}


  // Getters ROI
  int getRoiX() { return roiX; }
  int getRoiY() { return roiY; }
  int getRoiW() { return roiW; }
  int getRoiH() { return roiH; }
  int getExtentX() { return roiExtentX; }
  int getExtentY() { return roiExtentY; }
  int getMarkerPlacement() { return markerPlacement; }
}
