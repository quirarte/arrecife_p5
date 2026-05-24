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
  }

  void setBehavior(SpeciesBehavior nextBehavior) {
    behavior = nextBehavior;
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
    pushMatrix();
    translate(location.x, location.y);
    super.theta = degrees(getDisplayHeading());
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
    return velocity.heading();
  }
}
