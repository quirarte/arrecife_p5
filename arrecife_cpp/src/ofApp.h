#pragma once

#include "config/AppConfig.h"
#include "config/RoiConfig.h"
#include "hardware/HardwareController.h"
#include "vision/VisionPipeline.h"

#include "ofMain.h"

#include <memory>

class ofApp : public ofBaseApp {
public:
  void setup() override;
  void update() override;
  void draw() override;
  void keyPressed(int key) override;

private:
  void drawCamera();
  void drawRoiOverlay() const;
  void drawHud() const;
  bool loadConfigs();
  void syncHardwareMatrixCount();

  AppConfig appConfig_;
  RoiConfig roiConfig_;
  std::unique_ptr<HardwareController> hardware_;
  VisionPipeline visionPipeline_;

  ofVideoGrabber camera_;
  bool cameraReady_ = false;
  std::string statusMessage_ = "Booting";
};

