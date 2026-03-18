class GridSpawnBehavior extends SpawnBehavior {

  PVector getSpawnPosition(int selectedCell) {
    int maxCells = CFG.GRID_COLS * CFG.GRID_ROWS - 1;
    int cellIdx = constrain(selectedCell, 0, maxCells);

    float cellW = width / (float)CFG.GRID_COLS;
    float cellH = height / (float)CFG.GRID_ROWS;

    int col = cellIdx % CFG.GRID_COLS;
    int row = cellIdx / CFG.GRID_COLS;

    float cx = (col + 0.5) * cellW;
    float cy = (row + 0.5) * cellH;

    return new PVector(cx, cy);
  }

  void initializeAgent(AnimalAgent agent) {
    agent.muscleFreq = random(CFG.MUSCLE_FREQ_MIN, CFG.MUSCLE_FREQ_MAX);
  }
}
