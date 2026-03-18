class SharkAgent extends AnimalAgent {
  SharkAgent(PImage _skin, PVector _location, float _maxSpeed, float _maxForce, int _speciesId) {
    super(_skin, _location, _maxSpeed, _maxForce, _speciesId);
    mirrorSpriteOnTurn = true;
    deferMirrorUntilAfterFirstUpdate = true;
    setBehavior(new SharkBehavior());
    setSpawnBehavior(new SharkSpawnBehavior());
  }
}
