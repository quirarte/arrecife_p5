class Config {

  // Canvas
  final int CANVAS_W = 1280;
  final int CANVAS_H = 720;

  // Cámara buffer
  final int CAM_BUFFER_W = 640;
  final int CAM_BUFFER_H = 480;

  // Grid spawn
  final int GRID_COLS = 5;
  final int GRID_ROWS = 5;

  // Render pez
  final double BASE_ASPECT = 640.0 / 480.0;
  final int MIN_FISH_H = 40;
  final int MAX_FISH_H = 900;

  // Previews
  final int PREVIEW_W = 240;
  final int PREVIEW_H = 180;


  // Teclas comida
  final char[] FOOD_KEYS = { 'z', 'x', 'v', 'b', 'n' };
  final int MAX_SPECIES_KEYS = 5;

  // Spawn comida
  final int FOOD_COUNT_MIN = 25;
  final int FOOD_COUNT_JITTER = 15;
  final float FOOD_SPREAD_SEGMENT = 0.08;
  final float FOOD_STAGGER_Y = 200;
  // Límite de pellets por especie
  final int FOOD_MAX_PER_SPECIES = 150;


  final float FOOD_R_MIN = 5;
  final float FOOD_R_MAX = 16;

  final float FOOD_FALL_FAST = 1.35;
  final float FOOD_FALL_SLOW = 0.75;
  final float FOOD_FALL_JITTER = 0.08;

  // FishAgent tuning
  final float BORDER_PAD = 20;

  final float FOOD_SPEED_MULT_DEFAULT = 1.8;

  final int LOCK_FRAMES = 18;

  final float NEAR_FOOD_RADIUS = 260;
  final float NEAR_MIN_ALONG = 0.75;
  final float NEAR_DAMPING = 0.97;

  final float ARRIVE_FAR_SLOW_RADIUS = 120;
  final float FOOD_SCORE_DOWN_WEIGHT = 2.0;
  final float FOOD_SCORE_UP_WEIGHT = 4.0;

  final float BITE_R_SCALE = 0.08;
  final float BITE_R_MIN = 10;
  final float BITE_R_MAX = 45;

  final float MUSCLE_FREQ_MIN = 0.045;
  final float MUSCLE_FREQ_MAX = 0.085;
  final float MUSCLE_FREQ_LERP = 0.25;

  final float WANDER_R = 0.4;
  final float WANDER_D = 30;
  final float WANDER_CHANGE = 0.25;

  // FishBody
  final int MOUTH_ALPHA_THR = 10;
  
    // ROI defaults para segmentación blob (se sobreescriben desde roi.json si existe)
  final int ROI_X_DEFAULT = 128;
  final int ROI_Y_DEFAULT = 72;
  final int ROI_W_DEFAULT = 384;
  final int ROI_H_DEFAULT = 336;

  final int BLOB_WHITE_THR_DEFAULT = 225;
  // =========================
  // Fiduciales BoofCV (Square Binary)
  // =========================
  final boolean FIDUCIAL_ENABLED = true;

  // Tamaño del marcador en cm (2x2cm)
  final float FIDUCIAL_MARKER_SIZE_CM = 2.0;

  // IDs válidos, NO usarás 0
  final int FIDUCIAL_ID_MIN = 1;
  final int FIDUCIAL_ID_MAX = 10;

  // Solo rotación, en pasos de 90 grados
  final float FIDUCIAL_ROT_STEP_DEG = 90.0;

  // Debug por consola al capturar
  final boolean FIDUCIAL_DEBUG_PRINT = true;


}
