#include "RoiConfig.h"

#include "ofJson.h"
#include "ofLog.h"

#include <algorithm>
#include <cmath>

namespace {
float clampFloat(float value, float low, float high) {
  return std::max(low, std::min(high, value));
}
}

RoiConfig RoiConfig::loadFromFile(const std::string& path) {
  RoiConfig cfg;

  try {
    const ofJson json = ofLoadJson(path);
    if (json.contains("markerPlacement")) cfg.markerPlacement = json["markerPlacement"].get<int>();
    if (json.contains("extentX")) cfg.extentX = json["extentX"].get<int>();
    if (json.contains("extentY")) cfg.extentY = json["extentY"].get<int>();
    if (json.contains("whiteThr")) cfg.whiteThr = json["whiteThr"].get<int>();
    if (json.contains("matrixLedCount")) cfg.matrixLedCount = json["matrixLedCount"].get<int>();
    if (json.contains("anchorX")) cfg.anchor.x = json["anchorX"].get<float>();
    if (json.contains("anchorY")) cfg.anchor.y = json["anchorY"].get<float>();
    if (json.contains("rotationDeg")) cfg.rotationDeg = json["rotationDeg"].get<float>();
  } catch (const std::exception& e) {
    ofLogWarning("RoiConfig") << "No se pudo cargar " << path << ": " << e.what() << ". Se usan defaults.";
  }

  return cfg;
}

bool RoiConfig::saveToFile(const std::string& path) const {
  try {
    ofJson json;
    json["markerPlacement"] = markerPlacement;
    json["extentX"] = extentX;
    json["extentY"] = extentY;
    json["whiteThr"] = whiteThr;
    json["matrixLedCount"] = matrixLedCount;
    json["anchorX"] = anchor.x;
    json["anchorY"] = anchor.y;
    json["rotationDeg"] = rotationDeg;
    return ofSavePrettyJson(path, json);
  } catch (const std::exception& e) {
    ofLogError("RoiConfig") << "No se pudo guardar " << path << ": " << e.what();
    return false;
  }
}

void RoiConfig::clampToFrame(const glm::vec2& frameSize) {
  extentX = std::clamp(extentX, 10, std::max(10, static_cast<int>(frameSize.x)));
  extentY = std::clamp(extentY, 10, std::max(10, static_cast<int>(frameSize.y)));
  whiteThr = std::clamp(whiteThr, 0, 255);
  matrixLedCount = std::clamp(matrixLedCount, MatrixLedCountMin, MatrixLedCountMax);
  anchor.x = clampFloat(anchor.x, 0.0f, std::max(0.0f, frameSize.x - 1.0f));
  anchor.y = clampFloat(anchor.y, 0.0f, std::max(0.0f, frameSize.y - 1.0f));
}

void RoiConfig::nudgeAnchor(float dx, float dy, const glm::vec2& frameSize) {
  anchor.x += dx;
  anchor.y += dy;
  clampToFrame(frameSize);
}

void RoiConfig::nudgeExtent(int dx, int dy, const glm::vec2& frameSize) {
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

std::vector<glm::vec2> RoiConfig::quad() const {
  const float rad = ofDegToRad(rotationDeg);
  const glm::vec2 u(std::cos(rad), std::sin(rad));
  const glm::vec2 v(-std::sin(rad), std::cos(rad));

  const int growXSign = (markerPlacement == MarkerBottomLeft) ? 1 : -1;
  const int growYSign = (markerPlacement == MarkerBottomRight || markerPlacement == MarkerBottomLeft) ? -1 : 1;

  const glm::vec2 dx = u * static_cast<float>(growXSign * extentX);
  const glm::vec2 dy = v * static_cast<float>(growYSign * extentY);

  std::vector<glm::vec2> q(4);
  q[0] = anchor;
  q[1] = anchor + dx;
  q[2] = q[1] + dy;
  q[3] = anchor + dy;
  return q;
}

