#include "AppConfig.h"
#include "HardwareController.h"
#include "RoiConfig.h"
#include "VisionPrototypeApp.h"

#include <iostream>
#include <memory>

int main() {
  try {
    AppConfig appConfig = AppConfig::loadFromFile("app_config.json");
    RoiConfig roiConfig = RoiConfig::loadFromFile("roi.json");

    auto hardware = std::make_unique<SimulatedHardwareController>();
    VisionPrototypeApp app(appConfig, roiConfig, std::move(hardware));
    return app.run();
  } catch (const std::exception& e) {
    std::cerr << "Error fatal: " << e.what() << std::endl;
    return 1;
  }
}
