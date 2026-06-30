#include "ofApp.h"

#include "ofFileUtils.h"

#include <sstream>

namespace {
constexpr int kMoveStep = 4;
constexpr int kRotateStepDeg = 5;
constexpr int kExtentStep = 8;

std::string findRepoFile(const std::string& fileName) {
  const std::vector<std::string> candidates = {
    "../" + fileName,
    "../../" + fileName,
    "../../../" + fileName,
    "../../../../" + fileName,
    fileName,
  };

  for (const auto& candidate : candidates) {
    if (ofFile::doesFileExist(candidate)) {
      return candidate;
    }
  }

  return "../" + fileName;
}
}

void ofApp::setup() {
  ofSetWindowTitle("arrecife_cpp");
  ofSetFrameRate(60);
  ofBackground(0);

  loadConfigs();

  hardware_ = std::make_unique<SimulatedHardwareController>();
  visionPipeline_.setup();
  syncHardwareMatrixCount();

  camera_.setDeviceID(appConfig_.defaultCameraIndex);
  camera_.setDesiredFrameRate(30);
  cameraReady_ = camera_.setup(640, 480);

  if (cameraReady_) {
    statusMessage_ = "Camera OK";
    roiConfig_.clampToFrame({camera_.getWidth(), camera_.getHeight()});
  } else {
    statusMessage_ = "No se pudo abrir la webcam";
  }
}

void ofApp::update() {
  camera_.update();
  if (cameraReady_ && camera_.isFrameNew()) {
    visionPipeline_.update(camera_.getPixels(), roiConfig_);
  }
  if (hardware_) {
    hardware_->update();
  }
}

void ofApp::draw() {
  ofBackground(15);
  drawCamera();
  drawRoiOverlay();
  drawHud();
}

void ofApp::keyPressed(int key) {
  if (!cameraReady_) {
    return;
  }

  const glm::vec2 frameSize(camera_.getWidth(), camera_.getHeight());

  switch (key) {
    case ',':
      roiConfig_.nudgeThreshold(-1);
      break;
    case '.':
      roiConfig_.nudgeThreshold(+1);
      break;
    case 'j':
    case 'J':
      roiConfig_.nudgeMatrixLedCount(-1);
      syncHardwareMatrixCount();
      break;
    case 'k':
    case 'K':
      roiConfig_.nudgeMatrixLedCount(+1);
      syncHardwareMatrixCount();
      break;
    case '1':
      roiConfig_.markerPlacement = RoiConfig::MarkerTopLeft;
      break;
    case '2':
      roiConfig_.markerPlacement = RoiConfig::MarkerTopRight;
      break;
    case '3':
      roiConfig_.markerPlacement = RoiConfig::MarkerBottomRight;
      break;
    case '4':
      roiConfig_.markerPlacement = RoiConfig::MarkerBottomLeft;
      break;
    case 'q':
    case 'Q':
      roiConfig_.nudgeRotation(-kRotateStepDeg);
      break;
    case 'e':
    case 'E':
      roiConfig_.nudgeRotation(+kRotateStepDeg);
      break;
    case '[':
      roiConfig_.nudgeExtent(-kExtentStep, 0, frameSize);
      break;
    case ']':
      roiConfig_.nudgeExtent(+kExtentStep, 0, frameSize);
      break;
    case '-':
      roiConfig_.nudgeExtent(0, -kExtentStep, frameSize);
      break;
    case '=':
      roiConfig_.nudgeExtent(0, +kExtentStep, frameSize);
      break;
    case OF_KEY_LEFT:
      roiConfig_.nudgeAnchor(-kMoveStep, 0, frameSize);
      break;
    case OF_KEY_RIGHT:
      roiConfig_.nudgeAnchor(+kMoveStep, 0, frameSize);
      break;
    case OF_KEY_UP:
      roiConfig_.nudgeAnchor(0, -kMoveStep, frameSize);
      break;
    case OF_KEY_DOWN:
      roiConfig_.nudgeAnchor(0, +kMoveStep, frameSize);
      break;
    case 's':
    case 'S':
      if (roiConfig_.saveToFile(findRepoFile("roi.json"))) {
        statusMessage_ = "ROI guardado";
      } else {
        statusMessage_ = "Error guardando ROI";
      }
      break;
    case 'l':
    case 'L':
      roiConfig_ = RoiConfig::loadFromFile(findRepoFile("roi.json"));
      roiConfig_.clampToFrame(frameSize);
      syncHardwareMatrixCount();
      statusMessage_ = "ROI recargado";
      break;
    case ' ':
      if (hardware_) {
        hardware_->triggerStripAnimation();
        statusMessage_ = "Animacion de tira disparada";
      }
      break;
    default:
      break;
  }
}

void ofApp::drawCamera() {
  if (!cameraReady_) {
    ofSetColor(255, 80, 80);
    ofDrawBitmapString("No camera", 40, 40);
    return;
  }

  const float margin = 24.0f;
  const float targetW = ofGetWidth() - margin * 2.0f;
  const float targetH = ofGetHeight() - 160.0f;
  const float scale = std::min(targetW / camera_.getWidth(), targetH / camera_.getHeight());
  const float drawW = camera_.getWidth() * scale;
  const float drawH = camera_.getHeight() * scale;
  const float drawX = (ofGetWidth() - drawW) * 0.5f;
  const float drawY = 24.0f;

  ofSetColor(255);
  camera_.draw(drawX, drawY, drawW, drawH);
}

void ofApp::drawRoiOverlay() const {
  if (!cameraReady_) {
    return;
  }

  const float margin = 24.0f;
  const float targetW = ofGetWidth() - margin * 2.0f;
  const float targetH = ofGetHeight() - 160.0f;
  const float scale = std::min(targetW / camera_.getWidth(), targetH / camera_.getHeight());
  const float drawW = camera_.getWidth() * scale;
  const float drawH = camera_.getHeight() * scale;
  const float drawX = (ofGetWidth() - drawW) * 0.5f;
  const float drawY = 24.0f;

  const auto quad = roiConfig_.quad();

  ofPushStyle();
  ofNoFill();
  ofSetLineWidth(2.0f);
  ofSetColor(0, 255, 120);

  ofBeginShape();
  for (const auto& p : quad) {
    ofVertex(drawX + p.x * scale, drawY + p.y * scale);
  }
  ofEndShape(true);

  ofFill();
  ofSetColor(255, 220, 0);
  ofDrawCircle(drawX + roiConfig_.anchor.x * scale, drawY + roiConfig_.anchor.y * scale, 5.0f);
  ofPopStyle();
}

void ofApp::drawHud() const {
  ofPushStyle();
  ofSetColor(0, 0, 0, 190);
  ofDrawRectangle(0, ofGetHeight() - 120, ofGetWidth(), 120);

  ofSetColor(255);
  std::ostringstream line1;
  line1 << "status=" << statusMessage_
        << " camIndex=" << appConfig_.defaultCameraIndex
        << " thr=" << roiConfig_.whiteThr
        << " leds=" << roiConfig_.matrixLedCount
        << " placement=" << roiConfig_.markerPlacement
        << " rot=" << roiConfig_.rotationDeg;
  ofDrawBitmapString(line1.str(), 20, ofGetHeight() - 84);

  std::ostringstream line2;
  line2 << "anchor=(" << static_cast<int>(roiConfig_.anchor.x) << "," << static_cast<int>(roiConfig_.anchor.y)
        << ") extent=(" << roiConfig_.extentX << "," << roiConfig_.extentY << ")"
        << " arduino=" << appConfig_.arduinoCom << "@" << appConfig_.arduinoBaud;
  ofDrawBitmapString(line2.str(), 20, ofGetHeight() - 58);

  ofDrawBitmapString(",/. thr  j/k leds  1-4 corner  arrows move  q/e rot  [/]/-/= extents  s save  l load  space anim",
                     20, ofGetHeight() - 32);
  ofPopStyle();
}

bool ofApp::loadConfigs() {
  appConfig_ = AppConfig::loadFromFile(findRepoFile("app_config.json"));
  roiConfig_ = RoiConfig::loadFromFile(findRepoFile("roi.json"));
  return true;
}

void ofApp::syncHardwareMatrixCount() {
  if (hardware_) {
    hardware_->setMatrixLedCount(roiConfig_.matrixLedCount);
  }
}
