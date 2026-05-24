abstract class SpeciesBehavior {
  abstract void updateMovement(AnimalAgent agent, ArrayList<FoodPellet> foods);

  void tryEat(AnimalAgent agent, ArrayList<FoodPellet> foods) {
    if (foods == null || foods.isEmpty()) return;

    agent.getMouthPointLocalStable(agent.tmpMouthStable);
    float mx = agent.location.x + agent.tmpMouthStable.x;
    float my = agent.location.y + agent.tmpMouthStable.y;
    float biteR = max(CFG.BITE_R_MIN, min(CFG.BITE_R_MAX * biteRadiusMultiplier(), agent.renderH * CFG.BITE_R_SCALE * biteRadiusMultiplier()));

    for (int i = foods.size() - 1; i >= 0; i--) {
      FoodPellet p = foods.get(i);
      if (p.speciesId != agent.foodSpeciesId) continue;

      float dx = mx - p.pos.x;
      float dy = my - p.pos.y;
      float rr = biteR + p.r;
      if (dx*dx + dy*dy <= rr*rr) foods.remove(i);
    }
  }

  float biteRadiusMultiplier() {
    return 1;
  }

  FoodPellet keepLockedFoodIfValid(AnimalAgent agent, ArrayList<FoodPellet> foods, int maxFrames) {
    if (agent.lockedFood == null || agent.lockedFoodFrames >= maxFrames) return null;

    for (int i = 0; i < foods.size(); i++) {
      FoodPellet p = foods.get(i);
      if (p == agent.lockedFood && p.speciesId == agent.foodSpeciesId) {
        agent.lockedFoodFrames++;
        return p;
      }
    }

    clearFoodLock(agent);
    return null;
  }

  void clearFoodLock(AnimalAgent agent) {
    agent.lockedFood = null;
    agent.lockedFoodFrames = 0;
  }
}
