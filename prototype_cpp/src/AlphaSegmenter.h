#pragma once

#include "RoiConfig.h"

#include <opencv2/core.hpp>

struct SegmentResult {
  cv::Mat alphaMask;
  cv::Mat rgbaPreview;
};

class AlphaSegmenter {
public:
  SegmentResult segment(const cv::Mat& frameBgr, const RoiConfig& roi) const;
};
