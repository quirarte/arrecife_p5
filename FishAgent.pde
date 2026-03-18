class FishAgent extends AnimalAgent {
  FishAgent(PImage _skin, PVector _location, float _maxSpeed, float _maxForce, int _speciesId) {
    super(_skin, _location, _maxSpeed, _maxForce, _speciesId);
    setBehavior(new FishClassicBehavior());
  }
}
