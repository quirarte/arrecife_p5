import java.io.File;

class BlobSegmenter {

  final PApplet p;
  final int W;
  final int H;

  static final int MARKER_TOP_LEFT = 1;
  static final int MARKER_TOP_RIGHT = 2;
  static final int MARKER_BOTTOM_RIGHT = 3;
  static final int MARKER_BOTTOM_LEFT = 4;
  static final int MATRIX_LED_COUNT_MIN = 1;
  static final int MATRIX_LED_COUNT_MAX = 64;

  // ROI aproximada en coords del buffer (AABB de la ROI rotada)
  int roiX, roiY, roiW, roiH;
  int roiExtentX, roiExtentY;
  int markerPlacement = MARKER_TOP_LEFT;

  // ROI robusta: cuadrilátero orientado en coords de cámara
  // q0(x,y), q1(x,y), q2(x,y), q3(x,y)
  float[] roiQuad = new float[8];

  // Umbral para considerar "blanco"
  // Foreground si maxRGB < whiteThr
  int whiteThr = 225;
  int matrixLedCount = 2;

  // Buffers reutilizables
  int[] binary;   // 0 o 1, tamaño W*H
  int[] visited;  // 0 o 1, tamaño W*H
  int[] outAlpha; // 0..255, tamaño W*H
  int[] queue;    // indices (i = y*W + x), tamaño W*H
  int[] roiMask;  // 0 o 1, tamaño W*H (1 = dentro de ROI)

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
    roiMask = new int[n];

    clampROI();
    rebuildFallbackQuadFromAabb();
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

  void setMatrixLedCount(int count) {
    matrixLedCount = constrain(count, MATRIX_LED_COUNT_MIN, MATRIX_LED_COUNT_MAX);
  }

  void nudgeMatrixLedCount(int delta) {
    setMatrixLedCount(matrixLedCount + delta);
  }

  void rebuildFallbackQuadFromAabb() {
    float x0 = roiX;
    float y0 = roiY;
    float x1 = roiX + roiW;
    float y1 = roiY + roiH;

    roiQuad[0] = x0; roiQuad[1] = y0;
    roiQuad[2] = x1; roiQuad[3] = y0;
    roiQuad[4] = x1; roiQuad[5] = y1;
    roiQuad[6] = x0; roiQuad[7] = y1;
  }

  void setAabbFromQuad(float[] q) {
    float minX = min(min(q[0], q[2]), min(q[4], q[6]));
    float maxX = max(max(q[0], q[2]), max(q[4], q[6]));
    float minY = min(min(q[1], q[3]), min(q[5], q[7]));
    float maxY = max(max(q[1], q[3]), max(q[5], q[7]));

    int bx0 = constrain(floor(minX), 0, W - 1);
    int by0 = constrain(floor(minY), 0, H - 1);
    int bx1 = constrain(ceil(maxX), bx0 + 1, W);
    int by1 = constrain(ceil(maxY), by0 + 1, H);

    roiX = bx0;
    roiY = by0;
    roiW = max(10, min(W - roiX, bx1 - bx0));
    roiH = max(10, min(H - roiY, by1 - by0));
    clampROI();
  }

  void updateFromFiducialCorners(float[] corners) {
    if (corners == null || corners.length < 8) return;

    int anchorIdx = getAnchorCornerIndex();
    int base = anchorIdx * 2;
    float ax = corners[base];
    float ay = corners[base + 1];

    // Eje local del marcador: u = corner0->corner1, v = corner0->corner3
    float ux = corners[2] - corners[0];
    float uy = corners[3] - corners[1];
    float vx = corners[6] - corners[0];
    float vy = corners[7] - corners[1];

    float uLen = sqrt(ux * ux + uy * uy);
    float vLen = sqrt(vx * vx + vy * vy);

    if (uLen < 0.0001 || vLen < 0.0001) {
      rebuildFallbackQuadFromAabb();
      return;
    }

    ux /= uLen;
    uy /= uLen;
    vx /= vLen;
    vy /= vLen;

    float ex = getGrowXSign() * roiExtentX;
    float ey = getGrowYSign() * roiExtentY;

    float dxX = ux * ex;
    float dxY = uy * ex;
    float dyX = vx * ey;
    float dyY = vy * ey;

    float x0 = ax;
    float y0 = ay;
    float x1 = x0 + dxX;
    float y1 = y0 + dxY;
    float x2 = x1 + dyX;
    float y2 = y1 + dyY;
    float x3 = x0 + dyX;
    float y3 = y0 + dyY;

    roiQuad[0] = x0; roiQuad[1] = y0;
    roiQuad[2] = x1; roiQuad[3] = y1;
    roiQuad[4] = x2; roiQuad[5] = y2;
    roiQuad[6] = x3; roiQuad[7] = y3;

    setAabbFromQuad(roiQuad);
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
      setMatrixLedCount(j.getInt("matrixLedCount", matrixLedCount));
      roiExtentX = max(10, min(W, roiExtentX));
      roiExtentY = max(10, min(H, roiExtentY));
      println("ROI cargado desde roi.json: markerPlacement=" + markerPlacement
        + " extentX=" + roiExtentX + " extentY=" + roiExtentY + " whiteThr=" + whiteThr
        + " matrixLedCount=" + matrixLedCount);
      rebuildFallbackQuadFromAabb();
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
      j.setInt("matrixLedCount", matrixLedCount);
      p.saveJSONObject(j, roiPath());
      println("ROI guardado en roi.json");
      return true;
    } catch (Exception e) {
      println("Error al guardar roi.json: " + e);
      return false;
    }
  }

  boolean pointInConvexQuad(float px, float py, float[] q) {
    float prevCross = 0;
    for (int i = 0; i < 4; i++) {
      int j = (i + 1) % 4;
      float ax = q[i * 2];
      float ay = q[i * 2 + 1];
      float bx = q[j * 2];
      float by = q[j * 2 + 1];

      float ex = bx - ax;
      float ey = by - ay;
      float tx = px - ax;
      float ty = py - ay;
      float cross = ex * ty - ey * tx;

      if (abs(cross) < 0.0001) continue;
      if (prevCross == 0) {
        prevCross = cross;
      } else if ((prevCross > 0 && cross < 0) || (prevCross < 0 && cross > 0)) {
        return false;
      }
    }
    return true;
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
      roiMask[i] = 0;  // 1 = dentro de ROI orientada
    }

    float[] q = roiQuad;
    if (q == null || q.length < 8) {
      rebuildFallbackQuadFromAabb();
      q = roiQuad;
    }

    int x0 = roiX;
    int y0 = roiY;
    int x1 = min(W, roiX + roiW);
    int y1 = min(H, roiY + roiH);

    // 1) Dentro de ROI orientada, por default TODO es pez (opaco)
    // 2) Detectar pixeles "blancos" para flood-fill desde borde de ROI orientada
    for (int y = y0; y < y1; y++) {
      int row = y * W;
      for (int x = x0; x < x1; x++) {
        if (!pointInConvexQuad(x + 0.5, y + 0.5, q)) continue;

        int idx = row + x;
        roiMask[idx] = 1;
        outAlpha[idx] = 255;

        int c = snap.pixels[idx];
        int r = (c >> 16) & 0xFF;
        int g = (c >> 8) & 0xFF;
        int b = c & 0xFF;

        // "Blanco" si los 3 canales son altos (papel)
        // Si tus colores claros se recortan, SUBE whiteThr poco a poco en modo ROI
        if (r >= whiteThr && g >= whiteThr && b >= whiteThr) {
          binary[idx] = 1;
        }
      }
    }

    // 3) Flood fill de "blanco" desde el perímetro de la ROI orientada.
    int qh = 0;
    int qt = 0;

    for (int y = y0; y < y1; y++) {
      int row = y * W;
      for (int x = x0; x < x1; x++) {
        int idx = row + x;
        if (roiMask[idx] == 0 || binary[idx] == 0 || visited[idx] == 1) continue;

        boolean isBoundary = false;
        if (x <= 0 || x >= W - 1 || y <= 0 || y >= H - 1) {
          isBoundary = true;
        } else {
          int left = idx - 1;
          int right = idx + 1;
          int up = idx - W;
          int down = idx + W;
          if (roiMask[left] == 0 || roiMask[right] == 0 || roiMask[up] == 0 || roiMask[down] == 0) {
            isBoundary = true;
          }
        }

        if (!isBoundary) continue;

        visited[idx] = 1;
        queue[qt++] = idx;
      }
    }

    // BFS 4-conectado limitado a ROI orientada, solo sobre pixeles blancos
    while (qh < qt) {
      int idx = queue[qh++];
      int px = idx % W;
      int py = idx / W;

      // Este blanco es exterior: hacerlo transparente
      outAlpha[idx] = 0;

      if (px > 0) {
        int ni = idx - 1;
        if (roiMask[ni] == 1 && binary[ni] == 1 && visited[ni] == 0) {
          visited[ni] = 1;
          queue[qt++] = ni;
        }
      }
      if (px < W - 1) {
        int ni = idx + 1;
        if (roiMask[ni] == 1 && binary[ni] == 1 && visited[ni] == 0) {
          visited[ni] = 1;
          queue[qt++] = ni;
        }
      }
      if (py > 0) {
        int ni = idx - W;
        if (roiMask[ni] == 1 && binary[ni] == 1 && visited[ni] == 0) {
          visited[ni] = 1;
          queue[qt++] = ni;
        }
      }
      if (py < H - 1) {
        int ni = idx + W;
        if (roiMask[ni] == 1 && binary[ni] == 1 && visited[ni] == 0) {
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
  int getMatrixLedCount() { return matrixLedCount; }
  float[] getRoiQuad() { return roiQuad; }
}
