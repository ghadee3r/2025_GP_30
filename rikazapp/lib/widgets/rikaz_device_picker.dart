// ============================================================================
// FILE: rikaz_device_picker.dart
// PURPOSE: UI for scanning and selecting Rikaz devices
// ============================================================================

import 'package:flutter/material.dart';
import '/services/rikaz_light_service.dart';

class RikazDevicePicker extends StatefulWidget {
  const RikazDevicePicker({super.key});

  @override
  State<RikazDevicePicker> createState() => _RikazDevicePickerState();
}

class _RikazDevicePickerState extends State<RikazDevicePicker> {
  List<RikazDevice> _devices = [];
  bool _isScanning = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _devices = [];
    });

    try {
      final devices = await RikazLightService.scanForDevices(
        timeout: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _devices = devices;
          _isScanning = false;
          
          if (devices.isEmpty) {
            _errorMessage = 'No Rikaz devices found.\n\n'
                'Make sure:\n'
                '• Device is powered on\n'
                '• Bluetooth is enabled\n'
                '• Device is nearby\n'
                '• Location is ON\n\n'
                'Device name: "Rikaz-Light"';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          
          if (e.toString().contains('Location')) {
            _errorMessage = 'Location Required!\n\n'
                'Enable Location in phone settings, then try again.';
          } else {
            _errorMessage = 'Scan failed: $e';
          }
        });
      }
    }
  }

  Future<void> _connectToDevice(RikazDevice device) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Connecting to ${device.name}...'),
          ],
        ),
      ),
    );

    final success = await RikazLightService.connectToDevice(device);

    if (mounted) {
      Navigator.pop(context);

      if (success) {
        Navigator.pop(context, device);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to ${device.name}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.7,
          maxWidth: screenWidth * 0.9,
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.bluetooth_searching, color: Color(0xFF7A68FF), size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Select Rikaz Device',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF30304D),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Scanning
            if (_isScanning)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFF7A68FF)),
                    SizedBox(height: 12),
                    Text(
                      'Scanning for devices...',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

            // Error
            if (_errorMessage != null && !_isScanning)
              Flexible(
                child: SingleChildScrollView(
                  child: Container(
                    padding: EdgeInsets.all(16),
                    margin: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.warning_amber_rounded, 
                          color: Colors.orange.shade700, size: 40),
                        SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Device list
            if (_devices.isNotEmpty && !_isScanning)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    return _buildDeviceTile(device, screenWidth);
                  },
                ),
              ),

            // Rescan
            if (!_isScanning)
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: OutlinedButton.icon(
                  onPressed: _startScan,
                  icon: Icon(Icons.refresh),
                  label: Text('Scan Again'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF7A68FF),
                    side: BorderSide(color: Color(0xFF7A68FF)),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTile(RikazDevice device, double screenWidth) {
    int signalBars = 0;
    if (device.rssi > -60) signalBars = 4;
    else if (device.rssi > -70) signalBars = 3;
    else if (device.rssi > -80) signalBars = 2;
    else signalBars = 1;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _connectToDevice(device),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF7A68FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.lightbulb,
                  color: Color(0xFF7A68FF),
                  size: 28,
                ),
              ),
              SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF30304D),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${device.rssi} dBm',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              Row(
                children: List.generate(4, (index) {
                  return Container(
                    width: 4,
                    height: 8 + (index * 4.0),
                    margin: EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: index < signalBars 
                        ? Color(0xFF7A68FF) 
                        : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}