class FoodPellet {
  PVector pos;
  PVector vel;
  int speciesId;
  int col;
  float r;

  // NUEVO: 0 = círculo, 5 = pentágono, 6 = hexágono, 7 = heptágono
  int sides;

  FoodPellet(float x, float y, int speciesId, int col, float radius, float fallSpeed) {
    this.pos = new PVector(x, y);
    this.vel = new PVector(random(-0.15, 0.15), fallSpeed);
    this.speciesId = speciesId;
    this.col = col;
    this.r = radius;

    // Forma aleatoria, independiente de la especie.
    int shapeChoice = (int)random(4);
    this.sides = (shapeChoice == 0) ? 0 : shapeChoice + 4;
  }

  void update() {
    pos.add(vel);
  }

  void display() {
    pushStyle();
    noStroke();
    fill(col);

    if (sides <= 2) {
      ellipse(pos.x, pos.y, r * 2, r * 2);
    } else {
      drawRegularPolygon(pos.x, pos.y, r, sides);
    }

    popStyle();
  }

  // NUEVO: polígono regular
  void drawRegularPolygon(float cx, float cy, float radius, int n) {
    beginShape();
    float step = TWO_PI / n;
    float start = -HALF_PI;
    for (int i = 0; i < n; i++) {
      float a = start + i * step;
      vertex(cx + cos(a) * radius, cy + sin(a) * radius);
    }
    endShape(CLOSE);
  }

  boolean isOffscreen() {
    return pos.y > height + r * 3;
  }
}
