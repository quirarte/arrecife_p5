class SharkBehavior extends SpeciesBehavior {

  final PVector patrolTarget = new PVector();
  int patrolTargetFrames = 0;

  SharkBehavior() {
    patrolTarget.set(-1, -1);
  }

  void updateMovement(AnimalAgent agent, ArrayList<FoodPellet> foods) {
    boolean chasing = seekClosestFood(agent, foods);
    if (!chasing) patrol(agent);
  }

  void tryEat(AnimalAgent agent, ArrayList<FoodPellet> foods) {
    if (foods == null || foods.isEmpty()) return;

    agent.getMouthPointLocalStableForDisplay(agent.tmpMouthStable);
    float mx = agent.location.x + agent.tmpMouthStable.x;
    float my = agent.location.y + agent.tmpMouthStable.y;
    float biteR = max(CFG.BITE_R_MIN, min(CFG.BITE_R_MAX * CFG.SHARK_BITE_RADIUS_MULT, agent.renderH * CFG.BITE_R_SCALE * CFG.SHARK_BITE_RADIUS_MULT));

    for (int i = foods.size() - 1; i >= 0; i--) {
      FoodPellet p = foods.get(i);
      if (p.speciesId != agent.speciesId) continue;

      float dx = mx - p.pos.x;
      float dy = my - p.pos.y;
      float rr = biteR + p.r;
      if (dx*dx + dy*dy <= rr*rr) foods.remove(i);
    }
  }

  void patrol(AnimalAgent agent) {
    clearFoodLock(agent);

    agent.maxSpeed = agent.baseMaxSpeed * CFG.SHARK_CRUISE_SPEED_MULT;
    agent.maxForce = agent.baseMaxForce * CFG.SHARK_CRUISE_FORCE_MULT;

    updatePatrolTarget(agent);
    keepForwardCruise(agent, patrolTarget.x, patrolTarget.y);
    agent.applySteerTo(patrolTarget.x, patrolTarget.y, true, CFG.SHARK_PATROL_REACH_RADIUS * 1.4);
  }

  boolean seekClosestFood(AnimalAgent agent, ArrayList<FoodPellet> foods) {
    if (foods == null || foods.isEmpty()) {
      clearFoodLock(agent);
      return false;
    }

    FoodPellet best = pickFoodTarget(agent, foods);
    if (best == null) {
      clearFoodLock(agent);
      return false;
    }

    agent.maxSpeed = agent.baseMaxSpeed * CFG.SHARK_FOOD_SPEED_MULT;
    agent.maxForce = agent.baseMaxForce * CFG.SHARK_FOOD_FORCE_MULT;

    agent.getMouthPointLocalStableForDisplay(agent.tmpMouthStable);
    float targetX = best.pos.x - agent.tmpMouthStable.x;
    float targetY = best.pos.y - agent.tmpMouthStable.y;

    agent.applySteerTo(targetX, targetY, false, 1);
    return true;
  }

  FoodPellet pickFoodTarget(AnimalAgent agent, ArrayList<FoodPellet> foods) {
    if (agent.lockedFood != null && agent.lockedFoodFrames < CFG.LOCK_FRAMES * 2) {
      for (int i = 0; i < foods.size(); i++) {
        FoodPellet p = foods.get(i);
        if (p == agent.lockedFood && p.speciesId == agent.speciesId) {
          agent.lockedFoodFrames++;
          return p;
        }
      }
      clearFoodLock(agent);
    }

    FoodPellet best = null;
    float bestScore = 1e18;

    for (int i = 0; i < foods.size(); i++) {
      FoodPellet p = foods.get(i);
      if (p.speciesId != agent.speciesId) continue;

      float dx = p.pos.x - agent.location.x;
      float dy = p.pos.y - agent.location.y;
      float d2 = dx*dx + dy*dy;
      float verticalBias = abs(p.pos.y - height * CFG.SHARK_PATROL_LANE_Y) * CFG.SHARK_FOOD_VERTICAL_WEIGHT;
      float headingBias = abs(dy) * CFG.SHARK_FOOD_HEADING_WEIGHT;
      float score = d2 + verticalBias + headingBias;

      if (score < bestScore) {
        bestScore = score;
        best = p;
      }
    }

    agent.lockedFood = best;
    agent.lockedFoodFrames = 0;
    return best;
  }

  void clearFoodLock(AnimalAgent agent) {
    agent.lockedFood = null;
    agent.lockedFoodFrames = 0;
  }

  void updatePatrolTarget(AnimalAgent agent) {
    patrolTargetFrames++;

    float dx = patrolTarget.x - agent.location.x;
    float dy = patrolTarget.y - agent.location.y;
    float reachR = CFG.SHARK_PATROL_REACH_RADIUS;
    boolean reachedTarget = dx*dx + dy*dy <= reachR * reachR;
    boolean invalidTarget = patrolTarget.x < 0 || patrolTarget.y < 0;
    boolean timeout = patrolTargetFrames >= CFG.SHARK_PATROL_MAX_FRAMES;

    if (invalidTarget || reachedTarget || timeout) {
      choosePatrolTarget(agent, reachedTarget);
    }
  }

  void choosePatrolTarget(AnimalAgent agent, boolean reachedTarget) {
    float dirX = (agent.velocity.x >= 0) ? 1 : -1;
    if (!reachedTarget && patrolTargetFrames < CFG.SHARK_PATROL_MIN_FRAMES) {
      dirX = (patrolTarget.x >= agent.location.x) ? 1 : -1;
    }

    float sideMargin = width * CFG.SHARK_PATROL_SIDE_MARGIN;
    float minX = sideMargin;
    float maxX = width - sideMargin;
    float minY = max(CFG.BORDER_PAD, height * (CFG.SHARK_PATROL_LANE_Y - CFG.SHARK_PATROL_BAND_HEIGHT));
    float maxY = min(height - CFG.BORDER_PAD, height * (CFG.SHARK_PATROL_LANE_Y + CFG.SHARK_PATROL_BAND_HEIGHT));

    float rawTargetX = (dirX > 0)
      ? random(width * 0.62, maxX)
      : random(minX, width * 0.38);
    float rawTargetY = random(minY, maxY);

    patrolTarget.set(constrain(rawTargetX, minX, maxX), constrain(rawTargetY, minY, maxY));
    patrolTargetFrames = 0;
  }

  void keepForwardCruise(AnimalAgent agent, float targetX, float targetY) {
    float dx = targetX - agent.location.x;
    float dy = targetY - agent.location.y;
    float d2 = dx*dx + dy*dy;
    if (d2 < 0.000001) return;

    float d = sqrt(d2);
    float dirX = dx / d;
    float dirY = dy / d;

    float minForward = agent.maxSpeed * CFG.SHARK_PATROL_FORWARD_MIN;
    float currentForward = agent.velocity.x * dirX + agent.velocity.y * dirY;

    if (currentForward < minForward) {
      agent.velocity.x = dirX * minForward;
      agent.velocity.y = dirY * minForward;
    }
  }
}
