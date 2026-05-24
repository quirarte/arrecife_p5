abstract class SpawnBehavior {
  abstract PVector getSpawnPosition(int selectedCell);

  PVector getGridCellCenter(int selectedCell) {
    int maxCells = CFG.GRID_COLS * CFG.GRID_ROWS - 1;
    int cellIdx = constrain(selectedCell, 0, maxCells);

    float cellW = width / (float)CFG.GRID_COLS;
    float cellH = height / (float)CFG.GRID_ROWS;

    int col = cellIdx % CFG.GRID_COLS;
    int row = cellIdx / CFG.GRID_COLS;

    return new PVector((col + 0.5) * cellW, (row + 0.5) * cellH);
  }

  void initializeAgent(AnimalAgent agent) {
  }
}
