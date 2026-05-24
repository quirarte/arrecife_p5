#include "RoiConfig.h"

#include <opencv2/core.hpp>
#include <algorithm>
#include <cmath>
#include <iostream>

namespace {
float clampFloat(float value, float low, float high) {
  return std::max(low, std::min(high, value));
}
}

RoiConfig RoiConfig::loadFromFile(const std::string& path) {
  RoiConfig cfg;

  cv::FileStorage fs(path, cv::FileStorage::READ | cv::FileStorage::FORMAT_JSON);
  if (!fs.isOpened()) {
    std::cerr << "No se pudo abrir " << path << ". Se usan defaults de ROI." << std::endl;
    return cfg;
  }

  fs["markerPlacement"] >> cfg.markerPlacement;
  fs["extentX"] >> cfg.extentX;
  fs["extentY"] >> cfg.extentY;
  fs["whiteThr"] >> cfg.whiteThr;
  fs["matrixLedCount"] >> cfg.matrixLedCount;

  if (!fs["anchorX"].empty()) fs["anchorX"] >> cfg.anchor.x;
  if (!fs["anchorY"].empty()) fs["anchorY"] >> cfg.anchor.y;
  if (!fs["rotationDeg"].empty()) fs["rotationDeg"] >> cfg.rotationDeg;

  return cfg;
}

bool RoiConfig::saveToFile(const std::string& path) const {
  cv::FileStorage fs(path, cv::FileStorage::WRITE | cv::FileStorage::FORMAT_JSON);
  if (!fs.isOpened()) {
    std::cerr << "No se pudo guardar " << path << std::endl;
    return false;
  }

  fs << "markerPlacement" << markerPlacement;
  fs << "extentX" << extentX;
  fs << "extentY" << extentY;
  fs << "whiteThr" << whiteThr;
  fs << "matrixLedCount" << matrixLedCount;
  fs << "anchorX" << anchor.x;
  fs << "anchorY" << anchor.y;
  fs << "rotationDeg" << rotationDeg;

  return true;
}

void RoiConfig::clampToFrame(const cv::Size& frameSize) {
  extentX = std::clamp(extentX, 10, std::max(10, frameSize.width));
  extentY = std::clamp(extentY, 10, std::max(10, frameSize.height));
  whiteThr = std::clamp(whiteThr, 0, 255);
  matrixLedCount = std::clamp(matrixLedCount, MatrixLedCountMin, MatrixLedCountMax);
  anchor.x = clampFloat(anchor.x, 0.0f, static_cast<float>(std::max(0, frameSize.width - 1)));
  anchor.y = clampFloat(anchor.y, 0.0f, static_cast<float>(std::max(0, frameSize.height - 1)));
}

void RoiConfig::nudgeAnchor(float dx, float dy, const cv::Size& frameSize) {
  anchor.x += dx;
  anchor.y += dy;
  clampToFrame(frameSize);
}

void RoiConfig::nudgeExtent(int dx, int dy, const cv::Size& frameSize) {
  extentX += dx;
  extentY += dy;
  clampToFrame(frameSize);
}

void RoiConfig::nudgeThreshold(int delta) {
  whiteThr = std::clamp(whiteThr + delta, 0, 255);
}

void RoiConfig::nudgeMatrixLedCount(int delta) {
  matrixLedCount = std::clamp(matrixLedCount + delta, MatrixLedCountMin, MatrixLedCountMax);
}

void RoiConfig::nudgeRotation(float deltaDeg) {
  rotationDeg += deltaDeg;
  while (rotationDeg <= -180.0f) rotationDeg += 360.0f;
  while (rotationDeg > 180.0f) rotationDeg -= 360.0f;
}

std::vector<cv::Point2f> RoiConfig::quad() const {
  const float rad = rotationDeg * static_cast<float>(CV_PI / 180.0);
  const cv::Point2f u(std::cos(rad), std::sin(rad));
  const cv::Point2f v(-std::sin(rad), std::cos(rad));

  int growXSign = (markerPlacement == MarkerBottomLeft) ? 1 : -1;
  int growYSign = (markerPlacement == MarkerBottomRight || markerPlacement == MarkerBottomLeft) ? -1 : 1;

  const cv::Point2f dx = u * static_cast<float>(growXSign * extentX);
  const cv::Point2f dy = v * static_cast<float>(growYSign * extentY);

  std::vector<cv::Point2f> q(4);
  q[0] = anchor;
  q[1] = anchor + dx;
  q[2] = q[1] + dy;
  q[3] = anchor + dy;
  return q;
}
