#pragma once

#include <string>

struct AppConfig {
  int defaultCameraIndex = 0;
  int arduinoBaud = 9600;
  int stripLedCount = 60;
  int stripTravelStepMs = 24;
  int fishSpawnHeight = 280;
  std::string arduinoCom;

  static AppConfig loadFromFile(const std::string& path);
};
