#pragma once

#include "ofLog.h"

class HardwareController {
public:
  virtual ~HardwareController() = default;

  virtual void setMatrixLedCount(int count) = 0;
  virtual void triggerStripAnimation() = 0;
  virtual void update() = 0;
};

class SimulatedHardwareController final : public HardwareController {
public:
  void setMatrixLedCount(int count) override {
    if (count == matrixLedCount_) return;
    matrixLedCount_ = count;
    ofLogNotice("HardwareSim") << "I:" << matrixLedCount_;
  }

  void triggerStripAnimation() override {
    ofLogNotice("HardwareSim") << "1";
  }

  void update() override {}

private:
  int matrixLedCount_ = -1;
};

