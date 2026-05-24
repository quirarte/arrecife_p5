#include "AlphaSegmenter.h"

#include <opencv2/imgproc.hpp>
#include <queue>
#include <vector>

SegmentResult AlphaSegmenter::segment(const cv::Mat& frameBgr, const RoiConfig& roi) const {
  SegmentResult out;

  if (frameBgr.empty()) return out;

  cv::Mat roiMask(frameBgr.rows, frameBgr.cols, CV_8UC1, cv::Scalar(0));
  std::vector<cv::Point> quad;
  for (const cv::Point2f& p : roi.quad()) {
    quad.emplace_back(cvRound(p.x), cvRound(p.y));
  }
  cv::fillConvexPoly(roiMask, quad, cv::Scalar(255), cv::LINE_AA);

  cv::Mat whiteMask(frameBgr.rows, frameBgr.cols, CV_8UC1, cv::Scalar(0));
  for (int y = 0; y < frameBgr.rows; ++y) {
    const cv::Vec3b* src = frameBgr.ptr<cv::Vec3b>(y);
    const uchar* roiPtr = roiMask.ptr<uchar>(y);
    uchar* whitePtr = whiteMask.ptr<uchar>(y);
    for (int x = 0; x < frameBgr.cols; ++x) {
      if (!roiPtr[x]) continue;
      const cv::Vec3b pixel = src[x];
      if (pixel[0] >= roi.whiteThr && pixel[1] >= roi.whiteThr && pixel[2] >= roi.whiteThr) {
        whitePtr[x] = 255;
      }
    }
  }

  cv::Mat visited(frameBgr.rows, frameBgr.cols, CV_8UC1, cv::Scalar(0));
  cv::Mat alpha(frameBgr.rows, frameBgr.cols, CV_8UC1, cv::Scalar(0));
  alpha.setTo(255, roiMask);

  std::queue<cv::Point> queue;
  for (int y = 0; y < frameBgr.rows; ++y) {
    const uchar* roiPtr = roiMask.ptr<uchar>(y);
    const uchar* whitePtr = whiteMask.ptr<uchar>(y);
    uchar* visitPtr = visited.ptr<uchar>(y);

    for (int x = 0; x < frameBgr.cols; ++x) {
      if (!roiPtr[x] || !whitePtr[x] || visitPtr[x]) continue;

      const bool isBoundary =
        x == 0 || y == 0 || x == frameBgr.cols - 1 || y == frameBgr.rows - 1 ||
        roiMask.at<uchar>(std::max(0, y - 1), x) == 0 ||
        roiMask.at<uchar>(std::min(frameBgr.rows - 1, y + 1), x) == 0 ||
        roiMask.at<uchar>(y, std::max(0, x - 1)) == 0 ||
        roiMask.at<uchar>(y, std::min(frameBgr.cols - 1, x + 1)) == 0;

      if (!isBoundary) continue;

      visitPtr[x] = 255;
      queue.push({x, y});
    }
  }

  static const int kDx[4] = {-1, 1, 0, 0};
  static const int kDy[4] = {0, 0, -1, 1};

  while (!queue.empty()) {
    const cv::Point p = queue.front();
    queue.pop();
    alpha.at<uchar>(p.y, p.x) = 0;

    for (int i = 0; i < 4; ++i) {
      const int nx = p.x + kDx[i];
      const int ny = p.y + kDy[i];
      if (nx < 0 || ny < 0 || nx >= frameBgr.cols || ny >= frameBgr.rows) continue;
      if (!roiMask.at<uchar>(ny, nx)) continue;
      if (!whiteMask.at<uchar>(ny, nx)) continue;
      if (visited.at<uchar>(ny, nx)) continue;

      visited.at<uchar>(ny, nx) = 255;
      queue.push({nx, ny});
    }
  }

  cv::Mat bgra;
  cv::cvtColor(frameBgr, bgra, cv::COLOR_BGR2BGRA);
  std::vector<cv::Mat> channels;
  cv::split(bgra, channels);
  channels[3] = alpha;
  cv::merge(channels, out.rgbaPreview);

  out.alphaMask = alpha;
  return out;
}
