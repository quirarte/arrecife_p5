#pragma once

#include <string>

struct AppConfig {
  int defaultCameraIndex = 0;
  int arduinoBaud = 9600;
  std::string arduinoCom;

  static AppConfig loadFromFile(const std::string& path);
};
