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
#define CHAR_UUID "0000ffe1-0000-1000-8000-00805f9b34fb"

// GLOBAL OBJECTS
CRGB leds[NUM_LEDS];
LiquidCrystal_I2C lcd(LCD_ADDRESS, LCD_COLUMNS, LCD_ROWS);
HardwareSerial OpenMVSerial(2);

BLEServer* pServer = nullptr;
BLECharacteristic* pCharacteristic = nullptr;

bool deviceConnected = false;
bool oldDeviceConnected = false;

// Session State
enum LightMode { MODE_OFF, MODE_FOCUS, MODE_BREAK, MODE_PAUSED, MODE_DISTRACTION_WARNING };
LightMode currentMode = MODE_OFF;

int timerMinutes = 0;
int timerSeconds = 0;
bool timerActive = false;
String sessionStatus = "ready";
String sessionMode = "focus";

// Tracking State
bool isUserSleeping = false;
bool isUserAbsent = false;
bool isUserOnPhone = false;

unsigned long sleepStartTime = 0;
unsigned long absentStartTime = 0;
unsigned long phoneStartTime = 0;
unsigned long currentDistractionDuration = 0;
unsigned long sessionStartTime = 0;

int distractionCount = 0;
float distractionRate = 0.0;
int distractionThreshold = 60; 

// Triggers & Alerts
bool sleepTriggerEnabled = true;
bool presenceTriggerEnabled = false;
bool phoneTriggerEnabled = false;
String alertStyle = "strong"; 
String subtleType = "light";

// Alert Logic
bool redLightActive = false;
unsigned long redLightStartTime = 0;
const unsigned long MIN_RED_LIGHT_DURATION = 5000; 

const CRGB COLOR_FOCUS = CRGB(250, 252, 255); 
const CRGB COLOR_BREAK = CRGB(255, 100, 20); 
const CRGB COLOR_PAUSED = CRGB(180, 200, 100); 
const CRGB COLOR_OFF = CRGB(0, 0, 0);
const CRGB COLOR_DISTRACTION_WARNING = CRGB(255, 0, 0); 

// PROTOTYPES
void processCommand(String command);
void processCameraMessage(String message);
void updateLCDDisplay();
void showWelcomeMessage();
void setAllLEDs(CRGB color);
void startFocusMode();
void startBreakMode();
void setPausedMode();
void turnOffAll();
void handleDistractionLogic();
void createCustomChars();
void restoreCorrectColor();
void notifyAppDistraction();

class ServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        lcd.clear();
        lcd.print("Phone Connected");
        delay(1000);
        showWelcomeMessage();
    }
    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        turnOffAll();
        BLEDevice::startAdvertising();
    }
};

class CharacteristicCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) {
        String command = pCharacteristic->getValue().c_str();
        if (command.length() > 0) {
            Serial.print("App JSON: "); Serial.println(command);
            processCommand(command);
        }
    }
};

void notifyAppDistraction() {
    if (deviceConnected && pCharacteristic != nullptr) {
        String payload = "{\"distraction\":true,\"count\":" + String(distractionCount) + "}";
        pCharacteristic->setValue(payload.c_str());
        pCharacteristic->notify();
    }
}

void calculateDistractionRate() {
    if (!timerActive) return;
    unsigned long elapsedMillis = millis() - sessionStartTime;
    float minutes = elapsedMillis / 60000.0;
    if (minutes < 0.1) minutes = 0.1;
    distractionRate = ((float)distractionCount / minutes) * 10.0;
}

void handleDistractionLogic() {
    if (!timerActive || sessionMode != "focus") {
        redLightActive = false;
        return;
    }

    unsigned long now = millis();
    unsigned long maxSleepDuration = (isUserSleeping && sleepTriggerEnabled) ? (now - sleepStartTime) : 0;
    unsigned long maxAbsentDuration = (isUserAbsent && presenceTriggerEnabled) ? (now - absentStartTime) : 0;
    unsigned long maxPhoneDuration = (isUserOnPhone && phoneTriggerEnabled) ? (now - phoneStartTime) : 0;
    
    unsigned long maxDuration = max(max(maxSleepDuration, maxAbsentDuration), maxPhoneDuration);
    currentDistractionDuration = maxDuration;

    bool useLight = (alertStyle == "strong" || (alertStyle == "subtle" && subtleType == "light"));

    if (maxDuration > 0) {
        if (currentDistractionDuration >= (distractionThreshold * 1000) && !redLightActive) {
            redLightActive = true;
            redLightStartTime = now;
            distractionCount++;
            
            if (useLight) {
                setAllLEDs(COLOR_DISTRACTION_WARNING);
            }
            notifyAppDistraction(); 
        }
    }

    if (redLightActive) {
        bool minTimePassed = (now - redLightStartTime) >= MIN_RED_LIGHT_DURATION;
        bool sleepClear = !sleepTriggerEnabled || !isUserSleeping;
        bool presenceClear = !presenceTriggerEnabled || !isUserAbsent;
        bool phoneClear = !phoneTriggerEnabled || !isUserOnPhone;

        if (minTimePassed && sleepClear && presenceClear && phoneClear) {
            redLightActive = false;
            restoreCorrectColor(); 
        } else {
            if (useLight) {
                if ((now/500) % 2 == 0) setAllLEDs(COLOR_DISTRACTION_WARNING);
                else setAllLEDs(CRGB(50, 0, 0));
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
    }
}

void processCameraMessage(String message) {
    message.trim();
    if (message.length() == 0) return;
    
    if (message.startsWith("SYNC:")) {
        bool camSleeping = (message.indexOf(":SLEEPING") > 0);
        bool camAbsent = (message.indexOf(":ABSENT") > 0);
        bool camPhone = (message.indexOf(":PHONE_ON") > 0);

        if (camSleeping && !isUserSleeping) {
            isUserSleeping = true; sleepStartTime = millis();
        } else if (!camSleeping && isUserSleeping) {
            isUserSleeping = false;
            if (!redLightActive && !isUserAbsent && !isUserOnPhone) restoreCorrectColor();
        }

        if (camAbsent && !isUserAbsent) {
            isUserAbsent = true; absentStartTime = millis();
        } else if (!camAbsent && isUserAbsent) {
            isUserAbsent = false;
            if (!redLightActive && !isUserSleeping && !isUserOnPhone) restoreCorrectColor();
        }

        if (camPhone && !isUserOnPhone) {
            isUserOnPhone = true; phoneStartTime = millis();
            Serial.println("SYNC: Phone usage detected");
        } else if (!camPhone && isUserOnPhone) {
            isUserOnPhone = false;
            if (!redLightActive && !isUserSleeping && !isUserAbsent) restoreCorrectColor();
        }
    }
}

void processCommand(String command) {
    if (command.indexOf("\"sensitivity\":\"high\"") > 0) distractionThreshold = 30;
    else if (command.indexOf("\"sensitivity\":\"medium\"") > 0) distractionThreshold = 60;
    else if (command.indexOf("\"sensitivity\":\"low\"") > 0) distractionThreshold = 90;

    if (command.indexOf("\"config\":") > 0) {
        if (command.indexOf("\"style\":\"subtle\"") > 0) alertStyle = "subtle";
        else alertStyle = "strong";
        
        if (command.indexOf("\"subtleType\":\"sound\"") > 0) subtleType = "sound";
        else subtleType = "light";
    }

    if (command.indexOf("\"sleepTrig\":true") > 0 || command.indexOf("\"sleepTrig\": true") > 0) sleepTriggerEnabled = true;
    else if (command.indexOf("\"sleepTrig\":false") > 0 || command.indexOf("\"sleepTrig\": false") > 0) sleepTriggerEnabled = false;
    
    if (command.indexOf("\"presenceTrig\":true") > 0 || command.indexOf("\"presenceTrig\": true") > 0) presenceTriggerEnabled = true;
    else if (command.indexOf("\"presenceTrig\":false") > 0 || command.indexOf("\"presenceTrig\": false") > 0) presenceTriggerEnabled = false;

    if (command.indexOf("\"phoneTrig\":true") > 0 || command.indexOf("\"phoneTrig\": true") > 0) phoneTriggerEnabled = true;
    else if (command.indexOf("\"phoneTrig\":false") > 0 || command.indexOf("\"phoneTrig\": false") > 0) phoneTriggerEnabled = false;

    if (command.indexOf("\"timer\":") > 0) {
        int minutesStart = command.indexOf("\"minutes\":") + 10;
        int minutesEnd = command.indexOf(",", minutesStart);
        if (minutesEnd == -1) minutesEnd = command.indexOf("}", minutesStart);

        int secondsStart = command.indexOf("\"seconds\":") + 10;
        int secondsEnd = command.indexOf(",", secondsStart);
        if (secondsEnd == -1) secondsEnd = command.indexOf("}", secondsStart);

        int statusStart = command.indexOf("\"status\":\"") + 10;
        int statusEnd = command.indexOf("\"", statusStart);

        int modeStart = command.indexOf("\"mode\":\"") + 8;
        int modeEnd = command.indexOf("\"", modeStart);

        if (minutesStart > 9 && secondsStart > 9) {
            timerMinutes = command.substring(minutesStart, minutesEnd).toInt();
            timerSeconds = command.substring(secondsStart, secondsEnd).toInt();
        }

        if (statusStart > 9) {
            String newStatus = command.substring(statusStart, statusEnd);
            
            if (newStatus == "running" && sessionStatus != "running") {
                timerActive = true;
                sessionStartTime = millis();
                absentStartTime = millis();
                sleepStartTime = millis();
                phoneStartTime = millis();
                
                if (sessionStatus == "ready") {
                    distractionCount = 0;
                    distractionRate = 0.0;
                }
                
                if (sessionMode == "focus") startFocusMode();
                else startBreakMode();
            } else if (newStatus == "paused" && sessionStatus != "paused") {
                timerActive = false;
                redLightActive = false;
                currentDistractionDuration = 0;
                setPausedMode();
            }
            sessionStatus = newStatus;
        }

        if (modeStart > 7) {
            String newMode = command.substring(modeStart, modeEnd);
            if (newMode != sessionMode) {
                sessionMode = newMode;
                if (sessionStatus == "running") {
                    if (sessionMode == "focus") startFocusMode();
                    else startBreakMode();
                }
            }
        }
        updateLCDDisplay();
    }

    if (command.indexOf("\"on\":false") > 0) {
        turnOffAll();
        redLightActive = false;
        isUserSleeping = false;
        isUserAbsent = false;
        isUserOnPhone = false;
        alertStyle = "strong";
        sessionStatus = "ready";
        distractionCount = 0;
        distractionRate = 0.0;
    }
}

void updateLCDDisplay() {
    if (redLightActive) {
        lcd.clear();
        lcd.setCursor(0, 0);
        lcd.print(" !! REFOCUS !! ");
        lcd.setCursor(0, 1);
        lcd.print("Count: ");
        lcd.print(distractionCount);
        return;
    }

    lcd.clear();
    if (timerActive || sessionStatus == "paused") {
        lcd.setCursor(0, 0);
        lcd.print("Time: ");
        if (timerMinutes < 10) lcd.print("0");
        lcd.print(timerMinutes);
        lcd.print(":");
        if (timerSeconds < 10) lcd.print("0");
        lcd.print(timerSeconds);
    } else {
        lcd.setCursor(0, 0);
        lcd.print("Rikaz Ready");
    }

    lcd.setCursor(0, 1);
    if (sessionStatus == "paused") {
        lcd.print("Session Paused");
    } else if (sessionMode == "break") {
        lcd.print("Mode: Break");
    } else if (sessionMode == "focus") {
        if (currentDistractionDuration > 0) {
            lcd.print("Warn: ");
            lcd.print(currentDistractionDuration/1000);
            lcd.print("s");
        } else {
            lcd.print("D:");
            lcd.print(distractionCount);
            lcd.print(" R:");
            lcd.print(distractionRate, 1);
        }
    }
}

void restoreCorrectColor() {
    if (sessionStatus == "ready" || currentMode == MODE_OFF) setAllLEDs(COLOR_OFF);
    else if (sessionStatus == "paused") setAllLEDs(COLOR_PAUSED);
    else if (sessionMode == "break") setAllLEDs(COLOR_BREAK);
    else if (sessionMode == "focus") setAllLEDs(COLOR_FOCUS);
    else setAllLEDs(COLOR_OFF);
}

void startFocusMode() { currentMode = MODE_FOCUS; setAllLEDs(COLOR_FOCUS); }
void startBreakMode() { currentMode = MODE_BREAK; setAllLEDs(COLOR_BREAK); }
void setPausedMode() { currentMode = MODE_PAUSED; setAllLEDs(COLOR_PAUSED); }
void turnOffAll() { currentMode = MODE_OFF; setAllLEDs(COLOR_OFF); timerActive = false; sessionStatus = "ready"; showWelcomeMessage(); }

void setAllLEDs(CRGB color) { fill_solid(leds, NUM_LEDS, color); FastLED.show(); }

void showWelcomeMessage() { lcd.clear(); lcd.setCursor(0, 0); lcd.print(" Rikaz System"); lcd.setCursor(0, 1); lcd.print(" Ready to Focus"); }

void createCustomChars() {}

void setup() {
    Serial.begin(115200);

    OpenMVSerial.begin(UART_BAUD, SERIAL_8N1, RXD2, TXD2);
    OpenMVSerial.setRxBufferSize(1024);
    OpenMVSerial.setTimeout(50);

    lcd.init();
    lcd.backlight();
    createCustomChars();
    showWelcomeMessage();

    FastLED.addLeds<LED_TYPE, LED_PIN, COLOR_ORDER>(leds, NUM_LEDS);
    FastLED.setBrightness(120);
    setAllLEDs(COLOR_OFF);

    BLEDevice::init("Rikaz-Light");
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());
    BLEService* pService = pServer->createService(SERVICE_UUID);
    pCharacteristic = pService->createCharacteristic(
        CHAR_UUID,
        BLECharacteristic::PROPERTY_READ |
        BLECharacteristic::PROPERTY_WRITE |
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pCharacteristic->setCallbacks(new CharacteristicCallbacks());
    pCharacteristic->addDescriptor(new BLE2902());
    pService->start();

    BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);
    BLEDevice::startAdvertising();
}

void loop() {
    if (OpenMVSerial.available()) {
        String message = OpenMVSerial.readStringUntil('\n');
        processCameraMessage(message);
    }

    handleDistractionLogic();

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
