#pragma once

#include <opencv2/core.hpp>
#include <string>
#include <vector>

struct RoiConfig {
  static constexpr int MarkerTopLeft = 1;
  static constexpr int MarkerTopRight = 2;
  static constexpr int MarkerBottomRight = 3;
  static constexpr int MarkerBottomLeft = 4;
  static constexpr int MatrixLedCountMin = 1;
  static constexpr int MatrixLedCountMax = 64;

  int markerPlacement = MarkerTopLeft;
  int extentX = 384;
  int extentY = 336;
  int whiteThr = 225;
  int matrixLedCount = 2;
  cv::Point2f anchor = {320.0f, 120.0f};
  float rotationDeg = 0.0f;

  static RoiConfig loadFromFile(const std::string& path);
  bool saveToFile(const std::string& path) const;

  void clampToFrame(const cv::Size& frameSize);
  void nudgeAnchor(float dx, float dy, const cv::Size& frameSize);
  void nudgeExtent(int dx, int dy, const cv::Size& frameSize);
  void nudgeThreshold(int delta);
  void nudgeMatrixLedCount(int delta);
  void nudgeRotation(float deltaDeg);

  std::vector<cv::Point2f> quad() const;
};
