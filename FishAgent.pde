class FishAgent extends FishBody {

  // Estado físico
  PVector location;
  PVector velocity;
  PVector acceleration;

  float maxForce;
  float maxSpeed;

  float baseMaxSpeed;
  float baseMaxForce;

  int speciesId = 0;

  // Wander
  float wandertheta;

  // Comida
  float foodSpeedMult = 1.0;

  FoodPellet lockedFood = null;
  int lockedFoodFrames = 0;

  // Scratch
  final PVector tmpMouthStable = new PVector();

  FishAgent(PImage _skin, PVector _location, float _maxSpeed, float _maxForce, int _speciesId) {
    super(_skin);

    speciesId = _speciesId;

    location = _location.copy();
    velocity = new PVector(random(-1, 1), random(-1, 1));
    if (velocity.mag() < 0.001) velocity.set(1, 0);

    acceleration = new PVector(0, 0);

    maxForce = _maxForce;
    maxSpeed = _maxSpeed;

    baseMaxForce = maxForce;
    baseMaxSpeed = maxSpeed;

    wandertheta = random(TWO_PI);

    foodSpeedMult = CFG.FOOD_SPEED_MULT_DEFAULT;
  }


  // Steering sin allocs
  void applySteerTo(float tx, float ty, boolean slowdown, float slowRadius) {
    float dx = tx - location.x;
    float dy = ty - location.y;

    float d2 = dx*dx + dy*dy;
    if (d2 < 0.000001) return;

    float d = sqrt(d2);
    float invD = 1.0 / d;

    float desiredSpeed = maxSpeed;
    if (slowdown && d < slowRadius) {
      desiredSpeed = maxSpeed * (d / max(0.0001, slowRadius));
    }

    float desiredX = dx * invD * desiredSpeed;
    float desiredY = dy * invD * desiredSpeed;

    float steerX = desiredX - velocity.x;
    float steerY = desiredY - velocity.y;

    float s2 = steerX*steerX + steerY*steerY;
    float mf2 = maxForce * maxForce;

    if (s2 > mf2 && s2 > 0.000001) {
      float invS = 1.0 / sqrt(s2);
      float k = maxForce * invS;
      steerX *= k;
      steerY *= k;
    }

    acceleration.x += steerX;
    acceleration.y += steerY;
  }

  void wander() {
    resetToCruise();

    float wanderR = CFG.WANDER_R;
    float wanderD = CFG.WANDER_D;
    float change  = CFG.WANDER_CHANGE;

    wandertheta += random(-change, change);

    float vx = velocity.x;
    float vy = velocity.y;
    float v2 = vx*vx + vy*vy;
    if (v2 < 0.0001) {
      vx = 1;
      vy = 0;
      v2 = 1;
    }
    float invV = 1.0 / sqrt(v2);
    vx *= invV;
    vy *= invV;

    float circleX = location.x + vx * wanderD;
    float circleY = location.y + vy * wanderD;

    float offX = wanderR * cos(wandertheta);
    float offY = wanderR * sin(wandertheta);

    applySteerTo(circleX + offX, circleY + offY, false, 1);
  }

  void run() {
    update();
    borders();
    display();
  }

  void update() {
    velocity.add(acceleration);
    velocity.limit(maxSpeed);
    location.add(velocity);
    acceleration.set(0, 0);

    float speedRatio = constrain(velocity.mag() / max(0.001, maxSpeed), 0, 1);
    float targetFreq = lerp(CFG.MUSCLE_FREQ_MIN, CFG.MUSCLE_FREQ_MAX, speedRatio);
    super.muscleFreq = lerp(super.muscleFreq, targetFreq, CFG.MUSCLE_FREQ_LERP);

    super.move();
  }

  void display() {
    float th = velocity.heading() + PI;

    pushMatrix();
    translate(location.x, location.y);

    super.theta = degrees(th) + 180;
    super.display();


    popMatrix();
  }

  void borders() {
    float pad = CFG.BORDER_PAD;

    float minX = pad;
    float maxX = width - pad;
    float minY = pad;
    float maxY = height - pad;

    if (location.x < minX) location.x = minX;
    if (location.x > maxX) location.x = maxX;
    if (location.y < minY) location.y = minY;
    if (location.y > maxY) location.y = maxY;

    if (location.x == minX) velocity.x = abs(velocity.x);
    if (location.x == maxX) velocity.x = -abs(velocity.x);
    if (location.y == minY) velocity.y = abs(velocity.y);
    if (location.y == maxY) velocity.y = -abs(velocity.y);
  }


  void resetToCruise() {
    maxSpeed = baseMaxSpeed;
    maxForce = baseMaxForce;
  }

  boolean seekClosestFood(ArrayList<FoodPellet> foods) {
    resetToCruise();

    if (foods == null || foods.isEmpty()) {
      clearFoodLock();
      return false;
    }

    FoodPellet best = pickFoodTarget(foods);
    if (best == null) {
      clearFoodLock();
      return false;
    }

    maxSpeed = baseMaxSpeed * foodSpeedMult;
    maxForce = baseMaxForce;

    getMouthPointLocalStable(tmpMouthStable);
    float targetX = best.pos.x - tmpMouthStable.x;
    float targetY = best.pos.y - tmpMouthStable.y;

    float dx = targetX - location.x;
    float dy = targetY - location.y;
    float d2 = dx*dx + dy*dy;
    float d  = sqrt(max(0.000001, d2));

    if (d < CFG.NEAR_FOOD_RADIUS) {
      float invD = 1.0 / d;
      float dirX = dx * invD;
      float dirY = dy * invD;

      float vAlong = velocity.x * dirX + velocity.y * dirY;
      float minAlong = maxSpeed * CFG.NEAR_MIN_ALONG;
      float newAlong = max(vAlong, minAlong);

      velocity.x = dirX * newAlong;
      velocity.y = dirY * newAlong;

      velocity.mult(CFG.NEAR_DAMPING);

      applySteerTo(targetX, targetY, false, 1);
      return true;
    }

    applySteerTo(targetX, targetY, true, CFG.ARRIVE_FAR_SLOW_RADIUS);
    return true;
  }

  FoodPellet pickFoodTarget(ArrayList<FoodPellet> foods) {
    if (lockedFood != null && lockedFoodFrames < CFG.LOCK_FRAMES) {
      boolean stillThere = false;
      for (int i = 0; i < foods.size(); i++) {
        if (foods.get(i) == lockedFood) {
          stillThere = true;
          break;
        }
      }
      if (stillThere && lockedFood.speciesId == speciesId) {
        lockedFoodFrames++;
        return lockedFood;
      } else {
        clearFoodLock();
      }
    }

    FoodPellet best = null;
    float bestScore = 1e18;

    for (int i = 0; i < foods.size(); i++) {
      FoodPellet p = foods.get(i);
      if (p.speciesId != speciesId) continue;

      float dx = p.pos.x - location.x;
      float dy = p.pos.y - location.y;
      float d2 = dx*dx + dy*dy;

      float down = max(0, dy);
      float up   = max(0, -dy);

      float score = d2 - (down*down) * CFG.FOOD_SCORE_DOWN_WEIGHT + (up*up) * CFG.FOOD_SCORE_UP_WEIGHT;

      if (score < bestScore) {
        bestScore = score;
        best = p;
      }
    }

    lockedFood = best;
    lockedFoodFrames = 0;
    return best;
  }

  void clearFoodLock() {
    lockedFood = null;
    lockedFoodFrames = 0;
  }

  void tryEatFoods(ArrayList<FoodPellet> foods) {
    if (foods == null || foods.isEmpty()) return;

    getMouthPointLocalStable(tmpMouthStable);
    float mx = location.x + tmpMouthStable.x;
    float my = location.y + tmpMouthStable.y;

    float biteR = max(CFG.BITE_R_MIN, min(CFG.BITE_R_MAX, renderH * CFG.BITE_R_SCALE));

    for (int i = foods.size() - 1; i >= 0; i--) {
      FoodPellet p = foods.get(i);
      if (p.speciesId != speciesId) continue;

      float dx = mx - p.pos.x;
      float dy = my - p.pos.y;
      float rr = biteR + p.r;

      if (dx*dx + dy*dy <= rr*rr) {
        foods.remove(i);
      }
    }
  }

}
