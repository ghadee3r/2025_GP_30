#include <FastLED.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <LiquidCrystal_I2C.h>

// ============================================================================
// CONFIGURATION
// ============================================================================

// LED Strip Configuration
#define LED_PIN 		5
#define NUM_LEDS 		30
#define LED_TYPE 		WS2812B
#define COLOR_ORDER 	GRB

// LCD Configuration
#define LCD_ADDRESS 	0x27  // Try 0x3F if 0x27 doesn't work
#define LCD_COLUMNS 	16
#define LCD_ROWS 		2

// BLE Configuration
#define SERVICE_UUID 	"0000ffe0-0000-1000-8000-00805f9b34fb"
#define CHAR_UUID 		"0000ffe1-0000-1000-8000-00805f9b34fb"

// ============================================================================
// GLOBAL OBJECTS
// ============================================================================

CRGB leds[NUM_LEDS];
LiquidCrystal_I2C lcd(LCD_ADDRESS, LCD_COLUMNS, LCD_ROWS);

BLEServer* pServer = nullptr;
BLECharacteristic* pCharacteristic = nullptr;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Session State
enum LightMode {
	MODE_OFF,
	MODE_FOCUS,
	MODE_BREAK,
	MODE_PAUSED
};

LightMode currentMode = MODE_OFF;

// Timer State
int timerMinutes = 0;
int timerSeconds = 0;
bool timerActive = false;
String sessionStatus = "ready";
String sessionMode = "focus";

// ============================================================================
// COLORS
// ============================================================================

const CRGB COLOR_FOCUS = CRGB(250, 252, 255);	// White with hint of blue
const CRGB COLOR_BREAK = CRGB(255, 100, 20);	// Soft yellow
const CRGB COLOR_PAUSED = CRGB(180, 200, 100);	// Soft yellowish-green
const CRGB COLOR_OFF = CRGB(0, 0, 0);

// ============================================================================
// FUNCTION PROTOTYPES
// ============================================================================
void processCommand(String command);
void updateLCDDisplay();
void showWelcomeMessage();
void setAllLEDs(CRGB color);
void startFocusMode();
void startBreakMode();
void setPausedMode();
void turnOffAll();
void showMotivationalMessage();
void showSessionComplete();

// ============================================================================
// BLE CALLBACKS
// ============================================================================

class ServerCallbacks : public BLEServerCallbacks {
	void onConnect(BLEServer* pServer) {
		deviceConnected = true;
		Serial.println("✅ Phone Connected");
		
		lcd.clear();
		lcd.setCursor(0, 0);
		lcd.print("Phone Connected!");
		lcd.setCursor(0, 1);
		lcd.print("Ready for session");
		delay(2000);
		showWelcomeMessage();
	}

	void onDisconnect(BLEServer* pServer) {
		deviceConnected = false;
		Serial.println("❌ Phone Disconnected");
		
		timerActive = false;
		currentMode = MODE_OFF;
		setAllLEDs(COLOR_OFF);
		showWelcomeMessage();
		
		BLEDevice::startAdvertising();
		Serial.println("📡 Restarting BLE advertising...");
	}
};

class CharacteristicCallbacks : public BLECharacteristicCallbacks {
	void onWrite(BLECharacteristic* pCharacteristic) {
		String command = pCharacteristic->getValue();

		if (command.length() > 0) {
			Serial.print("📥 Received: ");
			Serial.println(command);
			processCommand(command);
		}
	}
};

// ============================================================================
// COMMAND PROCESSING
// ============================================================================

void processCommand(String command) {
	Serial.println("🔍 DEBUG: Full command received: " + command);
	
	if (command.indexOf("\"timer\":") > 0) {
		// Parse timer command
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
		
		if (minutesStart > 9 && secondsStart > 9 && statusStart > 9) {
			timerMinutes = command.substring(minutesStart, minutesEnd).toInt();
			timerSeconds = command.substring(secondsStart, secondsEnd).toInt();
			sessionStatus = command.substring(statusStart, statusEnd);
			
			if (modeStart > 7) {
				sessionMode = command.substring(modeStart, modeEnd);
			}
			
			timerActive = (sessionStatus == "running");
			
			// Handle paused state
			if (sessionStatus == "paused") {
				setPausedMode();
			}
			
			Serial.println("⏰ Timer: " + String(timerMinutes) + ":" + 
			              String(timerSeconds) + " (" + sessionStatus + ")");
			updateLCDDisplay();
		}
	} 
	else if (command.indexOf("\"on\":true") > 0) {
		if (command.indexOf("\"mode\":\"focus\"") > 0) {
			startFocusMode();
		} else if (command.indexOf("\"mode\":\"break\"") > 0) {
			startBreakMode();
		}
	} 
	else if (command.indexOf("\"on\":false") > 0) {
		turnOffAll();
	}
	else if (command.indexOf("\"motivation\":") > 0) {
		showMotivationalMessage();
	}
	else if (command.indexOf("\"sessionComplete\":") > 0) {
		showSessionComplete();
	}
}

// ============================================================================
// LIGHT CONTROL FUNCTIONS
// ============================================================================

void startFocusMode() {
	currentMode = MODE_FOCUS;
	setAllLEDs(COLOR_FOCUS);
	sessionMode = "focus";
	Serial.println("⚪ Focus Mode - White with hint of blue");
	updateLCDDisplay();
}

void startBreakMode() {
	currentMode = MODE_BREAK;
	setAllLEDs(COLOR_BREAK);
	sessionMode = "break";
	Serial.println("🟡 Break Mode - Soft Yellow");
	updateLCDDisplay();
}

void setPausedMode() {
	currentMode = MODE_PAUSED;
	setAllLEDs(COLOR_PAUSED);
	Serial.println("🟢 Paused Mode - Yellowish Green");
}

void turnOffAll() {
	currentMode = MODE_OFF;
	setAllLEDs(COLOR_OFF);
	timerActive = false;
	sessionStatus = "ready";
	Serial.println("⚫ Lights Off");
	showWelcomeMessage();
}

void setAllLEDs(CRGB color) {
	fill_solid(leds, NUM_LEDS, color);
	FastLED.show();
}

// ============================================================================
// LCD DISPLAY FUNCTIONS
// ============================================================================

void updateLCDDisplay() {
	lcd.clear();
	
	if (timerActive && (timerMinutes > 0 || timerSeconds > 0)) {
		// Line 1: Timer
		lcd.setCursor(0, 0);
		lcd.print("Time: ");
		if (timerMinutes < 10) lcd.print("0");
		lcd.print(timerMinutes);
		lcd.print(":");
		if (timerSeconds < 10) lcd.print("0");
		lcd.print(timerSeconds);
		
		// Line 2: Mode
		lcd.setCursor(0, 1);
		if (sessionMode == "focus") {
			lcd.print("Mode: FOCUS");
		} else if (sessionMode == "break") {
			lcd.print("Mode: BREAK");
		} else {
			lcd.print("Mode: ACTIVE");
		}
	} else if (sessionStatus == "paused") {
		lcd.setCursor(0, 0);
		lcd.print("Session Paused");
		lcd.setCursor(0, 1);
		if (timerMinutes > 0 || timerSeconds > 0) {
			lcd.print("Time: ");
			if (timerMinutes < 10) lcd.print("0");
			lcd.print(timerMinutes);
			lcd.print(":");
			if (timerSeconds < 10) lcd.print("0");
			lcd.print(timerSeconds);
		} else {
			lcd.print("Press Resume");
		}
	} else {
		showWelcomeMessage();
	}
}

void showWelcomeMessage() {
	lcd.clear();
	lcd.setCursor(0, 0);
	lcd.print("   Rikaz Screen");
	lcd.setCursor(0, 1);
	lcd.print(" Ready to Focus");
}

// ============================================================================
// POSITIVE REINFORCEMENT (AFTER BLOCKS/SESSIONS ONLY)
// ============================================================================

void showMotivationalMessage() {
	lcd.clear();
	lcd.setCursor(0, 0);
	
	int messageType = random(0, 6);
	
	switch(messageType) {
		case 0:
			lcd.print("Great Focus!");
			lcd.setCursor(0, 1);
			lcd.print("Keep it up! :)");
			break;
		case 1:
			lcd.print("Well Done!");
			lcd.setCursor(0, 1);
			lcd.print("Stay focused!");
			break;
		case 2:
			lcd.print("Excellent Work!");
			lcd.setCursor(0, 1);
			lcd.print("You're doing it!");
			break;
		case 3:
			lcd.print("Focus Champion!");
			lcd.setCursor(0, 1);
			lcd.print("Amazing progress");
			break;
		case 4:
			lcd.print("Super Focused!");
			lcd.setCursor(0, 1);
			lcd.print("Keep going!");
			break;
		default:
			lcd.print("You're Awesome!");
			lcd.setCursor(0, 1);
			lcd.print("Stay strong!");
			break;
	}
	
	delay(3000);
	updateLCDDisplay();
}

void showSessionComplete() {
	lcd.clear();
	lcd.setCursor(0, 0);
	lcd.print("Session Done!");
	lcd.setCursor(0, 1);
	lcd.print("Great job! :D");
	
	delay(5000);
	showWelcomeMessage();
}

// ============================================================================
// SETUP
// ============================================================================

void setup() {
	Serial.begin(115200);
	Serial.println("\n🚀 Rikaz Light + LCD System Starting...");
	
	// LCD Setup
	lcd.init();
	lcd.backlight();
	lcd.clear();
	lcd.setCursor(0, 0);
	lcd.print("Initializing...");
	lcd.setCursor(0, 1);
	lcd.print("Please wait");
	Serial.println("✅ LCD initialized");
	
	// LED Setup
	FastLED.addLeds<LED_TYPE, LED_PIN, COLOR_ORDER>(leds, NUM_LEDS);
	FastLED.setBrightness(120);  // Lower brightness
	FastLED.clear();
	FastLED.show();
	Serial.println("✅ WS2812B LED initialized");
	
	// BLE Setup
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
	pAdvertising->setMinPreferred(0x12);
	BLEDevice::startAdvertising();
	
	Serial.println("✅ BLE advertising as 'Rikaz-Light'");
	
	delay(2000);
	showWelcomeMessage();
	
	Serial.println("🎉 System Ready! Open app to connect.");
}

// ============================================================================
// MAIN LOOP
// ============================================================================

void loop() {
	if (!deviceConnected && oldDeviceConnected) {
		delay(500);
		pServer->startAdvertising();
		Serial.println("📡 Restarting advertising");
		oldDeviceConnected = deviceConnected;
	}
	
	if (deviceConnected && !oldDeviceConnected) {
		oldDeviceConnected = deviceConnected;
	}
	
	delay(10);
}
