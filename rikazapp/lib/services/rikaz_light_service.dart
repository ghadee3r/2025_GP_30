// ============================================================================
// FILE: rikaz_light_service.dart
// PURPOSE: Bluetooth communication with Rikaz Light device
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class RikazDevice {
  final String id;
  final String name;
  final int rssi;
  final BluetoothDevice device;

  RikazDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.device,
  });
}

class RikazLightService {
  static BluetoothDevice? _connectedDevice;
  static BluetoothCharacteristic? _writeCharacteristic;
  
  // Rikaz BLE Service UUID
  static final Guid _rikazServiceUuid = Guid("0000ffe0-0000-1000-8000-00805f9b34fb");
  static final Guid _rikazCharacteristicUuid = Guid("0000ffe1-0000-1000-8000-00805f9b34fb");

  // Check and request permissions
  static Future<bool> checkPermissions() async {
    // Check location service first
    bool serviceEnabled = await Permission.location.serviceStatus.isEnabled;
    if (!serviceEnabled) {
      debugPrint("❌ Location services disabled");
      return false;
    }

    // Request permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);
    
    if (!allGranted) {
      debugPrint("❌ Permissions denied");
    }
    
    return allGranted;
  }

  // Scan for Rikaz devices
  static Future<List<RikazDevice>> scanForDevices({Duration timeout = const Duration(seconds: 10)}) async {
    List<RikazDevice> foundDevices = [];
    
    try {
      if (await FlutterBluePlus.isSupported == false) {
        debugPrint("❌ Bluetooth not supported");
        return foundDevices;
      }

      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        debugPrint("❌ Bluetooth is OFF");
        return foundDevices;
      }

      if (!await checkPermissions()) {
        debugPrint("❌ Permissions denied or location disabled");
        return foundDevices;
      }

      debugPrint("🔍 Scanning for Rikaz devices...");

      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );

      await Future.delayed(timeout);
      
      var results = FlutterBluePlus.lastScanResults;
      
      for (ScanResult result in results) {
        String deviceName = result.device.platformName;
        
        debugPrint("📱 Found: $deviceName (${result.rssi} dBm)");
        
        // Look for "Rikaz" in device name
        if (deviceName.toLowerCase().contains('rikaz') ||
            result.advertisementData.serviceUuids.contains(_rikazServiceUuid)) {
          
          bool exists = foundDevices.any((d) => d.id == result.device.remoteId.toString());
          
          if (!exists) {
            foundDevices.add(RikazDevice(
              id: result.device.remoteId.toString(),
              name: deviceName.isNotEmpty ? deviceName : "Rikaz Device",
              rssi: result.rssi,
              device: result.device,
            ));
            debugPrint("✅ Added Rikaz device: $deviceName");
          }
        }
      }

      await FlutterBluePlus.stopScan();

      debugPrint("✅ Scan complete. Found ${foundDevices.length} device(s)");
      
      if (foundDevices.isEmpty) {
        debugPrint("💡 Tip: Device should be named 'Rikaz-Light'");
      }
      
      return foundDevices;

    } catch (e) {
      debugPrint("❌ Scan Error: $e");
      await FlutterBluePlus.stopScan();
      return foundDevices;
    }
  }

  // Connect to device
  static Future<bool> connectToDevice(RikazDevice device) async {
    try {
      debugPrint("🔌 Connecting to ${device.name}...");

      await device.device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device.device;

      debugPrint("✅ Connected to ${device.name}");

      List<BluetoothService> services = await device.device.discoverServices();
      
      for (BluetoothService service in services) {
        if (service.uuid == _rikazServiceUuid) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid == _rikazCharacteristicUuid) {
              _writeCharacteristic = characteristic;
              debugPrint("✅ Found Rikaz characteristic");
              return true;
            }
          }
        }
      }

      debugPrint("⚠️ Rikaz service not found");
      return false;

    } catch (e) {
      debugPrint("❌ Connection Error: $e");
      return false;
    }
  }

  // Disconnect
  static Future<void> disconnect() async {
    try {
      if (_connectedDevice != null) {
        // Use device.disconnect() to explicitly disconnect
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
        _writeCharacteristic = null;
        debugPrint("🔌 Disconnected");
      }
    } catch (e) {
      debugPrint("❌ Disconnect Error: $e");
    }
  }

  // Check connection
  static Future<bool> isConnected() async {
    if (_connectedDevice == null) return false;
    
    try {
      // Stream is used here to get the current state without triggering new events
      var state = await _connectedDevice!.connectionState.first;
      return state == BluetoothConnectionState.connected;
    } catch (e) {
      // If the device object itself is invalid, assume disconnected
      return false;
    }
  }

  // Send BLE command
  static Future<bool> sendCommand(String jsonCommand) async {
    if (_writeCharacteristic == null) {
      debugPrint("❌ No characteristic available");
      return false;
    }

    try {
      List<int> bytes = utf8.encode(jsonCommand);
      await _writeCharacteristic!.write(bytes, withoutResponse: false);
      debugPrint("📤 Sent: $jsonCommand");
      return true;
    } on FlutterBluePlusException catch (e) {
      // Capture the specific exception that occurs when the link is lost during write
      debugPrint("❌ Write Error: FlutterBluePlusException: $e");
      return false; // Return false on write failure
    } catch (e) {
      debugPrint("❌ Write Error: $e");
      return false;
    }
  }

  // === LIGHT CONTROL METHODS ===

  // Focus Mode - Bluish white
  static Future<bool> setFocusLight() async {
    final command = jsonEncode({
      "on": true,
      "mode": "focus"
    });
    
    bool success = await sendCommand(command);
    if (success) {
      debugPrint("🔵 Focus light activated");
    }
    return success;
  }

  // Break Mode - Soft yellow
  static Future<bool> setBreakLight() async {
    final command = jsonEncode({
      "on": true,
      "mode": "break"
    });
    
    bool success = await sendCommand(command);
    if (success) {
      debugPrint("🟡 Break light activated");
    }
    return success;
  }

  // Turn off
  static Future<bool> turnOff() async {
    final command = jsonEncode({
      "on": false
    });
    
    bool success = await sendCommand(command);
    if (success) {
      debugPrint("⚫ Light turned off");
    }
    return success;
  }
}