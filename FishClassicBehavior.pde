class FishClassicBehavior extends SpeciesBehavior {

  float wandertheta;

  FishClassicBehavior() {
    wandertheta = random(TWO_PI);
  }

  void updateMovement(AnimalAgent agent, ArrayList<FoodPellet> foods) {
    boolean chasing = seekClosestFood(agent, foods);
    if (!chasing) wander(agent);
  }

  void wander(AnimalAgent agent) {
    agent.resetToCruise();

    float wanderR = CFG.WANDER_R;
    float wanderD = CFG.WANDER_D;
    float change  = CFG.WANDER_CHANGE;

    wandertheta += random(-change, change);

    float vx = agent.velocity.x;
    float vy = agent.velocity.y;
    float v2 = vx*vx + vy*vy;
    if (v2 < 0.0001) {
      vx = 1;
      vy = 0;
      v2 = 1;
    }
    float invV = 1.0 / sqrt(v2);
    vx *= invV;
    vy *= invV;

    float circleX = agent.location.x + vx * wanderD;
    float circleY = agent.location.y + vy * wanderD;

    float offX = wanderR * cos(wandertheta);
    float offY = wanderR * sin(wandertheta);

    agent.applySteerTo(circleX + offX, circleY + offY, false, 1);
  }

  boolean seekClosestFood(AnimalAgent agent, ArrayList<FoodPellet> foods) {
    agent.resetToCruise();

    if (foods == null || foods.isEmpty()) {
      clearFoodLock(agent);
      return false;
    }

    FoodPellet best = pickFoodTarget(agent, foods);
    if (best == null) {
      clearFoodLock(agent);
      return false;
    }

    agent.maxSpeed = agent.baseMaxSpeed * CFG.FOOD_SPEED_MULT_DEFAULT;
    agent.maxForce = agent.baseMaxForce;

    agent.getMouthPointLocalStable(agent.tmpMouthStable);
    float targetX = best.pos.x - agent.tmpMouthStable.x;
    float targetY = best.pos.y - agent.tmpMouthStable.y;

    float dx = targetX - agent.location.x;
    float dy = targetY - agent.location.y;
    float d2 = dx*dx + dy*dy;
    float d  = sqrt(max(0.000001, d2));

    if (d < CFG.NEAR_FOOD_RADIUS) {
      float invD = 1.0 / d;
      float dirX = dx * invD;
      float dirY = dy * invD;

      float vAlong = agent.velocity.x * dirX + agent.velocity.y * dirY;
      float minAlong = agent.maxSpeed * CFG.NEAR_MIN_ALONG;
      float newAlong = max(vAlong, minAlong);

      agent.velocity.x = dirX * newAlong;
      agent.velocity.y = dirY * newAlong;

      agent.velocity.mult(CFG.NEAR_DAMPING);

      agent.applySteerTo(targetX, targetY, false, 1);
      return true;
    }

    agent.applySteerTo(targetX, targetY, true, CFG.ARRIVE_FAR_SLOW_RADIUS);
    return true;
  }

  FoodPellet pickFoodTarget(AnimalAgent agent, ArrayList<FoodPellet> foods) {
    if (agent.lockedFood != null && agent.lockedFoodFrames < CFG.LOCK_FRAMES) {
      boolean stillThere = false;
      for (int i = 0; i < foods.size(); i++) {
        if (foods.get(i) == agent.lockedFood) {
          stillThere = true;
          break;
        }
      }
      if (stillThere && agent.lockedFood.speciesId == agent.speciesId) {
        agent.lockedFoodFrames++;
        return agent.lockedFood;
      } else {
        clearFoodLock(agent);
      }
    }

    FoodPellet best = null;
    float bestScore = 1e18;

    for (int i = 0; i < foods.size(); i++) {
      FoodPellet p = foods.get(i);
      if (p.speciesId != agent.speciesId) continue;

      float dx = p.pos.x - agent.location.x;
      float dy = p.pos.y - agent.location.y;
      float d2 = dx*dx + dy*dy;

      float down = max(0, dy);
      float up   = max(0, -dy);

      float score = d2 - (down*down) * CFG.FOOD_SCORE_DOWN_WEIGHT + (up*up) * CFG.FOOD_SCORE_UP_WEIGHT;

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

  void tryEat(AnimalAgent agent, ArrayList<FoodPellet> foods) {
    if (foods == null || foods.isEmpty()) return;

    agent.getMouthPointLocalStable(agent.tmpMouthStable);
    float mx = agent.location.x + agent.tmpMouthStable.x;
    float my = agent.location.y + agent.tmpMouthStable.y;

    float biteR = max(CFG.BITE_R_MIN, min(CFG.BITE_R_MAX, agent.renderH * CFG.BITE_R_SCALE));

    for (int i = foods.size() - 1; i >= 0; i--) {
      FoodPellet p = foods.get(i);
      if (p.speciesId != agent.speciesId) continue;

      float dx = mx - p.pos.x;
      float dy = my - p.pos.y;
      float rr = biteR + p.r;

      if (dx*dx + dy*dy <= rr*rr) {
        foods.remove(i);
      }
    }
  }
}
