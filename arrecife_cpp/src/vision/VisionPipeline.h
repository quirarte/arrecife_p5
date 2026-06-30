#pragma once

#include "config/RoiConfig.h"

#include "ofMain.h"

class VisionPipeline {
public:
  void setup();
  void update(const ofPixels& pixels, const RoiConfig& roiConfig);
  bool hasFrame() const;

private:
  bool hasFrame_ = false;
};

