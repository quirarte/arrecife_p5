#pragma once

#include "AlphaSegmenter.h"
#include "AppConfig.h"
#include "HardwareController.h"
#include "RoiConfig.h"

#include <memory>
#include <string>

class VisionPrototypeApp {
public:
  VisionPrototypeApp(AppConfig appConfig, RoiConfig roiConfig, std::unique_ptr<HardwareController> hardware);
  int run();

private:
  void drawOverlay(cv::Mat& canvas, const SegmentResult& segment) const;
  bool handleKey(int key, const cv::Size& frameSize);
  void syncHardwareMatrixCount();

  AppConfig appConfig_;
  RoiConfig roiConfig_;
  std::unique_ptr<HardwareController> hardware_;
  AlphaSegmenter segmenter_;
  std::string roiPath_ = "roi.json";
};
