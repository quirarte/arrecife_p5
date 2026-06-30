#include "AppConfig.h"

#include "ofJson.h"
#include "ofLog.h"

AppConfig AppConfig::loadFromFile(const std::string& path) {
  AppConfig cfg;

  try {
    const ofJson json = ofLoadJson(path);
    if (json.contains("default_cam_index")) cfg.defaultCameraIndex = json["default_cam_index"].get<int>();
    if (json.contains("arduino_baud")) cfg.arduinoBaud = json["arduino_baud"].get<int>();
    if (json.contains("strip_led_count")) cfg.stripLedCount = json["strip_led_count"].get<int>();
    if (json.contains("strip_travel_step_ms")) cfg.stripTravelStepMs = json["strip_travel_step_ms"].get<int>();
    if (json.contains("fish_spawn_height")) cfg.fishSpawnHeight = json["fish_spawn_height"].get<int>();
    if (json.contains("arduino_com")) cfg.arduinoCom = json["arduino_com"].get<std::string>();
  } catch (const std::exception& e) {
    ofLogWarning("AppConfig") << "No se pudo cargar " << path << ": " << e.what() << ". Se usan defaults.";
  }

  return cfg;
}
