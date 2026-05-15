#include <FastLED.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <LiquidCrystal_I2C.h>
#include <HardwareSerial.h>

// CONFIGURATION
#define LED_PIN 5
#define NUM_LEDS 30
#define LED_TYPE WS2812B
#define COLOR_ORDER GRB

#define LCD_ADDRESS 0x27
#define LCD_COLUMNS 16
#define LCD_ROWS 2

#define RXD2 16
#define TXD2 17
#define UART_BAUD 115200

#define SERVICE_UUID "0000ffe0-0000-1000-8000-00805f9b34fb"
#define CHAR_UUID    "0000ffe1-0000-1000-8000-00805f9b34fb"

// GLOBAL OBJECTS
CRGB leds[NUM_LEDS];
LiquidCrystal_I2C lcd(LCD_ADDRESS, LCD_COLUMNS, LCD_ROWS);
HardwareSerial OpenMVSerial(2);

BLEServer*         pServer         = nullptr;
BLECharacteristic* pCharacteristic = nullptr;

bool deviceConnected    = false;
bool oldDeviceConnected = false;

// SESSION STATE
enum LightMode {
  MODE_OFF,
  MODE_FOCUS,
  MODE_BREAK,
  MODE_PAUSED,
  MODE_DISTRACTION_WARNING
};

LightMode currentMode = MODE_OFF;

int    timerMinutes  = 0;
int    timerSeconds  = 0;
bool   timerActive   = false;
String sessionStatus = "ready";
String sessionMode   = "focus";

// CAMERA MASTER SWITCH
bool cameraDetectionEnabled = false;

// TRACKING STATE
bool isUserSleeping = false;
bool isUserAbsent   = false;
bool isUserOnPhone  = false;

unsigned long sleepStartTime             = 0;
unsigned long absentStartTime            = 0;
unsigned long phoneStartTime             = 0;
unsigned long currentDistractionDuration = 0;
unsigned long sessionStartTime           = 0;
unsigned long totalFocusedSeconds        = 0;
unsigned long lastFocusTickMillis        = 0;

int   distractionCount     = 0;
float distractionRate      = 0.0;
int   distractionThreshold = 60;

// Tracks which trigger caused the currently active alert
// so we can report the correct type when it ends
String currentAlertTriggerType = "";

// TRIGGERS
bool sleepTriggerEnabled    = true;
bool presenceTriggerEnabled = false;
bool phoneTriggerEnabled    = false;

// ALERTS
String alertStyle  = "strong";
String subtleType  = "light";

bool          redLightActive           = false;
unsigned long redLightStartTime        = 0;
const unsigned long MIN_RED_LIGHT_DURATION = 5000;

// ─── COLORS (as requested) ────────────────────────────────────────────────────
const CRGB COLOR_FOCUS               = CRGB(250, 252, 255);
const CRGB COLOR_BREAK               = CRGB(255, 100,  20);
const CRGB COLOR_PAUSED              = CRGB(180, 200, 100);
const CRGB COLOR_OFF                 = CRGB(  0,   0,   0);
const CRGB COLOR_DISTRACTION_WARNING = CRGB(255,   0,   0);

// BRIGHTNESS
const uint8_t BRIGHTNESS_FOCUS   = 255;
const uint8_t BRIGHTNESS_BREAK   = 220;   // raised for visibility
const uint8_t BRIGHTNESS_PAUSED  = 220;
const uint8_t BRIGHTNESS_WARNING = 255;
const uint8_t BRIGHTNESS_OFF     = 0;

// ─── LCD BUFFER ──────────────────────────────────────────────────────────────
// All LCD writes happen exclusively in the main loop (writeLCDIfNeeded).
// Callbacks only update these strings and set the flag.
// This prevents I2C bus corruption from concurrent access.
String           lcdLine0      = "";
String           lcdLine1      = "";
volatile bool    lcdNeedsWrite = false;

// ─── PROTOTYPES ──────────────────────────────────────────────────────────────
void  processCommand(String command);
void  processCameraMessage(String message);
void  updateLCDDisplay();
void  writeLCDIfNeeded();
void  showWelcomeMessage();
void  setAllLEDs(CRGB color);
void  applyLEDState(CRGB color, uint8_t brightness);
void  startFocusMode();
void  startBreakMode();
void  setPausedMode();
void  turnOffAll();
void  handleDistractionLogic();
void  restoreCorrectColor();
void  notifyAppDistraction();
void  notifyDistractionEnd();
void  resetCameraTracking();
void  setCameraDetectionEnabled(bool enabled);
void  calculateDistractionRate();
String compactCommand(String command);
bool  hasJsonBool(String compact, String key, bool value);
void  sendCameraStatus();
void  updateFocusAccumulation();
bool  isSessionEndedStatus(String status);
bool  isSessionRunningStatus(String status);
bool  isSessionPausedStatus(String status);
String formatFocusedDuration(unsigned long totalSeconds);
String getDetectedTriggerText();
String formatTimerText();
void  buildLCDContent(String &line0, String &line1);
void  printLCDPhysical(uint8_t row, String text);
void  maintainActiveFocusWhite();
String getDominantTriggerType();

// ─── BLE CALLBACKS ───────────────────────────────────────────────────────────
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    lcdLine0 = "Phone Connected ";
    lcdLine1 = "                ";
    lcdNeedsWrite = true;
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    turnOffAll();
    setCameraDetectionEnabled(false);
    BLEDevice::startAdvertising();
  }
};

class CharacteristicCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    String command = pCharacteristic->getValue().c_str();
    if (command.length() > 0) {
      Serial.print("App JSON: ");
      Serial.println(command);
      processCommand(command);
    }
  }
};

// ─── HELPERS ─────────────────────────────────────────────────────────────────
String compactCommand(String command) {
  command.replace(" ", "");
  command.replace("\n", "");
  command.replace("\r", "");
  command.replace("\t", "");
  return command;
}

bool hasJsonBool(String compact, String key, bool value) {
  String needle = String("\"") + key + "\":" + (value ? "true" : "false");
  return compact.indexOf(needle) >= 0;
}

// Returns the type string of whichever active + enabled trigger has been
// running the longest. Used to label the distraction event when it ends.
String getDominantTriggerType() {
  unsigned long maxDur = 0;
  String type = "unknown";
  unsigned long now = millis();

  if (isUserSleeping && sleepTriggerEnabled) {
    unsigned long d = now - sleepStartTime;
    if (d > maxDur) { maxDur = d; type = "sleeping"; }
  }
  if (isUserAbsent && presenceTriggerEnabled) {
    unsigned long d = now - absentStartTime;
    if (d > maxDur) { maxDur = d; type = "absence"; }
  }
  if (isUserOnPhone && phoneTriggerEnabled) {
    unsigned long d = now - phoneStartTime;
    if (d > maxDur) { maxDur = d; type = "phone_use"; }
  }
  return type;
}

void resetCameraTracking() {
  isUserSleeping = false;
  isUserAbsent   = false;
  isUserOnPhone  = false;

  unsigned long now = millis();
  sleepStartTime  = now;
  absentStartTime = now;
  phoneStartTime  = now;

  currentDistractionDuration = 0;
  redLightActive             = false;
  currentAlertTriggerType    = "";
}

void setCameraDetectionEnabled(bool enabled) {
  cameraDetectionEnabled = enabled;
  resetCameraTracking();
  if (!enabled) {
    restoreCorrectColor();
    Serial.println("Camera detection DISABLED");
  } else {
    Serial.println("Camera detection ENABLED");
  }
  sendCameraStatus();
  updateLCDDisplay();
}

void sendCameraStatus() {
  if (!deviceConnected || pCharacteristic == nullptr) return;
  String status  = cameraDetectionEnabled ? "enabled" : "disabled";
  String payload = "{\"cameraStatus\":\"" + status + "\"}";
  pCharacteristic->setValue(payload.c_str());
  pCharacteristic->notify();
}

void notifyAppDistraction() {
  if (!deviceConnected || pCharacteristic == nullptr) return;
  String payload = "{\"distraction\":true,\"count\":" + String(distractionCount) + "}";
  pCharacteristic->setValue(payload.c_str());
  pCharacteristic->notify();
}

// Sent when a distraction alert clears so the Flutter app can log the event
// to the Session_Distraction table with the correct type and duration.
void notifyDistractionEnd() {
  if (!deviceConnected || pCharacteristic == nullptr) return;
  unsigned long durationSeconds = (millis() - redLightStartTime) / 1000;
  String payload = "{\"distractionEnd\":true,\"type\":\"" +
                   currentAlertTriggerType +
                   "\",\"duration\":" + String(durationSeconds) + "}";
  pCharacteristic->setValue(payload.c_str());
  pCharacteristic->notify();
  Serial.print("Distraction ended — type: ");
  Serial.print(currentAlertTriggerType);
  Serial.print(" — duration: ");
  Serial.println(durationSeconds);
}

void calculateDistractionRate() {
  if (!timerActive) return;
  unsigned long elapsedMillis = millis() - sessionStartTime;
  float minutes = elapsedMillis / 60000.0;
  if (minutes < 0.1) minutes = 0.1;
  distractionRate = ((float)distractionCount / minutes) * 10.0;
}

// ─── DISTRACTION LOGIC ───────────────────────────────────────────────────────
void handleDistractionLogic() {
  if (!cameraDetectionEnabled) {
    if (redLightActive) {
      notifyDistractionEnd();
      redLightActive = false;
      currentAlertTriggerType = "";
      restoreCorrectColor();
    }
    currentDistractionDuration = 0;
    return;
  }

  if (!timerActive || sessionMode != "focus") {
    if (redLightActive) {
      notifyDistractionEnd();
      redLightActive = false;
      currentAlertTriggerType = "";
      restoreCorrectColor();
    }
    currentDistractionDuration = 0;
    return;
  }

  unsigned long now = millis();

  unsigned long maxSleepDuration =
      (isUserSleeping && sleepTriggerEnabled)    ? (now - sleepStartTime)  : 0;
  unsigned long maxAbsentDuration =
      (isUserAbsent && presenceTriggerEnabled)   ? (now - absentStartTime) : 0;
  unsigned long maxPhoneDuration =
      (isUserOnPhone && phoneTriggerEnabled)     ? (now - phoneStartTime)  : 0;

  unsigned long maxDuration = max(max(maxSleepDuration, maxAbsentDuration), maxPhoneDuration);
  currentDistractionDuration = maxDuration;

  bool useLight = (alertStyle == "strong" ||
                   (alertStyle == "subtle" && subtleType == "light"));

  if (maxDuration > 0) {
    if (currentDistractionDuration >= (unsigned long)(distractionThreshold * 1000) && !redLightActive) {
      redLightActive          = true;
      redLightStartTime       = now;
      currentAlertTriggerType = getDominantTriggerType();
      distractionCount++;

      if (useLight) applyLEDState(COLOR_DISTRACTION_WARNING, BRIGHTNESS_WARNING);
      notifyAppDistraction();
      updateLCDDisplay();
    }
  }

  if (redLightActive) {
    bool minTimePassed  = (now - redLightStartTime) >= MIN_RED_LIGHT_DURATION;
    bool sleepClear     = !sleepTriggerEnabled    || !isUserSleeping;
    bool presenceClear  = !presenceTriggerEnabled || !isUserAbsent;
    bool phoneClear     = !phoneTriggerEnabled    || !isUserOnPhone;

    if (minTimePassed && sleepClear && presenceClear && phoneClear) {
      notifyDistractionEnd();   // tell the app to log this event
      redLightActive          = false;
      currentDistractionDuration = 0;
      currentAlertTriggerType = "";
      restoreCorrectColor();
      updateLCDDisplay();
    } else {
      if (useLight) {
        if ((now / 500) % 2 == 0) applyLEDState(COLOR_DISTRACTION_WARNING, BRIGHTNESS_WARNING);
        else                       applyLEDState(CRGB(50, 0, 0), BRIGHTNESS_WARNING);
      }

      static unsigned long lastNotifyTime = 0;
      if (now - lastNotifyTime >= 5000) {
        lastNotifyTime = now;
        notifyAppDistraction();
      }
    }
  }

  static unsigned long lastRateUpdate = 0;
  if (now - lastRateUpdate > 2000) {
    lastRateUpdate = now;
    calculateDistractionRate();
    updateLCDDisplay();
  }
}

// ─── OPENMV MESSAGE HANDLING ─────────────────────────────────────────────────
void processCameraMessage(String message) {
  if (!cameraDetectionEnabled) return;
  message.trim();
  if (message.length() == 0) return;

  if (message.startsWith("SYNC:")) {
    bool camSleeping = (message.indexOf(":SLEEPING") > 0);
    bool camAbsent   = (message.indexOf(":ABSENT")   > 0);
    bool camPhone    = (message.indexOf(":PHONE_ON")  > 0);

    // SLEEP
    if (camSleeping && !isUserSleeping) {
      isUserSleeping = true;
      sleepStartTime = millis();
    } else if (!camSleeping && isUserSleeping) {
      isUserSleeping = false;
      if (!redLightActive && !isUserAbsent && !isUserOnPhone) restoreCorrectColor();
    }

    // PRESENCE
    if (camAbsent && !isUserAbsent) {
      isUserAbsent   = true;
      absentStartTime = millis();
    } else if (!camAbsent && isUserAbsent) {
      isUserAbsent = false;
      if (!redLightActive && !isUserSleeping && !isUserOnPhone) restoreCorrectColor();
    }

    // PHONE
    if (camPhone && !isUserOnPhone) {
      isUserOnPhone  = true;
      phoneStartTime = millis();
      Serial.println("SYNC: Phone usage detected");
    } else if (!camPhone && isUserOnPhone) {
      isUserOnPhone = false;
      if (!redLightActive && !isUserSleeping && !isUserAbsent) restoreCorrectColor();
    }
  }
}

// ─── BLE COMMAND HANDLING ─────────────────────────────────────────────────────
void processCommand(String command) {
  updateFocusAccumulation();

  String compact = compactCommand(command);

  bool explicitCameraDisable =
      hasJsonBool(compact, "camera", false) ||
      hasJsonBool(compact, "cameraDetection", false) ||
      hasJsonBool(compact, "cameraEnabled", false) ||
      compact.indexOf("\"command\":\"disableCamera\"") >= 0 ||
      compact.indexOf("\"command\":\"disableCameraDetection\"") >= 0;

  bool explicitCameraEnable =
      hasJsonBool(compact, "camera", true) ||
      hasJsonBool(compact, "cameraDetection", true) ||
      hasJsonBool(compact, "cameraEnabled", true) ||
      compact.indexOf("\"command\":\"enableCamera\"") >= 0 ||
      compact.indexOf("\"command\":\"enableCameraDetection\"") >= 0;

  if (explicitCameraDisable) { setCameraDetectionEnabled(false); return; }
  if (explicitCameraEnable)  { setCameraDetectionEnabled(true);  }

  if (compact.indexOf("\"requestCameraStatus\":true") >= 0) { sendCameraStatus(); return; }

  // Sensitivity
  if      (compact.indexOf("\"sensitivity\":\"high\"")   >= 0) distractionThreshold = 30;
  else if (compact.indexOf("\"sensitivity\":\"medium\"") >= 0) distractionThreshold = 60;
  else if (compact.indexOf("\"sensitivity\":\"low\"")    >= 0) distractionThreshold = 90;

  // Notification style
  if      (compact.indexOf("\"notificationStyle\":\"subtle\"") >= 0 ||
           compact.indexOf("\"style\":\"subtle\"")             >= 0) alertStyle = "subtle";
  else if (compact.indexOf("\"notificationStyle\":\"strong\"") >= 0 ||
           compact.indexOf("\"style\":\"strong\"")             >= 0) alertStyle = "strong";

  if      (compact.indexOf("\"subtleType\":\"sound\"")      >= 0 ||
           compact.indexOf("\"subtleAlertType\":\"sound\"") >= 0) subtleType = "sound";
  else if (compact.indexOf("\"subtleType\":\"light\"")      >= 0 ||
           compact.indexOf("\"subtleAlertType\":\"light\"") >= 0) subtleType = "light";

  // Triggers
  if      (compact.indexOf("\"sleepTrig\":true")  >= 0) sleepTriggerEnabled = true;
  else if (compact.indexOf("\"sleepTrig\":false") >= 0) sleepTriggerEnabled = false;

  if      (compact.indexOf("\"presenceTrig\":true")  >= 0) presenceTriggerEnabled = true;
  else if (compact.indexOf("\"presenceTrig\":false") >= 0) presenceTriggerEnabled = false;

  if      (compact.indexOf("\"phoneTrig\":true")  >= 0) phoneTriggerEnabled = true;
  else if (compact.indexOf("\"phoneTrig\":false") >= 0) phoneTriggerEnabled = false;

  // Timer command
  if (compact.indexOf("\"timer\":") >= 0) {
    int minutesStart = compact.indexOf("\"minutes\":") + 10;
    int minutesEnd   = compact.indexOf(",", minutesStart);
    if (minutesEnd == -1) minutesEnd = compact.indexOf("}", minutesStart);

    int secondsStart = compact.indexOf("\"seconds\":") + 10;
    int secondsEnd   = compact.indexOf(",", secondsStart);
    if (secondsEnd == -1) secondsEnd = compact.indexOf("}", secondsStart);

    int statusStart = compact.indexOf("\"status\":\"") + 10;
    int statusEnd   = compact.indexOf("\"", statusStart);

    int modeStart = compact.indexOf("\"mode\":\"") + 8;
    int modeEnd   = compact.indexOf("\"", modeStart);

    if (minutesStart >= 10 && minutesEnd > minutesStart)
      timerMinutes = compact.substring(minutesStart, minutesEnd).toInt();

    if (secondsStart >= 10 && secondsEnd > secondsStart)
      timerSeconds = compact.substring(secondsStart, secondsEnd).toInt();

    // Process MODE first
    if (modeStart >= 8 && modeEnd > modeStart) {
      String newMode = compact.substring(modeStart, modeEnd);
      if (newMode != sessionMode) {
        sessionMode = newMode;
        redLightActive             = false;
        currentDistractionDuration = 0;
        currentAlertTriggerType    = "";
        resetCameraTracking();
        if (sessionStatus == "running") {
          if (sessionMode == "focus") startFocusMode();
          else                        startBreakMode();
        }
      }
    }

    // Then STATUS
    if (statusStart >= 10 && statusEnd > statusStart) {
      String newStatus = compact.substring(statusStart, statusEnd);

      if (isSessionRunningStatus(newStatus) && !isSessionRunningStatus(sessionStatus)) {
        timerActive    = true;
        sessionStartTime = millis();
        resetCameraTracking();

        if (sessionStatus == "ready" || isSessionEndedStatus(sessionStatus)) {
          distractionCount  = 0;
          distractionRate   = 0.0;
          totalFocusedSeconds   = 0;
          lastFocusTickMillis   = millis();
        }

        if (sessionMode == "focus") startFocusMode();
        else                        startBreakMode();

      } else if (isSessionRunningStatus(newStatus)) {
        timerActive = true;
        if (!redLightActive) {
          if (sessionMode == "focus") startFocusMode();
          else                        startBreakMode();
        }

      } else if (isSessionPausedStatus(newStatus) && !isSessionPausedStatus(sessionStatus)) {
        timerActive                = false;
        redLightActive             = false;
        currentDistractionDuration = 0;
        currentAlertTriggerType    = "";
        setPausedMode();

      } else if (isSessionEndedStatus(newStatus) && !isSessionEndedStatus(sessionStatus)) {
        updateFocusAccumulation();
        timerActive                = false;
        lastFocusTickMillis        = 0;
        redLightActive             = false;
        currentDistractionDuration = 0;
        currentAlertTriggerType    = "";
        applyLEDState(COLOR_OFF, BRIGHTNESS_OFF);
      }

      sessionStatus = newStatus;
    }

    updateLCDDisplay();
  }

  // Off/reset command
  if (compact.indexOf("\"on\":false") >= 0) {
    turnOffAll();
    setCameraDetectionEnabled(false);
    alertStyle    = "strong";
    subtleType    = "light";
    sessionStatus = "ready";
    sessionMode   = "focus";
    distractionCount           = 0;
    distractionRate            = 0.0;
    currentDistractionDuration = 0;
    totalFocusedSeconds        = 0;
    lastFocusTickMillis        = 0;
    currentAlertTriggerType    = "";
    updateLCDDisplay();
    return;
  }
}

// ─── LCD ─────────────────────────────────────────────────────────────────────
bool isSessionEndedStatus(String status) {
  status.toLowerCase();
  return status == "ended"    || status == "end"      ||
         status == "finished" || status == "complete" ||
         status == "completed"|| status == "done";
}

bool isSessionRunningStatus(String status) {
  status.toLowerCase();
  return status == "running"  || status == "active"   ||
         status == "started"  || status == "start"    ||
         status == "resume"   || status == "resumed"  ||
         status == "focus"    || status == "work"     ||
         status == "inprogress" || status == "in_progress";
}

bool isSessionPausedStatus(String status) {
  status.toLowerCase();
  return status == "paused" || status == "pause";
}

String formatFocusedDuration(unsigned long totalSeconds) {
  unsigned long hours   = totalSeconds / 3600;
  unsigned long minutes = (totalSeconds % 3600) / 60;
  unsigned long seconds = totalSeconds % 60;
  if (hours > 0)   return String(hours)   + "h " + String(minutes) + "m";
  if (minutes > 0) return String(minutes) + "m " + String(seconds) + "s";
  return String(seconds) + "s";
}

String getDetectedTriggerText() {
  if (isUserSleeping && sleepTriggerEnabled)    return "sleep detected";
  if (isUserOnPhone  && phoneTriggerEnabled)    return "phone detected";
  if (isUserAbsent   && presenceTriggerEnabled) return "absent detected";
  return "trigger detected";
}

String formatTimerText() {
  String text = "Time: ";
  if (timerMinutes < 10) text += "0";
  text += String(timerMinutes) + ":";
  if (timerSeconds < 10) text += "0";
  text += String(timerSeconds);
  return text;
}

// Computes both LCD lines into the string buffers.
// Never touches the physical LCD — only updates lcdLine0/lcdLine1.
void buildLCDContent(String &line0, String &line1) {
  if (isSessionEndedStatus(sessionStatus)) {
    line0 = "Great job.";
    line1 = "Total: " + formatFocusedDuration(totalFocusedSeconds);
    return;
  }

  if (!(timerActive || isSessionPausedStatus(sessionStatus))) {
    line0 = "Rikaz System";
    line1 = "Ready to focus?";
    return;
  }

  line0 = formatTimerText();

  if (isSessionPausedStatus(sessionStatus)) {
    line1 = "Session Paused";
  } else if (sessionMode == "break") {
    line1 = "Time for rest";
  } else if (sessionMode == "focus") {
    if (redLightActive) {
      line1 = getDetectedTriggerText();
    } else if (currentDistractionDuration > 0) {
      line1 = "Detecting... " + String(currentDistractionDuration / 1000) + "s";
    } else {
      line1 = "Keep Going!";
    }
  }
}

// Called from callbacks / logic — only updates string buffers + sets flag.
void updateLCDDisplay() {
  String newLine0, newLine1;
  buildLCDContent(newLine0, newLine1);
  if (newLine0 != lcdLine0 || newLine1 != lcdLine1) {
    lcdLine0      = newLine0;
    lcdLine1      = newLine1;
    lcdNeedsWrite = true;
  }
}

// Pads/truncates a string to exactly LCD_COLUMNS characters, then writes it.
void printLCDPhysical(uint8_t row, String text) {
  if ((int)text.length() > LCD_COLUMNS) text = text.substring(0, LCD_COLUMNS);
  while ((int)text.length() < LCD_COLUMNS) text += " ";
  lcd.setCursor(0, row);
  lcd.print(text);
}

// Called only from the main loop — safely writes buffered content to LCD.
void writeLCDIfNeeded() {
  if (!lcdNeedsWrite) return;
  lcdNeedsWrite = false;
  lcd.backlight();
  printLCDPhysical(0, lcdLine0);
  printLCDPhysical(1, lcdLine1);
}

// ─── LED MODES ───────────────────────────────────────────────────────────────
void restoreCorrectColor() {
  if (sessionStatus == "ready" || isSessionEndedStatus(sessionStatus))
    applyLEDState(COLOR_OFF, BRIGHTNESS_OFF);
  else if (isSessionPausedStatus(sessionStatus))
    applyLEDState(COLOR_PAUSED, BRIGHTNESS_PAUSED);
  else if (sessionMode == "break")
    applyLEDState(COLOR_BREAK, BRIGHTNESS_BREAK);
  else if (sessionMode == "focus")
    applyLEDState(COLOR_FOCUS, BRIGHTNESS_FOCUS);
  else
    applyLEDState(COLOR_OFF, BRIGHTNESS_OFF);
}

void startFocusMode() { currentMode = MODE_FOCUS; applyLEDState(COLOR_FOCUS, BRIGHTNESS_FOCUS); }
void startBreakMode()  {
  currentMode                = MODE_BREAK;
  redLightActive             = false;
  currentDistractionDuration = 0;
  currentAlertTriggerType    = "";
  resetCameraTracking();
  applyLEDState(COLOR_BREAK, BRIGHTNESS_BREAK);
}
void setPausedMode() {
  currentMode                = MODE_PAUSED;
  redLightActive             = false;
  currentDistractionDuration = 0;
  currentAlertTriggerType    = "";
  applyLEDState(COLOR_PAUSED, BRIGHTNESS_PAUSED);
}
void turnOffAll() {
  currentMode                = MODE_OFF;
  timerActive                = false;
  sessionStatus              = "ready";
  redLightActive             = false;
  currentDistractionDuration = 0;
  currentAlertTriggerType    = "";
  applyLEDState(COLOR_OFF, BRIGHTNESS_OFF);
  lcdLine0 = "Rikaz System";
  lcdLine1 = "Ready to focus?";
  lcdNeedsWrite = true;
}

void setAllLEDs(CRGB color) { fill_solid(leds, NUM_LEDS, color); FastLED.show(); }
void applyLEDState(CRGB color, uint8_t brightness) {
  FastLED.setBrightness(brightness);
  setAllLEDs(color);
}

// ─── FOCUS ACCUMULATION ──────────────────────────────────────────────────────
void updateFocusAccumulation() {
  unsigned long now = millis();
  if (timerActive && sessionMode == "focus") {
    if (lastFocusTickMillis == 0) { lastFocusTickMillis = now; return; }
    unsigned long elapsed = now - lastFocusTickMillis;
    if (elapsed >= 1000) {
      unsigned long elapsedSeconds = elapsed / 1000;
      totalFocusedSeconds += elapsedSeconds;
      lastFocusTickMillis += elapsedSeconds * 1000;
    }
  } else {
    lastFocusTickMillis = 0;
  }
}

// ─── MAINTAIN FOCUS COLOR ────────────────────────────────────────────────────
void maintainActiveFocusWhite() {
  static unsigned long lastWhiteRefresh = 0;
  unsigned long now = millis();
  if (now - lastWhiteRefresh < 100) return;
  lastWhiteRefresh = now;
  if (timerActive && isSessionRunningStatus(sessionStatus) &&
      sessionMode == "focus" && !redLightActive) {
    applyLEDState(COLOR_FOCUS, BRIGHTNESS_FOCUS);
  }
}

void showWelcomeMessage() {
  lcdLine0 = "Rikaz System";
  lcdLine1 = "Ready to focus?";
  lcdNeedsWrite = true;
}

// ─── SETUP ───────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);

  OpenMVSerial.begin(UART_BAUD, SERIAL_8N1, RXD2, TXD2);
  OpenMVSerial.setRxBufferSize(1024);
  OpenMVSerial.setTimeout(50);

  lcd.init();
  lcd.clear();
  lcd.backlight();
  showWelcomeMessage();
  writeLCDIfNeeded();   // write welcome immediately on startup

  FastLED.addLeds<LED_TYPE, LED_PIN, COLOR_ORDER>(leds, NUM_LEDS);
  FastLED.setCorrection(UncorrectedColor);
  FastLED.setDither(0);
  FastLED.setBrightness(BRIGHTNESS_OFF);
  setAllLEDs(COLOR_OFF);

  BLEDevice::init("Rikaz-Light");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
      CHAR_UUID,
      BLECharacteristic::PROPERTY_READ  |
      BLECharacteristic::PROPERTY_WRITE |
      BLECharacteristic::PROPERTY_NOTIFY);

  pCharacteristic->setCallbacks(new CharacteristicCallbacks());
  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();

  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  BLEDevice::startAdvertising();

  Serial.println("Rikaz ESP ready.");
}

// ─── LOOP ────────────────────────────────────────────────────────────────────
void loop() {
  // Read camera UART only when detection is active
  if (cameraDetectionEnabled) {
    if (OpenMVSerial.available()) {
      String message = OpenMVSerial.readStringUntil('\n');
      processCameraMessage(message);
    }
  } else {
    // Flush stale messages so they don't fire when detection is re-enabled
    while (OpenMVSerial.available()) OpenMVSerial.read();
  }

  updateFocusAccumulation();
  handleDistractionLogic();
  maintainActiveFocusWhite();

  // All LCD writes happen here — never from BLE callback threads
  writeLCDIfNeeded();

  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    oldDeviceConnected = deviceConnected;
  }

  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }

  delay(20);
}
