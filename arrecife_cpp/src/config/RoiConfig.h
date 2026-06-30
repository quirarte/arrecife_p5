#pragma once

#include "ofMain.h"

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
  glm::vec2 anchor = {320.0f, 120.0f};
  float rotationDeg = 0.0f;

  static RoiConfig loadFromFile(const std::string& path);
  bool saveToFile(const std::string& path) const;

  void clampToFrame(const glm::vec2& frameSize);
  void nudgeAnchor(float dx, float dy, const glm::vec2& frameSize);
  void nudgeExtent(int dx, int dy, const glm::vec2& frameSize);
  void nudgeThreshold(int delta);
  void nudgeMatrixLedCount(int delta);
  void nudgeRotation(float deltaDeg);

  std::vector<glm::vec2> quad() const;
};

