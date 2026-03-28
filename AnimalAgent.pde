class AnimalAgent extends FishBody {

  PVector location;
  PVector velocity;
  PVector acceleration;

  float maxForce;
  float maxSpeed;

  float baseMaxSpeed;
  float baseMaxForce;

  int speciesId = 0;
  int foodSpeciesId = 0;

  SpeciesBehavior behavior;
  SpawnBehavior spawnBehavior;

  final PVector tmpMouthStable = new PVector();
  FoodPellet lockedFood = null;
  int lockedFoodFrames = 0;
  boolean mirrorSpriteOnTurn = false;
  boolean deferMirrorUntilAfterFirstUpdate = false;
  boolean turningAround = false;
  float turnProgress = 1;
  float turnStartHeading = 0;
  float turnTargetHeading = 0;
  float turnStartMirrorScale = 1;
  float turnTargetMirrorScale = 1;
  float displayMirrorScale = 1;
  float turnCruiseSpeed = 0;

  AnimalAgent(PImage _skin, PVector _location, float _maxSpeed, float _maxForce, int _speciesId) {
    super(_skin);

    speciesId = _speciesId;
    foodSpeciesId = _speciesId;

    location = _location.copy();
    velocity = new PVector(random(-1, 1), random(-1, 1));
    if (velocity.mag() < 0.001) velocity.set(1, 0);

    acceleration = new PVector(0, 0);

    maxForce = _maxForce;
    maxSpeed = _maxSpeed;

    baseMaxForce = maxForce;
    baseMaxSpeed = maxSpeed;
    displayMirrorScale = (velocity.x < 0) ? -1 : 1;
  }

  void setBehavior(SpeciesBehavior nextBehavior) {
    behavior = nextBehavior;
  }

  SpeciesBehavior getBehavior() {
    return behavior;
  }

  void setSpawnBehavior(SpawnBehavior nextSpawnBehavior) {
    spawnBehavior = nextSpawnBehavior;
  }

  void setFoodSpeciesId(int nextFoodSpeciesId) {
    foodSpeciesId = nextFoodSpeciesId;
  }

  SpawnBehavior getSpawnBehavior() {
    return spawnBehavior;
  }

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

  void run() {
    update();
    borders();
    display();
  }

  void update() {
    updateTurnAround();

    velocity.add(acceleration);
    velocity.limit(maxSpeed);
    location.add(velocity);
    acceleration.set(0, 0);

    float speedRatio = constrain(velocity.mag() / max(0.001, maxSpeed), 0, 1);
    float targetFreq = lerp(CFG.MUSCLE_FREQ_MIN, CFG.MUSCLE_FREQ_MAX, speedRatio);
    super.muscleFreq = lerp(super.muscleFreq, targetFreq, CFG.MUSCLE_FREQ_LERP);

    super.move();

    if (deferMirrorUntilAfterFirstUpdate) deferMirrorUntilAfterFirstUpdate = false;
  }

  void display() {
    float th = getDisplayHeading();
    float mirrorScale = getDisplayMirrorScale();
    PVector bodyCenter = getBodyCenterLocalForDisplay();

    pushMatrix();
    translate(location.x, location.y);
    translate(bodyCenter.x, bodyCenter.y);
    rotate(getDisplaySpinAngle());
    translate(-bodyCenter.x, -bodyCenter.y);
    scale(mirrorScale, 1);

    super.theta = degrees(th);
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

  void updateBehavior(ArrayList<FoodPellet> foods) {
    if (behavior != null) behavior.updateMovement(this, foods);
  }

  void tryEat(ArrayList<FoodPellet> foods) {
    if (behavior != null) behavior.tryEat(this, foods);
  }

  float getDisplayHeading() {
    if (turningAround) return lerpAngle(turnStartHeading, turnTargetHeading, turnProgress);
    if (!mirrorSpriteOnTurn) return velocity.heading();

    float vx = velocity.x;
    float vy = velocity.y;
    if (abs(vx) < 0.0001 && abs(vy) < 0.0001) return 0;

    return atan2(vy, abs(vx));
  }

  boolean shouldMirrorSprite() {
    return getDisplayMirrorScale() < 0;
  }

  float getDisplayMirrorScale() {
    if (!mirrorSpriteOnTurn || deferMirrorUntilAfterFirstUpdate) return 1;
    if (turningAround) return displayMirrorScale;
    return (velocity.x < 0) ? -1 : 1;
  }

  float getDisplaySpinAngle() {
    if (!turningAround) return 0;
    return sin(turnProgress * PI) * PI;
  }

  void beginTurnAround(float nextDirX, float cruiseSpeed) {
    if (!mirrorSpriteOnTurn || turningAround) return;

    turningAround = true;
    turnProgress = 0;
    turnStartHeading = getDisplayHeading();
    float dirX = (nextDirX >= 0) ? 1 : -1;
    float targetVy = constrain(velocity.y, -baseMaxSpeed * 0.25, baseMaxSpeed * 0.25);
    turnTargetHeading = atan2(targetVy, abs(dirX));
    turnStartMirrorScale = getDisplayMirrorScale();
    turnTargetMirrorScale = (dirX < 0) ? -1 : 1;
    displayMirrorScale = turnStartMirrorScale;
    float targetTurnSpeed = baseMaxSpeed * CFG.SHARK_TURN_GLIDE_SPEED_MULT;
    turnCruiseSpeed = (cruiseSpeed > 0) ? min(cruiseSpeed, targetTurnSpeed) : targetTurnSpeed;
    velocity.x = signNonZeroSafe(velocity.x) * turnCruiseSpeed;
    velocity.y *= CFG.SHARK_TURN_GLIDE_DAMPING;
    acceleration.set(0, 0);
  }

  void updateTurnAround() {
    if (!turningAround) return;

    turnProgress += 1.0 / max(1.0, CFG.SHARK_TURN_FRAMES);
    if (turnProgress >= 1) {
      turnProgress = 1;
      turningAround = false;
      displayMirrorScale = turnTargetMirrorScale;
      velocity.x = signNonZeroSafe(turnTargetMirrorScale) * turnCruiseSpeed;
      velocity.y = constrain(velocity.y, -baseMaxSpeed * 0.25, baseMaxSpeed * 0.25);
      return;
    }

    displayMirrorScale = lerp(turnStartMirrorScale, turnTargetMirrorScale, turnProgress);
    float currentDir = signNonZeroSafe(turnStartMirrorScale);
    velocity.x = currentDir * turnCruiseSpeed * lerp(1.0, CFG.SHARK_TURN_GLIDE_DAMPING, turnProgress);
    velocity.y *= CFG.SHARK_TURN_GLIDE_DAMPING;
  }

  float lerpAngle(float start, float stop, float amt) {
    float delta = atan2(sin(stop - start), cos(stop - start));
    return start + delta * amt;
  }

  float signNonZeroSafe(float value) {
    return (value >= 0) ? 1 : -1;
  }

  void getMouthPointLocalStableForDisplay(PVector out) {
    getMouthPointLocalStable(out);
    if (shouldMirrorSprite()) out.x *= -1;
  }

  PVector getBodyCenterLocalForDisplay() {
    PVector out = new PVector();
    if (node == null || node.length == 0) return out;

    int tailIndex = max(0, numNodes - 1);
    out.x = (node[0].x + node[tailIndex].x) * 0.5;
    out.y = (node[0].y + node[tailIndex].y) * 0.5;

    if (shouldMirrorSprite()) out.x *= -1;

    return out;
  }
}
