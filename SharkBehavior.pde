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
      if (p.speciesId != agent.foodSpeciesId) continue;

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

    float sideMargin = width * CFG.SHARK_PATROL_SIDE_MARGIN;
    float minX = sideMargin;
    float maxX = width - sideMargin;
    float turnZone = width * CFG.SHARK_TURN_TRIGGER_MARGIN;

    if (!agent.turningAround) {
      if (agent.velocity.x > 0 && agent.location.x >= maxX - turnZone) {
        agent.beginTurnAround(-1, agent.maxSpeed * CFG.SHARK_CRUISE_SPEED_MULT);
      } else if (agent.velocity.x < 0 && agent.location.x <= minX + turnZone) {
        agent.beginTurnAround(1, agent.maxSpeed * CFG.SHARK_CRUISE_SPEED_MULT);
      }
    }

    if (agent.turningAround) {
      agent.acceleration.set(0, 0);
      return;
    }

    float wanderR = CFG.WANDER_R * 0.55;
    float wanderD = CFG.WANDER_D * 2.35;
    float change = CFG.WANDER_CHANGE * 0.45;

    patrolTheta += random(-change, change);

    float vx = agent.velocity.x;
    float vy = agent.velocity.y;
    float v2 = vx*vx + vy*vy;
    if (v2 < 0.0001) {
      vx = (agent.location.x < width * 0.5) ? 1 : -1;
      vy = 0;
      v2 = 1;
    }

    float invV = 1.0 / sqrt(v2);
    vx *= invV;
    vy *= invV;

    float laneCenterY = height * CFG.SHARK_PATROL_LANE_Y;
    float laneHalfHeight = height * CFG.SHARK_PATROL_BAND_HEIGHT;
    float minY = max(CFG.BORDER_PAD, laneCenterY - laneHalfHeight);
    float maxY = min(height - CFG.BORDER_PAD, laneCenterY + laneHalfHeight);


    float circleX = agent.location.x + vx * wanderD;
    float circleY = agent.location.y + vy * wanderD;

    float offX = wanderR * cos(patrolTheta) * wanderD;
    float offY = wanderR * sin(patrolTheta) * wanderD * 0.45;

    float targetX = constrain(circleX + offX, minX, maxX);
    float targetY = constrain(circleY + offY, minY, maxY);

    float centerPull = (laneCenterY - agent.location.y) * 0.08;
    targetY = constrain(targetY + centerPull, minY, maxY);

    if (agent.location.x <= minX + 8) targetX = max(targetX, agent.location.x + wanderD);
    if (agent.location.x >= maxX - 8) targetX = min(targetX, agent.location.x - wanderD);

    agent.applySteerTo(targetX, targetY, false, 1);

    float minForward = agent.maxSpeed * CFG.SHARK_PATROL_FORWARD_MIN;
    if (abs(agent.velocity.x) < minForward) {
      float dirX = (agent.velocity.x >= 0) ? 1 : -1;
      if (abs(agent.velocity.x) < 0.0001) dirX = (agent.location.x < width * 0.5) ? 1 : -1;
      agent.velocity.x = dirX * minForward;
    }

    agent.velocity.y = constrain(agent.velocity.y, -agent.maxSpeed * 0.35, agent.maxSpeed * 0.35);
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

    float dx = targetX - agent.location.x;
    float dy = targetY - agent.location.y;
    float d = sqrt(max(0.000001, dx*dx + dy*dy));

    if (d < CFG.NEAR_FOOD_RADIUS * 1.35) {
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

    agent.applySteerTo(targetX, targetY, true, CFG.ARRIVE_FAR_SLOW_RADIUS * 0.9);
    return true;
  }

  FoodPellet pickFoodTarget(AnimalAgent agent, ArrayList<FoodPellet> foods) {
    if (agent.lockedFood != null && agent.lockedFoodFrames < CFG.LOCK_FRAMES * 2) {
      for (int i = 0; i < foods.size(); i++) {
        FoodPellet p = foods.get(i);
        if (p == agent.lockedFood && p.speciesId == agent.foodSpeciesId) {
          agent.lockedFoodFrames++;
          return p;
        }
      }
      clearFoodLock(agent);
    }

    FoodPellet best = null;
    float bestScore = 1e18;

    float laneCenterY = height * CFG.SHARK_PATROL_LANE_Y;

    for (int i = 0; i < foods.size(); i++) {
      FoodPellet p = foods.get(i);
      if (p.speciesId != agent.foodSpeciesId) continue;

      float dx = p.pos.x - agent.location.x;
      float dy = p.pos.y - agent.location.y;
      float d2 = dx*dx + dy*dy;
      float laneBias = abs(p.pos.y - laneCenterY) * CFG.SHARK_FOOD_VERTICAL_WEIGHT;
      float turnBias = max(0, -dx * signNonZero(agent.velocity.x)) * CFG.SHARK_FOOD_HEADING_WEIGHT;
      float score = d2 + laneBias + turnBias;

      if (score < bestScore) {
        bestScore = score;
        best = p;
      }
    }

    agent.lockedFood = best;
    agent.lockedFoodFrames = 0;
    return best;
  }

  float signNonZero(float value) {
    return (value >= 0) ? 1 : -1;
  }

  void clearFoodLock(AnimalAgent agent) {
    agent.lockedFood = null;
    agent.lockedFoodFrames = 0;
  }
}
