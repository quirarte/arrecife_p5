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
  fs["arduino_com"] >> cfg.arduinoCom;

  return cfg;
}
