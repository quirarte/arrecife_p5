#include "VisionPipeline.h"

void VisionPipeline::setup() {
  hasFrame_ = false;
}

void VisionPipeline::update(const ofPixels& pixels, const RoiConfig& roiConfig) {
  (void)roiConfig;
  hasFrame_ = !pixels.isAllocated() ? false : (pixels.getWidth() > 0 && pixels.getHeight() > 0);
}

bool VisionPipeline::hasFrame() const {
  return hasFrame_;
}
