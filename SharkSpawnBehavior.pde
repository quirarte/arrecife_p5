class SharkSpawnBehavior extends SpawnBehavior {

  PVector getSpawnPosition(int selectedCell) {
    float edgeInset = max(CFG.BORDER_PAD + 10, width * 0.06);
    float spawnY = random(height * 0.18, height * 0.58);
    boolean fromLeft = random(1) < 0.5;
    float spawnX = fromLeft ? edgeInset : width - edgeInset;
    return new PVector(spawnX, spawnY);
  }

  void initializeAgent(AnimalAgent agent) {
    boolean faceRight = agent.location.x < width * 0.5;
    float dirX = faceRight ? 1 : -1;
    float dirY = random(-0.18, 0.18);

    agent.velocity.set(dirX, dirY);
    agent.velocity.normalize();
    agent.velocity.mult(agent.baseMaxSpeed * 0.9);
    agent.muscleFreq = CFG.MUSCLE_FREQ_MIN;
  }
}
