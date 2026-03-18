class SharkBehavior extends SpeciesBehavior {

  float patrolTheta;

  SharkBehavior() {
    patrolTheta = random(TWO_PI);
  }

  void updateMovement(AnimalAgent agent, ArrayList<FoodPellet> foods) {
    boolean chasing = seekClosestFood(agent, foods);
    if (!chasing) patrol(agent);
  }

  void tryEat(AnimalAgent agent, ArrayList<FoodPellet> foods) {
    if (foods == null || foods.isEmpty()) return;

    agent.getMouthPointLocalStable(agent.tmpMouthStable);
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

    patrolTheta += random(-CFG.SHARK_PATROL_TURN_CHANGE, CFG.SHARK_PATROL_TURN_CHANGE);

    float vx = agent.velocity.x;
    float vy = agent.velocity.y;
    if (vx*vx + vy*vy < 0.0001) {
      vx = 1;
      vy = 0;
    }

    float heading = atan2(vy, vx);
    float targetHeading = heading + patrolTheta * CFG.SHARK_PATROL_TURN_BLEND;

    float steerX = cos(targetHeading);
    float steerY = sin(targetHeading);

    float laneCenterY = height * CFG.SHARK_PATROL_LANE_Y;
    float laneOffsetY = (laneCenterY - agent.location.y) * CFG.SHARK_PATROL_LANE_PULL;
    float targetX = agent.location.x + steerX * CFG.SHARK_PATROL_LOOKAHEAD;
    float targetY = agent.location.y + steerY * CFG.SHARK_PATROL_LOOKAHEAD + laneOffsetY;

    agent.applySteerTo(targetX, targetY, false, 1);
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

    agent.getMouthPointLocalStable(agent.tmpMouthStable);
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
}
