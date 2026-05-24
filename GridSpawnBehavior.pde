class GridSpawnBehavior extends SpawnBehavior {

  PVector getSpawnPosition(int selectedCell) {
    return getGridCellCenter(selectedCell);
  }

  void initializeAgent(AnimalAgent agent) {
    agent.muscleFreq = random(CFG.MUSCLE_FREQ_MIN, CFG.MUSCLE_FREQ_MAX);
  }
}
