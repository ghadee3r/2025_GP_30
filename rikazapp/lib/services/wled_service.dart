// ============================================================================
// FILE: wled_service.dart
// PURPOSE: Service to communicate with WLED device for light control
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

class WledService {
  // --------------------IMPORTANT---------------------
  // --------CHANGE THE IP BASED ON THE DEVICE---------
  static const String WLED_STATIC_IP = '172.20.10.2';
  
  // --- Connection Test (Called by SlideAction) ---
  Future<bool> testConnection() async {
    final url = Uri.http(WLED_STATIC_IP, '/json/info');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200 && response.body.contains('"ver"')) {
        print('✅ WLED Connection Test: SUCCESS');
        return true;
      }
      print('❌ WLED Connection Test: FAILED (Invalid response)');
      return false;
    } catch (e) {
      print('❌ WLED Connection Error: $e');
      return false;
    }
  }

  // --- Turn Light ON for Focus Session ---
  Future<void> startFocusLight() async {
    final url = Uri.http(WLED_STATIC_IP, '/json/state');
    final state = {
      "on": true,
      "ps": 1, // Preset 1: Focus mode (bluish white)
      "transition": 7
    };
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(state),
      ).timeout(const Duration(seconds: 2));
      
      if (response.statusCode == 200) {
        print('✅ WLED: Focus light started (Preset 1)');
      } else {
        print('❌ WLED: Failed to start focus light (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('❌ WLED: Error starting focus light: $e');
    }
  }

  // --- Change to Break Mode Light ---
  Future<void> startBreakLight() async {
    final url = Uri.http(WLED_STATIC_IP, '/json/state');
    final state = {
      "on": true,
      "ps": 2, // Preset 2: Break mode (soft yellow)
      "transition": 10
    };
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(state),
      ).timeout(const Duration(seconds: 2));
      
      if (response.statusCode == 200) {
        print('✅ WLED: Break light started (Preset 2)');
      } else {
        print('❌ WLED: Failed to start break light (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('❌ WLED: Error starting break light: $e');
    }
  }

  // --- Turn Light OFF ---
  Future<void> stopLight() async {
    final url = Uri.http(WLED_STATIC_IP, '/json/state');
    final state = {
      "on": false,
      "transition": 10
    };
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(state),
      ).timeout(const Duration(seconds: 2));
      
      if (response.statusCode == 200) {
        print('✅ WLED: Light turned off');
      } else {
        print('❌ WLED: Failed to turn off light (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('❌ WLED: Error turning off light: $e');
    }
  }

  // --- Distraction Alert (Cyan pulse) ---
  Future<void> triggerDistractionAlert() async {
    final url = Uri.http(WLED_STATIC_IP, '/json/state');
    final state = {
      "on": true,
      "ps": 3, // Preset 3: Distraction alert (cyan)
      "transition": 5
    };
    
    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(state),
      ).timeout(const Duration(seconds: 2));
      print('✅ WLED: Distraction alert triggered (Preset 3)');
      
      // Return to focus mode after 3 seconds
      await Future.delayed(const Duration(seconds: 3));
      await startFocusLight();
    } catch (e) {
      print('❌ WLED: Error triggering distraction alert: $e');
    }
  }
}