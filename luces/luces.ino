#include <Adafruit_NeoPixel.h>

// =========================
// Hardware
// =========================

// Tira NeoPixel 60 LEDs (nuevo)
#define PIN_NEOPIXEL       12
#define NUM_LEDS           60

// Matriz NeoPixel 8x8 (segunda)
#define PIN_NEOPIXEL_2     11
#define NUM_LEDS_2         64

// Botones arcade sin foco, usando INPUT_PULLUP (presionado = LOW)
#define PIN_BOTON_CAPTURA  2   // D2  -> manda captura y dispara animación
#define PIN_BOTON_Z        3   // D3  -> manda 'z'
#define PIN_BOTON_X        4   // D4  -> manda 'x'
#define PIN_BOTON_V        5   // D5  -> manda 'v'

#define DEBOUNCE_MS        35

Adafruit_NeoPixel pixels(NUM_LEDS, PIN_NEOPIXEL, NEO_GRB + NEO_KHZ800);
Adafruit_NeoPixel pixels2(NUM_LEDS_2, PIN_NEOPIXEL_2, NEO_GRB + NEO_KHZ800);

// =========================
// Antirrebote por botón
// =========================
struct DebounceBtn {
  uint8_t pin;
  int lastReading;
  int stableState;
  unsigned long lastDebounceTime;
  char onPressChar; // caracter a mandar a Processing al presionar
};

DebounceBtn btns[] = {
  { PIN_BOTON_CAPTURA, HIGH, HIGH, 0, 'S' }, // CAPTURA
  { PIN_BOTON_Z,       HIGH, HIGH, 0, 'z' }, // FOOD Z
  { PIN_BOTON_X,       HIGH, HIGH, 0, 'x' }, // FOOD X
  { PIN_BOTON_V,       HIGH, HIGH, 0, 'v' }  // FOOD V
};

const int BTN_COUNT = (int)(sizeof(btns) / sizeof(btns[0]));

int idleLedCount = 2;
String serialLine = "";

int matrixCornersOrder[NUM_LEDS_2];
bool matrixCornersOrderReady = false;

// =========================
// Animación NeoPixel no bloqueante (tira 60 LEDs en PIN_NEOPIXEL)
// =========================
bool animRunning = false;
int animHead = 0;                // cabeza del segmento (0..NUM_LEDS-1, luego sale)
unsigned long animT0 = 0;

// Ajuste rápido de velocidad
int TRAVEL_STEP_MS = 24;         // baja = más rápido, sube = más lento

const int TRAVEL_LEN = 5;        // cantidad de LEDs encendidos
const uint8_t TRAVEL_R = 0;
const uint8_t TRAVEL_G = 150;
const uint8_t TRAVEL_B = 255;

// Lanza solo la animación (para comando serial '1')
bool triggerAnimOnly = false;

// =========================
// Mapeo XY para matriz 2 (8x8)
// Cambia a 1 si tu matriz está cableada en serpentina
// =========================
#define MATRIX2_SERPENTINA 0

int indexXY2(int fila, int col) {
#if MATRIX2_SERPENTINA
  if (fila % 2 == 0) return fila * 8 + col;
  else return fila * 8 + (7 - col);
#else
  return fila * 8 + col;
#endif
}

void setup() {
  Serial.begin(9600);

  for (int i = 0; i < BTN_COUNT; i++) {
    pinMode(btns[i].pin, INPUT_PULLUP);
  }

  pixels.begin();
  pixels.clear();
  pixels.show();

  pixels2.begin();
  pixels2.clear();
  pixels2.show();

  prepareMatrixCornersOrder();

  updateIdleLeds();
}

void loop() {
  // 1) Leer comandos desde Processing
  while (Serial.available() > 0) {
    char comando = (char)Serial.read();

    if (comando == '\n' || comando == '\r') {
      if (serialLine.length() > 0) {
        parseSerialLine(serialLine);
        serialLine = "";
      }
      continue;
    }

    serialLine += comando;
    if (serialLine.length() > 32) serialLine = "";
  }

  // 2) Botones (con debounce)
  for (int i = 0; i < BTN_COUNT; i++) {
    readButtonAndAct(btns[i]);
  }

  // 3) Si llegó trigger de animación sola (comando '1'), ejecútala si no está en curso
  if (triggerAnimOnly) {
    triggerAnimOnly = false;
    if (!animRunning) {
      startAnim();
    }
  }

  // 4) Actualizar animación (no bloqueante)
  updateAnim();
}

// =========================
// Botones + debounce
// =========================
void readButtonAndAct(DebounceBtn &b) {
  int reading = digitalRead(b.pin);

  if (reading != b.lastReading) {
    b.lastDebounceTime = millis();
    b.lastReading = reading;
  }

  if ((millis() - b.lastDebounceTime) > DEBOUNCE_MS) {
    if (reading != b.stableState) {
      b.stableState = reading;

      // Evento al presionar (LOW por INPUT_PULLUP)
      if (b.stableState == LOW) {
        if (b.pin == PIN_BOTON_CAPTURA) {
          Serial.write('S');
          if (!animRunning) startAnim();
        } else {
          // Botones comida: manda el caracter a Processing
          Serial.write(b.onPressChar);
        }
      }
    }
  }
}

// =========================
// Matriz 2: patrón por esquinas hacia adentro
// =========================
void prepareMatrixCornersOrder() {
  if (matrixCornersOrderReady) return;

  int n = 0;
  for (int layer = 0; layer < 4; layer++) {
    int top = layer;
    int left = layer;
    int bottom = 7 - layer;
    int right = 7 - layer;

    // Prioridad: esquina 1, 3, 2, 4
    matrixCornersOrder[n++] = indexXY2(top, left);      // esquina 1 (arriba-izquierda)
    matrixCornersOrder[n++] = indexXY2(bottom, right);  // esquina 3 (abajo-derecha)
    matrixCornersOrder[n++] = indexXY2(top, right);     // esquina 2 (arriba-derecha)
    matrixCornersOrder[n++] = indexXY2(bottom, left);   // esquina 4 (abajo-izquierda)
  }

  // Completar con cualquier LED faltante para cubrir los 64 índices.
  for (int fila = 0; fila < 8; fila++) {
    for (int col = 0; col < 8; col++) {
      int idx = indexXY2(fila, col);
      bool exists = false;

      for (int i = 0; i < n; i++) {
        if (matrixCornersOrder[i] == idx) {
          exists = true;
          break;
        }
      }

      if (!exists && n < NUM_LEDS_2) {
        matrixCornersOrder[n++] = idx;
      }
    }
  }

  matrixCornersOrderReady = true;
}

void paintMatrixCorners(int ledCount, uint32_t color) {
  int cappedCount = ledCount;
  if (cappedCount < 1) cappedCount = 1;
  if (cappedCount > NUM_LEDS_2) cappedCount = NUM_LEDS_2;

  for (int i = 0; i < cappedCount; i++) {
    int idx = matrixCornersOrder[i];
    if (idx >= 0 && idx < NUM_LEDS_2) pixels2.setPixelColor(idx, color);
  }
}

void updateIdleMatrix() {
  pixels2.clear();

  uint32_t idleColor = pixels2.Color(255, 255, 255);
  paintMatrixCorners(idleLedCount, idleColor);

  pixels2.show();
}

void updateIdleStrip() {
  // La tira principal debe permanecer apagada en reposo.
  pixels.clear();
  pixels.show();
}

void updateIdleLeds() {
  updateIdleMatrix();
  updateIdleStrip();
}

void parseSerialLine(String line) {
  line.trim();
  if (line.length() == 0) return;

  // Compatibilidad con Processing legado: comando directo "1" para animación
  if (line == "1") {
    triggerAnimOnly = true;
    return;
  }

  if (line.startsWith("I:")) {
    int leds = line.substring(2).toInt();
    if (leds >= 1 && leds <= NUM_LEDS_2) {
      idleLedCount = leds;
      updateIdleMatrix();
    }
  }
}


// =========================
// Animación NeoPixel no bloqueante (tira 60 LEDs)
// Efecto: 5 LEDs encendidos avanzan de 0 a 59
// =========================
void startAnim() {
  animRunning = true;
  animHead = 0;
  animT0 = millis();

  pixels.clear();
  drawTravelFrame(animHead);
  pixels.show();
}

void updateAnim() {
  if (!animRunning) return;

  unsigned long now = millis();
  if (now - animT0 < (unsigned long)TRAVEL_STEP_MS) return;
  animT0 = now;

  animHead++;

  // Cuando la cabeza ya salió y la cola también, termina
  if (animHead >= NUM_LEDS + TRAVEL_LEN) {
    animRunning = false;
    updateIdleStrip();
    return;
  }

  pixels.clear();
  drawTravelFrame(animHead);
  pixels.show();
}

void drawTravelFrame(int head) {
  int start = head - TRAVEL_LEN + 1;
  int end = head;

  for (int i = start; i <= end; i++) {
    if (i < 0 || i >= NUM_LEDS) continue;

    // Cola con atenuación simple
    int tailIndex = end - i; // 0 = cabeza, 4 = cola
    float k = 1.0;
    if (tailIndex == 1) k = 0.75;
    else if (tailIndex == 2) k = 0.55;
    else if (tailIndex == 3) k = 0.35;
    else if (tailIndex >= 4) k = 0.20;

    pixels.setPixelColor(
      i,
      pixels.Color((uint8_t)(TRAVEL_R * k), (uint8_t)(TRAVEL_G * k), (uint8_t)(TRAVEL_B * k))
    );
  }
}
