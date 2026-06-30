#include "AppConfig.h"

#include <opencv2/core.hpp>
#include <iostream>

AppConfig AppConfig::loadFromFile(const std::string& path) {
  AppConfig cfg;

  cv::FileStorage fs(path, cv::FileStorage::READ | cv::FileStorage::FORMAT_JSON);
  if (!fs.isOpened()) {
    std::cerr << "No se pudo abrir " << path << ". Se usan defaults." << std::endl;
    return cfg;
  }

  fs["default_cam_index"] >> cfg.defaultCameraIndex;
  fs["arduino_baud"] >> cfg.arduinoBaud;
  fs["strip_led_count"] >> cfg.stripLedCount;
  fs["strip_travel_step_ms"] >> cfg.stripTravelStepMs;
  fs["fish_spawn_height"] >> cfg.fishSpawnHeight;
  fs["arduino_com"] >> cfg.arduinoCom;

  return cfg;
}
