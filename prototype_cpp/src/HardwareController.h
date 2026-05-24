#pragma once

#include <iostream>

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
    std::cout << "[hw-sim] I:" << matrixLedCount_ << std::endl;
  }

  void triggerStripAnimation() override {
    std::cout << "[hw-sim] 1" << std::endl;
  }

  void update() override {}

private:
  int matrixLedCount_ = -1;
};
