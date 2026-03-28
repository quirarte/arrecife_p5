import java.awt.image.BufferedImage;

import boofcv.io.image.ConvertBufferedImage;
import boofcv.struct.image.GrayU8;

import boofcv.abst.fiducial.FiducialDetector;
import boofcv.factory.fiducial.FactoryFiducial;
import boofcv.factory.fiducial.ConfigFiducialBinary;

import georegression.struct.shapes.Polygon2D_F64;
import georegression.struct.point.Point2D_F64;

class FiducialHit {
  boolean found = false;
  int id = -1;
  float rawAngleDeg = 0;
  float snappedAngleDeg = 0;
  float[] corners = null; // x0,y0,x1,y1,x2,y2,x3,y3 (orden del detector)
}

class BoofSquareBinaryManager {

  final FiducialDetector<GrayU8> detector;
  final int idMin;
  final int idMax;
  final float rotStepDeg;
  final boolean debug;

  BoofSquareBinaryManager(double markerSizeWorldUnits, int idMin, int idMax, float rotStepDeg, boolean debug) {
    this.idMin = idMin;
    this.idMax = idMax;
    this.rotStepDeg = rotStepDeg;
    this.debug = debug;

    ConfigFiducialBinary cfg = new ConfigFiducialBinary(markerSizeWorldUnits);

    // Threshold null, usa default interno
    detector = FactoryFiducial.squareBinary(cfg, null, GrayU8.class);
  }

  FiducialHit detect(PImage img) {
    FiducialHit out = new FiducialHit();
    if (img == null) return out;

    GrayU8 gray = pimageToGrayU8(img);
    if (gray == null) return out;

    detector.detect(gray);

    int n = detector.totalFound();
    if (n <= 0) return out;

    // Si hay varios, elige el de mayor área aparente
    int best = -1;
    double bestArea = -1;

    Polygon2D_F64 poly = new Polygon2D_F64(4);

    for (int i = 0; i < n; i++) {
      detector.getBounds(i, poly);
      double area = polygonAreaAbs(poly);
      if (area > bestArea) {
        bestArea = area;
        best = i;
      }
    }

    if (best < 0) return out;

    int bestId = (int)detector.getId(best);

    boolean outOfLowerRange = (bestId < idMin);
    boolean hasUpperBound = (idMax >= idMin);
    boolean outOfUpperRange = hasUpperBound && (bestId > idMax);

    if (outOfLowerRange || outOfUpperRange) {
      if (debug) {
        if (hasUpperBound) {
          println("FIDUCIAL: encontrado id=" + bestId + " fuera de rango " + idMin + ".." + idMax + ", ignorando");
        } else {
          println("FIDUCIAL: encontrado id=" + bestId + " fuera de rango (mínimo " + idMin + "), ignorando");
        }
      }
      return out;
    }

    detector.getBounds(best, poly);

    // Ángulo base usando borde 0->1 (orden consistente del detector)
    Point2D_F64 p0 = poly.get(0);
    Point2D_F64 p1 = poly.get(1);

    float raw = degrees(atan2((float)(p1.y - p0.y), (float)(p1.x - p0.x)));
    raw = normalizeAngle180(raw);

    float snapped = snapAngle(raw, rotStepDeg);
    snapped = normalizeAngle180(snapped);

    out.found = true;
    out.id = bestId;
    out.rawAngleDeg = raw;
    out.snappedAngleDeg = snapped;
    out.corners = new float[8];
    for (int i = 0; i < 4; i++) {
      Point2D_F64 cp = poly.get(i);
      out.corners[i * 2] = (float)cp.x;
      out.corners[i * 2 + 1] = (float)cp.y;
    }

    return out;
  }

  GrayU8 pimageToGrayU8(PImage img) {
    img.loadPixels();
    if (img.pixels == null) return null;

    int w = img.width;
    int h = img.height;

    BufferedImage b = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);

    int[] rgb = new int[w*h];
    for (int i = 0; i < rgb.length; i++) {
      rgb[i] = img.pixels[i] & 0x00FFFFFF;
    }
    b.setRGB(0, 0, w, h, rgb, 0, w);

    return ConvertBufferedImage.convertFromSingle(b, null, GrayU8.class);
  }

  double polygonAreaAbs(Polygon2D_F64 poly) {
    int N = poly.size();
    if (N < 3) return 0;

    double sum = 0;
    for (int i = 0; i < N; i++) {
      Point2D_F64 a = poly.get(i);
      Point2D_F64 b = poly.get((i + 1) % N);
      sum += a.x * b.y - b.x * a.y;
    }
    return Math.abs(sum) * 0.5;
  }

  float snapAngle(float angleDeg, float stepDeg) {
    if (stepDeg <= 0.0001) return angleDeg;
    return round(angleDeg / stepDeg) * stepDeg;
  }

  float normalizeAngle180(float a) {
    while (a <= -180) a += 360;
    while (a > 180) a -= 360;
    return a;
  }
}

// Rotación simple sin perspectiva, mantiene tamaño, recorta lo que se salga
PImage rotatePImageKeepSize(PImage src, float angleDeg) {
  if (src == null) return null;

  int w = src.width;
  int h = src.height;

  PGraphics pg = createGraphics(w, h, P2D);
  pg.beginDraw();
  pg.clear();
  pg.imageMode(CENTER);
  pg.translate(w * 0.5, h * 0.5);
  pg.rotate(radians(angleDeg));
  pg.image(src, 0, 0);
  pg.endDraw();

  return pg.get();
}

PImage flipPImageVerticallyKeepSize(PImage src) {
  if (src == null) return null;

  int w = src.width;
  int h = src.height;

  PGraphics pg = createGraphics(w, h, P2D);
  pg.beginDraw();
  pg.clear();
  pg.imageMode(CENTER);
  pg.translate(w * 0.5, h * 0.5);
  pg.scale(1, -1);
  pg.image(src, 0, 0);
  pg.endDraw();

  return pg.get();
}
