/*
 * ============================================================================
 * RIKAZ ESP32 FIRMWARE - Light Controller (Release 1)
 * ============================================================================
 * Purpose: Control WS2812B LED strip via BLE
 * * Features:
 * - BLE communication with Flutter app
 * - WS2812B LED control (focus/break modes)
 * - Research-backed colors (bluish white, soft yellow)
 * - Simple, reliable operation
 * * Hardware Connections:
 * - GPIO 5 	→ WS2812B Data In
 * - 5V/GND 	→ Power
 * * Release 2 will add: LCD countdown, OpenMV camera
 * ============================================================================
 */

#include <FastLED.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ============================================================================
// CONFIGURATION
// ============================================================================

// LED Strip Configuration
#define LED_PIN 		5
#define NUM_LEDS 		30 		// Adjust to your strip length
#define LED_TYPE 		WS2812B
#define COLOR_ORDER 	GRB

// BLE Configuration
#define SERVICE_UUID 	"0000ffe0-0000-1000-8000-00805f9b34fb"
#define CHAR_UUID 		"0000ffe1-0000-1000-8000-00805f9b34fb"

// ============================================================================
// GLOBAL OBJECTS
// ============================================================================

CRGB leds[NUM_LEDS];

BLEServer* pServer = nullptr;
BLECharacteristic* pCharacteristic = nullptr;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Session State
enum LightMode {
	MODE_OFF,
	MODE_FOCUS, 		// Bluish white
	MODE_BREAK 		// Soft yellow
};

LightMode currentMode = MODE_OFF;

// ============================================================================
// FUNCTION PROTOTYPES (Fixes 'not declared in this scope' error)
// ============================================================================
void processCommand(String command);

// ============================================================================
// RESEARCH-BACKED COLORS (From your literature review)
// ============================================================================

// Focus Mode: Bluish white (enhances attention)
const CRGB COLOR_FOCUS = CRGB(80, 120, 255); 		

// Break Mode: Soft yellow (supports relaxation & creativity)
const CRGB COLOR_BREAK = CRGB(255, 200, 80); 		

// Off
const CRGB COLOR_OFF = CRGB(0, 0, 0);

// ============================================================================
// BLE CALLBACKS
// ============================================================================

class ServerCallbacks : public BLEServerCallbacks {
	void onConnect(BLEServer* pServer) {
		deviceConnected = true;
		Serial.println("✅ Phone Connected");
	}

	void onDisconnect(BLEServer* pServer) {
		deviceConnected = false;
		Serial.println("❌ Phone Disconnected");
		
		// Restart advertising
		BLEDevice::startAdvertising();
		Serial.println("📡 Restarting BLE advertising...");
	}
};

class CharacteristicCallbacks : public BLECharacteristicCallbacks {
	void onWrite(BLECharacteristic* pCharacteristic) {
		// FIX: The compiler error indicates pCharacteristic->getValue() returns an
		// Arduino 'String', not C++ 'std::string' in this specific environment.
		// We use Arduino 'String' directly for command processing.
		String command = pCharacteristic->getValue();

		if (command.length() > 0) {
			Serial.print("📥 Received: ");
			Serial.println(command); // 'command' is already an Arduino String

			// The 'processCommand' call is now fixed by the prototype above.
			processCommand(command);
		}
	}
};

// ============================================================================
// COMMAND PROCESSING (From Flutter App)
// ============================================================================

void processCommand(String command) {
	// Expected format: {"on":true,"mode":"focus"}
	
	if (command.indexOf("\"on\":true") > 0) {
		if (command.indexOf("\"mode\":\"focus\"") > 0) {
			startFocusMode();
		} else if (command.indexOf("\"mode\":\"break\"") > 0) {
			startBreakMode();
		}
	} 
	else if (command.indexOf("\"on\":false") > 0) {
		turnOffAll();
	}
}

// ============================================================================
// LIGHT CONTROL FUNCTIONS
// ============================================================================

void startFocusMode() {
	currentMode = MODE_FOCUS;
	setAllLEDs(COLOR_FOCUS);
	Serial.println("🔵 Focus Mode - Bluish White");
}

void startBreakMode() {
	currentMode = MODE_BREAK;
	setAllLEDs(COLOR_BREAK);
	Serial.println("🟡 Break Mode - Soft Yellow");
}

void turnOffAll() {
	currentMode = MODE_OFF;
	setAllLEDs(COLOR_OFF);
	Serial.println("⚫ Lights Off");
}

void setAllLEDs(CRGB color) {
	fill_solid(leds, NUM_LEDS, color);
	FastLED.show();
}

// ============================================================================
// SETUP
// ============================================================================

void setup() {
	Serial.begin(115200);
	Serial.println("\n🚀 Rikaz Light System Starting...");
	
	// ===== LED SETUP =====
	FastLED.addLeds<LED_TYPE, LED_PIN, COLOR_ORDER>(leds, NUM_LEDS);
	FastLED.setBrightness(200);
	FastLED.clear();
	FastLED.show();
	Serial.println("✅ WS2812B LED initialized");
	
	// ===== BLE SETUP =====
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
	Serial.println("🎉 System Ready! Open app to connect.");
}

// ============================================================================
// MAIN LOOP
// ============================================================================

void loop() {
	// Handle BLE connection changes
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