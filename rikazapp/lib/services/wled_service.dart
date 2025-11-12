import 'dart:convert';
import 'package:http/http.dart' as http;

class WledService {
  // --------------------IMPORTANT---------------------
  // --------CHANGE THE IP BASED ON THE DEVICE---------
  static const String WLED_STATIC_IP = '192.168.0.122';
  
  // --- Connection Test (Called by SlideAction) ---
  Future<bool> testConnection() async {
    final url = Uri.http(WLED_STATIC_IP, '/json/info');
    try {
      // Send a cheap GET request to check connectivity
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      
      // WLED API responds with status 200 and a body containing "ver" (version)
      if (response.statusCode == 200 && response.body.contains('"ver"')) {
        return true;
      }
      return false;
    } catch (e) {
      print('WLED Connection Error: $e');
      return false;
    }
  }

  // --- Command Sending (Called by SessionPage) ---
  Future<void> sendCommand(bool startSession) async {
    final url = Uri.http(WLED_STATIC_IP, '/json/state');

    final Map<String, dynamic> state;

    if (startSession) {
      // Command to turn ON the light using WLED Preset ID 1
      state = {
        "on": true,
        "ps": 1, // Change this number (1) if you use a different WLED Preset ID
        "transition": 7 // 0.7 seconds transition
      };
      print('Sending FOCUS_START command (Preset 1).');

    } else {
      // Command to turn OFF the light
      state = {
        "on": false,
        "transition": 10 // 1 second fade out
      };
      print('Sending FOCUS_STOP command.');
    }

    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(state),
      ).timeout(const Duration(seconds: 2));
    } catch (e) {
      print('Failed to send WLED command: $e');
    }
  }
}