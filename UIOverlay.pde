class UIOverlay {

  final PApplet p;

  UIOverlay(PApplet p) {
    this.p = p;
  }

  void drawPreviewPanel(int x, int y, int w, int h, String label, PImage img) {
    p.noStroke();
    p.fill(0, 140);
    p.rect(x - 6, y - 22, w + 12, h + 28);

    if (img != null) {
      p.imageMode(CORNER);
      p.image(img, x, y, w, h);
    }

    p.noFill();
    p.stroke(255);
    p.rect(x, y, w, h);

    p.fill(255);
    p.textSize(18);
    p.textAlign(LEFT, CENTER);
    p.text(label, x, y - 12);
  }

  void drawFondoPreview(int x, int y, int w, int h, PImage bgFondo, int fondoCount) {
    if (bgFondo == null) return;
    String label = "F1 a F" + fondoCount + " para cambiar fondo.";
    drawPreviewPanel(x, y, w, h, label, bgFondo);
  }

  void drawWebcamPreview(int x, int y, int w, int h, PGraphics camBuffer, boolean camHasFrame, int camCount) {
    if (camBuffer == null) return;

    p.noStroke();
    p.fill(0, 140);
    p.rect(x - 6, y - 22, w + 12, h + 28);

    p.imageMode(CORNER);

    if (camHasFrame) {
      p.image(camBuffer, x, y, w, h);
    } else {
      p.noStroke();
      p.fill(0);
      p.rect(x, y, w, h);
      p.fill(255, 200);
      p.textSize(14);
      p.textAlign(LEFT, TOP);
      p.text("Webcam sin senal", x + 10, y + 10);
    }

    p.noFill();
    p.stroke(255);
    p.rect(x, y, w, h);

    p.fill(255);
    p.textSize(18);
    p.textAlign(LEFT, CENTER);
    p.text("F1 a F" + camCount + " para cambiar webcam.", x, y - 12);
  }


  void drawGridOverlay(int activeCell, int selectedCell, int cols, int rows) {
    float cellW = p.width / (float)cols;
    float cellH = p.height / (float)rows;

    int aCol = activeCell % cols;
    int aRow = activeCell / cols;

    p.noStroke();
    p.fill(200, 80);
    p.rect(aCol * cellW, aRow * cellH, cellW, cellH);

    int sCol = selectedCell % cols;
    int sRow = selectedCell / cols;
    p.noFill();
    p.stroke(255, 220);
    p.strokeWeight(2);
    p.rect(sCol * cellW + 2, sRow * cellH + 2, cellW - 4, cellH - 4);

    p.stroke(255, 140);
    p.strokeWeight(1);

    for (int c = 1; c < cols; c++) {
      float x = c * cellW;
      p.line(x, 0, x, p.height);
    }
    for (int r = 1; r < rows; r++) {
      float y = r * cellH;
      p.line(0, y, p.width, y);
    }

    p.fill(255, 200);
    p.textSize(12);
    p.textAlign(LEFT, TOP);
    p.text("Flechas = mover, Enter = seleccionar", 12, 12);
  }


  void drawRoiPreviewAndOverlay(int x, int y, int w, int h,
      PGraphics camBuffer, boolean camHasFrame,
      int roiX, int roiY, int roiW, int roiH, float[] roiQuad,
      int whiteThr, int matrixLedCount) {
    if (camBuffer == null) return;

    p.noStroke();
    p.fill(0, 140);
    p.rect(x - 6, y - 22, w + 12, h + 56);

    p.imageMode(CORNER);
    if (camHasFrame) p.image(camBuffer, x, y, w, h);

    p.noFill();
    p.stroke(255);
    p.rect(x, y, w, h);

    float sx = w / (float)camBuffer.width;
    float sy = h / (float)camBuffer.height;

    float rx = x + roiX * sx;
    float ry = y + roiY * sy;
    float rw = roiW * sx;
    float rh = roiH * sy;

    p.stroke(0, 255, 0);
    p.strokeWeight(2);
    p.noFill();

    boolean drewQuad = false;
    if (roiQuad != null && roiQuad.length >= 8) {
      p.beginShape();
      for (int i = 0; i < 4; i++) {
        float qx = x + roiQuad[i * 2] * sx;
        float qy = y + roiQuad[i * 2 + 1] * sy;
        p.vertex(qx, qy);
      }
      p.endShape(CLOSE);
      drewQuad = true;
    }

    if (!drewQuad) {
      p.rect(rx, ry, rw, rh);
    }

    p.fill(255);
    p.textSize(14);
    p.textAlign(LEFT, TOP);
    p.text("Flechas=Tamano | 1-4 = Esquina de Codigo", x, y + h + 6);
    p.text(", . = Thr (" + whiteThr + ") | k,j = Leds (" + matrixLedCount + ")", x, y + h + 24);
    p.text("S = Save | L = Load |  O = Salir", x, y + h + 42);
  }

  void drawHelpMenu(int speciesCount) {
    String[] lines = {
      "ESPACIO = captura",
      "P,p = Preview de webcam",
      "F,f = Preview de fondo",
      "G,g = Mostrar rejilla",
      "Flechas + Enter = Seleccionar cuadro",
      "O,o = Calibrar ROI (blob)",
      "C,c = Clear de pantalla",
      "U,u = Elimina el ultimo pez agregado",
      " -  = Reduce tamano",
      " +  = Incrementa tamano",
      "1.." + speciesCount + " = Cambia especie y sonidos",
      "F1..F9 = Cambia webcam (con preview activo)",
      "F1..F9 = Cambia fondo (con preview activo)",
      "Z,X,V,B,N = Soltar comida por especie",
      "T,t = Modo test (fuerza escaneo)"
    };

    p.textSize(18);
    p.textAlign(LEFT, TOP);

    float padX = 18;
    float padY = 16;
    float lineH = 24;

    float maxW = 0;
    for (int i = 0; i < lines.length; i++) {
      maxW = max(maxW, p.textWidth(lines[i]));
    }

    float boxW = maxW + padX * 2;
    float boxH = lines.length * lineH + padY * 2;

    float x = p.width / 2.0 - boxW / 2.0;
    float y = p.height / 2.0 - boxH / 2.0;

    p.noStroke();
    p.fill(0, 140);
    p.rect(x, y, boxW, boxH, 10);

    p.fill(255);
    for (int i = 0; i < lines.length; i++) {
      p.text(lines[i], x + padX, y + padY + i * lineH);
    }

    p.textSize(12);
    p.fill(255, 180);
    p.text("H,h = Este menu", x + padX, y + boxH - 16);
  }
}
