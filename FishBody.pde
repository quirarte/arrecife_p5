class FishBody {

  class Node {
    float x;
    float y;
  }

  int numNodes = 16;
  Node[] node = new Node[numNodes];

  PImage tlskin;

  float renderW = 640;
  float renderH = 480;

  float skinXspacing, skinYspacing;

  float muscleRange = 6;
  float muscleFreq = random(0.06, 0.07);

  float theta = 180;
  float count = 0;

  boolean mouthUVReady = false;
  float mouthU = 0;

  FishBody(PImage _tlskin) {
    tlskin = _tlskin;
    for (int n = 0; n < numNodes; n++) node[n] = new Node();

    setRenderSize((int)renderW, (int)renderH);
    computeMouthUVFromAlpha();
  }


  void setRenderSize(int w, int h) {
    renderW = max(10, w);
    renderH = max(10, h);

    skinXspacing = renderW / (float)(numNodes - 1);
    skinYspacing = renderH / 2.0;
  }

  void move() {
    float th = radians(theta);
    node[0].x = cos(th);
    node[0].y = sin(th);

    count += muscleFreq;
    float thetaMuscle = muscleRange * sin(count);

    float th1 = radians(theta + thetaMuscle);
    node[1].x = -skinXspacing * cos(th1) + node[0].x;
    node[1].y = -skinXspacing * sin(th1) + node[0].y;

    for (int n = 2; n < numNodes; n++) {
      float dx = node[n].x - node[n - 2].x;
      float dy = node[n].y - node[n - 2].y;

      float d2 = dx*dx + dy*dy;
      float d = sqrt(max(0.000001, d2));

      node[n].x = node[n - 1].x + (dx * skinXspacing) / d;
      node[n].y = node[n - 1].y + (dy * skinXspacing) / d;
    }
  }

  void display() {
    if (tlskin == null) return;

    textureMode(IMAGE);
    noStroke();

    beginShape(QUAD_STRIP);
    texture(tlskin);

    float uStep = (numNodes <= 1) ? 0 : (tlskin.width / (float)(numNodes - 1));
    float u = 0;

    for (int n = 0; n < numNodes; n++) {
      float dx, dy;

      if (n == 0) {
        dx = node[1].x - node[0].x;
        dy = node[1].y - node[0].y;
      } else {
        dx = node[n].x - node[n - 1].x;
        dy = node[n].y - node[n - 1].y;
      }

      float angle = -atan2(dy, dx);
      float sinA = sin(angle);
      float cosA = cos(angle);

      float x1 = node[n].x + sinA * -skinYspacing;
      float y1 = node[n].y + cosA * -skinYspacing;
      float x2 = node[n].x + sinA *  skinYspacing;
      float y2 = node[n].y + cosA *  skinYspacing;

      vertex(x1, y1, u, 0);
      vertex(x2, y2, u, tlskin.height);

      u += uStep;
    }

    endShape();
  }

  void computeMouthUVFromAlpha() {
    if (tlskin == null) return;

    tlskin.loadPixels();
    int w = tlskin.width;
    int h = tlskin.height;
    if (w <= 0 || h <= 0 || tlskin.pixels == null) return;

    int y0 = (int)(h * 0.35);
    int y1 = (int)(h * 0.65);

    int bestX = w;
    boolean found = false;

    for (int y = y0; y <= y1; y++) {
      int row = y * w;
      for (int x = 0; x < w; x++) {
        int a = (tlskin.pixels[row + x] >>> 24) & 0xFF;
        if (a > CFG.MOUTH_ALPHA_THR) {
          if (x < bestX) {
            bestX = x;
            found = true;
            if (bestX == 0) break;
          }
        }
      }
      if (bestX == 0) break;
    }

    if (!found) {
      bestX = w;

      for (int y = 0; y < h; y++) {
        int row = y * w;
        for (int x = 0; x < w; x++) {
          int a = (tlskin.pixels[row + x] >>> 24) & 0xFF;
          if (a > CFG.MOUTH_ALPHA_THR) {
            if (x < bestX) {
              bestX = x;
              found = true;
              if (bestX == 0) break;
            }
          }
        }
        if (bestX == 0) break;
      }
    }

    if (!found) {
      mouthU = 0;
      mouthUVReady = true;
      return;
    }

    mouthU = bestX;
    mouthUVReady = true;
  }



  void getMouthPointLocalStable(PVector out) {
    if (!mouthUVReady) computeMouthUVFromAlpha();
    if (tlskin == null) {
      out.set(0, 0);
      return;
    }

    float denomW = max(1.0f, (float)(tlskin.width - 1));
    float t = mouthU / denomW;

    float f = t * (numNodes - 1);

    int i0 = constrain((int)floor(f), 0, numNodes - 1);
    int i1 = min(i0 + 1, numNodes - 1);

    float lt = f - i0;

    float bx = lerp(node[i0].x, node[i1].x, lt);
    float by = lerp(node[i0].y, node[i1].y, lt);

    out.set(bx, by);
  }
}
