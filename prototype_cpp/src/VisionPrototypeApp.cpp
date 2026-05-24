#include "VisionPrototypeApp.h"

#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>
#include <iostream>
#include <sstream>

namespace {
constexpr int kMoveStep = 4;
constexpr int kRotateStepDeg = 5;
constexpr int kExtentStep = 8;
const char* kWindowName = "Arrecife C++ Prototype";

void drawTextLine(cv::Mat& canvas, const std::string& text, cv::Point origin, double scale = 0.45) {
  cv::putText(canvas, text, origin, cv::FONT_HERSHEY_SIMPLEX, scale, cv::Scalar(255, 255, 255), 1, cv::LINE_AA);
}
}

VisionPrototypeApp::VisionPrototypeApp(AppConfig appConfig, RoiConfig roiConfig, std::unique_ptr<HardwareController> hardware)
  : appConfig_(std::move(appConfig)),
    roiConfig_(std::move(roiConfig)),
    hardware_(std::move(hardware)) {}

int VisionPrototypeApp::run() {
  cv::VideoCapture cap(appConfig_.defaultCameraIndex, cv::CAP_ANY);
  if (!cap.isOpened()) {
    std::cerr << "No se pudo abrir la webcam index=" << appConfig_.defaultCameraIndex << std::endl;
    return 1;
  }

  cap.set(cv::CAP_PROP_FRAME_WIDTH, 640);
  cap.set(cv::CAP_PROP_FRAME_HEIGHT, 480);

  cv::namedWindow(kWindowName, cv::WINDOW_AUTOSIZE);

  cv::Mat frame;
  bool initialized = false;

  while (true) {
    if (!cap.read(frame) || frame.empty()) {
      std::cerr << "No se pudo leer frame de la webcam." << std::endl;
      return 1;
    }

    if (!initialized) {
      roiConfig_.clampToFrame(frame.size());
      syncHardwareMatrixCount();
      initialized = true;
    }

    const SegmentResult segment = segmenter_.segment(frame, roiConfig_);

    cv::Mat canvas;
    frame.copyTo(canvas);
    drawOverlay(canvas, segment);

    cv::imshow(kWindowName, canvas);

    hardware_->update();

    const int key = cv::waitKeyEx(10);
    if (key >= 0 && !handleKey(key, frame.size())) {
      break;
    }
  }

  return 0;
}

void VisionPrototypeApp::drawOverlay(cv::Mat& canvas, const SegmentResult& segment) const {
  const std::vector<cv::Point2f> q = roiConfig_.quad();
  std::vector<cv::Point> qi;
  for (const cv::Point2f& p : q) qi.emplace_back(cvRound(p.x), cvRound(p.y));
  cv::polylines(canvas, qi, true, cv::Scalar(0, 255, 0), 2, cv::LINE_AA);
  cv::circle(canvas, cv::Point(cvRound(roiConfig_.anchor.x), cvRound(roiConfig_.anchor.y)), 4, cv::Scalar(0, 255, 255), cv::FILLED, cv::LINE_AA);

  if (!segment.alphaMask.empty()) {
    cv::Mat alphaBgr;
    cv::cvtColor(segment.alphaMask, alphaBgr, cv::COLOR_GRAY2BGR);
    cv::resize(alphaBgr, alphaBgr, cv::Size(200, 150), 0, 0, cv::INTER_NEAREST);
    alphaBgr.copyTo(canvas(cv::Rect(10, 10, alphaBgr.cols, alphaBgr.rows)));

    cv::Mat cutout;
    canvas.copyTo(cutout);
    cv::bitwise_and(cutout, cutout, cutout, segment.alphaMask);
    cv::resize(cutout, cutout, cv::Size(200, 150));
    cutout.copyTo(canvas(cv::Rect(220, 10, cutout.cols, cutout.rows)));
  }

  cv::rectangle(canvas, cv::Rect(0, canvas.rows - 92, canvas.cols, 92), cv::Scalar(0, 0, 0), cv::FILLED);

  std::ostringstream line1;
  line1 << "thr=" << roiConfig_.whiteThr
        << " leds=" << roiConfig_.matrixLedCount
        << " placement=" << roiConfig_.markerPlacement
        << " rot=" << roiConfig_.rotationDeg;
  drawTextLine(canvas, line1.str(), {12, canvas.rows - 62});

  std::ostringstream line2;
  line2 << "anchor=(" << static_cast<int>(roiConfig_.anchor.x) << "," << static_cast<int>(roiConfig_.anchor.y)
        << ") extent=(" << roiConfig_.extentX << "," << roiConfig_.extentY << ")";
  drawTextLine(canvas, line2.str(), {12, canvas.rows - 40});

  drawTextLine(canvas, ",/. thr  j/k leds  1-4 corner  arrows move  q/e rot  [/]/-/= extents  s save  l load  space anim  esc exit",
               {12, canvas.rows - 18}, 0.4);
}

bool VisionPrototypeApp::handleKey(int key, const cv::Size& frameSize) {
  switch (key) {
    case 27:
      return false;
    case ',':
      roiConfig_.nudgeThreshold(-1);
      return true;
    case '.':
      roiConfig_.nudgeThreshold(+1);
      return true;
    case 'j':
    case 'J':
      roiConfig_.nudgeMatrixLedCount(-1);
      syncHardwareMatrixCount();
      return true;
    case 'k':
    case 'K':
      roiConfig_.nudgeMatrixLedCount(+1);
      syncHardwareMatrixCount();
      return true;
    case '1':
      roiConfig_.markerPlacement = RoiConfig::MarkerTopLeft;
      return true;
    case '2':
      roiConfig_.markerPlacement = RoiConfig::MarkerTopRight;
      return true;
    case '3':
      roiConfig_.markerPlacement = RoiConfig::MarkerBottomRight;
      return true;
    case '4':
      roiConfig_.markerPlacement = RoiConfig::MarkerBottomLeft;
      return true;
    case 's':
    case 'S':
      roiConfig_.saveToFile(roiPath_);
      std::cout << "ROI guardado en " << roiPath_ << std::endl;
      return true;
    case 'l':
    case 'L':
      roiConfig_ = RoiConfig::loadFromFile(roiPath_);
      roiConfig_.clampToFrame(frameSize);
      syncHardwareMatrixCount();
      std::cout << "ROI recargado desde " << roiPath_ << std::endl;
      return true;
    case 'q':
    case 'Q':
      roiConfig_.nudgeRotation(-kRotateStepDeg);
      return true;
    case 'e':
    case 'E':
      roiConfig_.nudgeRotation(+kRotateStepDeg);
      return true;
    case '[':
      roiConfig_.nudgeExtent(-kExtentStep, 0, frameSize);
      return true;
    case ']':
      roiConfig_.nudgeExtent(+kExtentStep, 0, frameSize);
      return true;
    case '-':
      roiConfig_.nudgeExtent(0, -kExtentStep, frameSize);
      return true;
    case '=':
      roiConfig_.nudgeExtent(0, +kExtentStep, frameSize);
      return true;
    case ' ':
      hardware_->triggerStripAnimation();
      return true;
    case 2424832:
      roiConfig_.nudgeAnchor(-kMoveStep, 0, frameSize);
      return true;
    case 2490368:
      roiConfig_.nudgeAnchor(0, -kMoveStep, frameSize);
      return true;
    case 2555904:
      roiConfig_.nudgeAnchor(+kMoveStep, 0, frameSize);
      return true;
    case 2621440:
      roiConfig_.nudgeAnchor(0, +kMoveStep, frameSize);
      return true;
    default:
      return true;
  }
}

void VisionPrototypeApp::syncHardwareMatrixCount() {
  if (hardware_) hardware_->setMatrixLedCount(roiConfig_.matrixLedCount);
}
