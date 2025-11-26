// ============================================================================
// FILE: rikaz_device_picker.dart
// PURPOSE: UI for scanning and selecting Rikaz devices
// UPDATED: Matching SetSession theme
// ============================================================================

import 'package:flutter/material.dart';
import '/services/rikaz_light_service.dart';

// =============================================================================
// THEME DEFINITIONS - Matching SetSession
// =============================================================================

// Primary color palette
const Color dfDeepTeal = Color(0xFF175B73); 
const Color dfTealCyan = Color(0xFF287C85); 
const Color dfLightSeafoam = Color(0xFF87ACA3); 
const Color dfDeepBlue = Color(0xFF162893); 
const Color dfNavyIndigo = Color(0xFF0C1446); 

// Primary theme colors
const Color primaryThemeColor = dfDeepTeal;
const Color accentThemeColor = dfTealCyan;
const Color lightestAccentColor = dfLightSeafoam;

// Background colors
const Color primaryBackground = Color(0xFFF7F7F7);
const Color cardBackground = Color(0xFFFFFFFF);

// Text colors
const Color primaryTextDark = dfNavyIndigo;
const Color secondaryTextGrey = Color(0xFF6B6B78);

// Error/alert color
const Color errorIndicatorRed = Color(0xFFE57373);

// Standard border radius for cards
const double cardBorderRadius = 16.0;

// Standard shadow for elevated cards
List<BoxShadow> get subtleShadow => [
      BoxShadow(
        color: dfNavyIndigo.withOpacity(0.08),
        blurRadius: 10,
        offset: const Offset(0, 5),
      ),
    ];

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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardBorderRadius),
        ),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: accentThemeColor,
                strokeWidth: 3,
              ),
              SizedBox(height: 20),
              Text(
                'Connecting to ${device.name}...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryTextDark,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Failed to connect to ${device.name}'),
                ),
              ],
            ),
            backgroundColor: errorIndicatorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
        borderRadius: BorderRadius.circular(cardBorderRadius),
      ),
      backgroundColor: cardBackground,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.7,
          maxWidth: screenWidth * 0.9,
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentThemeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.bluetooth_searching,
                    color: accentThemeColor,
                    size: 28,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Select Rikaz Device',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryTextDark,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: secondaryTextGrey),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
            SizedBox(height: 20),

            // Scanning indicator
            if (_isScanning)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: accentThemeColor,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Scanning for devices...',
                      style: TextStyle(
                        color: secondaryTextGrey,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // Error message
            if (_errorMessage != null && !_isScanning)
              Flexible(
                child: SingleChildScrollView(
                  child: Container(
                    padding: EdgeInsets.all(16),
                    margin: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.orange.shade50,
                          Colors.orange.shade100.withOpacity(0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade700,
                          size: 40,
                        ),
                        SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 14,
                            height: 1.4,
                          ),
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

            // Scan again button
            if (!_isScanning)
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: OutlinedButton.icon(
                  onPressed: _startScan,
                  icon: Icon(Icons.refresh, size: 20),
                  label: Text(
                    'Scan Again',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentThemeColor,
                    side: BorderSide(color: accentThemeColor, width: 1.5),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: subtleShadow,
        border: Border.all(
          color: accentThemeColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _connectToDevice(device),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Device icon
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentThemeColor,
                        accentThemeColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.lightbulb_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),

                // Device info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryTextDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.signal_cellular_alt,
                            size: 14,
                            color: secondaryTextGrey,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${device.rssi} dBm',
                            style: TextStyle(
                              fontSize: 13,
                              color: secondaryTextGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Signal strength bars
                Row(
                  children: List.generate(4, (index) {
                    return Container(
                      width: 4,
                      height: 8 + (index * 4.0),
                      margin: EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: index < signalBars 
                          ? accentThemeColor
                          : secondaryTextGrey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
                SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: secondaryTextGrey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}