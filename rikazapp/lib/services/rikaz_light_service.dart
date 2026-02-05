// ============================================================================
// FILE: rikaz_light_service.dart
// PURPOSE: Bluetooth communication with Rikaz Light device + Camera monitoring
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
  static StreamSubscription? _notificationSubscription;
  
  // Callbacks
  static Function(String status)? onCameraStatusChanged;
  static Function(int count)? onDistractionDetected;
  
  // Rikaz BLE Service UUID
  static final Guid _rikazServiceUuid = Guid("0000ffe0-0000-1000-8000-00805f9b34fb");
  static final Guid _rikazCharacteristicUuid = Guid("0000ffe1-0000-1000-8000-00805f9b34fb");

  // Check and request permissions
  static Future<bool> checkPermissions() async {
    bool serviceEnabled = await Permission.location.serviceStatus.isEnabled;
    if (!serviceEnabled) {
      debugPrint("❌ Location services disabled");
      return false;
    }

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

  // Connect to device and setup notifications
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
              
              // Enable notifications
              await _setupNotifications(characteristic);
              
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

  // Setup BLE notifications to receive camera status and distraction events
  static Future<void> _setupNotifications(BluetoothCharacteristic characteristic) async {
    try {
      await characteristic.setNotifyValue(true);
      
      _notificationSubscription = characteristic.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          try {
            String message = utf8.decode(value);
            debugPrint("📩 Notification received: $message");
            
            // Parse JSON
            final data = jsonDecode(message);
            
            // Handle camera status updates
            if (data.containsKey('cameraStatus')) {
              String status = data['cameraStatus'];
              debugPrint("📷 Camera status: $status");
              if (onCameraStatusChanged != null) {
                onCameraStatusChanged!(status);
              }
            }
            
            // Handle distraction events
            if (data.containsKey('distraction')) {
              int count = data['count'] ?? 0;
              debugPrint("🚨 Distraction detected! Count: $count");
              if (onDistractionDetected != null) {
                onDistractionDetected!(count);
              }
            }
          } catch (e) {
            debugPrint("❌ Error parsing notification: $e");
          }
        }
      });
      
      debugPrint("✅ Notifications enabled");
    } catch (e) {
      debugPrint("❌ Failed to enable notifications: $e");
    }
  }

  // Disconnect
  static Future<void> disconnect() async {
    try {
      await _notificationSubscription?.cancel();
      _notificationSubscription = null;
      
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
        _writeCharacteristic = null;
        debugPrint("🔌 Disconnected");
      }
      
      // Reset callbacks
      onCameraStatusChanged = null;
      onDistractionDetected = null;
    } catch (e) {
      debugPrint("❌ Disconnect Error: $e");
    }
  }

  // Check connection
  static Future<bool> isConnected() async {
    if (_connectedDevice == null) return false;
    
    try {
      var state = await _connectedDevice!.connectionState.first;
      return state == BluetoothConnectionState.connected;
    } catch (e) {
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
      debugPrint("❌ Write Error: FlutterBluePlusException: $e");
      return false;
    } catch (e) {
      debugPrint("❌ Write Error: $e");
      return false;
    }
  }

  // === LIGHT CONTROL METHODS ===

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

  // === CAMERA CONTROL METHODS ===

  static Future<bool> enableCameraDetection({
    required String sensitivity,
    required String notificationStyle,
  }) async {
    final command = jsonEncode({
      "cameraDetection": true,
      "sensitivity": sensitivity,
      "notificationStyle": notificationStyle,
    });
    
    bool success = await sendCommand(command);
    if (success) {
      debugPrint("📷 Camera detection enabled");
    }
    return success;
  }

  static Future<bool> disableCameraDetection() async {
    final command = jsonEncode({
      "cameraDetection": false
    });
    
    bool success = await sendCommand(command);
    if (success) {
      debugPrint("📷 Camera detection disabled");
    }
    return success;
  }

  static Future<bool> requestCameraStatus() async {
    final command = jsonEncode({
      "requestCameraStatus": true
    });
    
    return await sendCommand(command);
  }
}