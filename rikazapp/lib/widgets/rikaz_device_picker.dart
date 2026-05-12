// ============================================================================
// FILE: rikaz_device_picker.dart
// PURPOSE: UI for scanning and selecting Rikaz devices
// UPDATED: Matched to the new "Dreamy" aesthetic (Colors, Glassmorphism, Typography)
// ============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import '/services/rikaz_light_service.dart';

// =============================================================================
// DREAMY THEME DEFINITIONS
// =============================================================================
const Color dfNavyIndigo = Color(0xFF1B2536);
const Color dfTealCyan = Color(0xFF68C29D); 
const Color secondaryTextGrey = Color(0xFF8B95A5);
const Color errorIndicatorRed = Color(0xFFE57373);
const Color primaryBackgroundTop = Color(0xFFF4F7F9);

List<BoxShadow> get subtleShadow => [
      BoxShadow(
        color: dfNavyIndigo.withOpacity(0.04),
        blurRadius: 30,
        offset: const Offset(0, 10),
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
                '• Location is ON';
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
      barrierColor: dfNavyIndigo.withOpacity(0.4),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: dfNavyIndigo.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    color: dfTealCyan,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Connecting to ${device.name}...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: dfNavyIndigo,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final success = await RikazLightService.connectToDevice(device);

    if (mounted) {
      Navigator.pop(context); // Remove connecting dialog

      if (success) {
        Navigator.pop(context, device); // Return device on success
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to connect to ${device.name}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: errorIndicatorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
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

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.7,
            maxWidth: screenWidth * 0.9,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: dfNavyIndigo.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Header ---
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: dfTealCyan.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bluetooth_searching_rounded,
                        color: dfTealCyan,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Select Hardware',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: dfNavyIndigo,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    _InteractivePill(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: secondaryTextGrey.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: secondaryTextGrey,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: primaryBackgroundTop, thickness: 1.5),

              // --- Content Area ---
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Scanning Indicator
                      if (_isScanning)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              const SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                  color: dfTealCyan,
                                  strokeWidth: 3,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Scanning for devices...',
                                style: TextStyle(
                                  color: secondaryTextGrey.withOpacity(0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Error Message
                      if (_errorMessage != null && !_isScanning)
                        Container(
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: errorIndicatorRed.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: errorIndicatorRed.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: errorIndicatorRed.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: errorIndicatorRed,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: errorIndicatorRed,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Device List
                      if (_devices.isNotEmpty && !_isScanning)
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _devices.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            return _buildDeviceTile(device);
                          },
                        ),
                    ],
                  ),
                ),
              ),

              // --- Bottom Action Area ---
              if (!_isScanning)
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: dfNavyIndigo.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: _InteractivePill(
                    onTap: _startScan,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: dfTealCyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: dfTealCyan.withOpacity(0.3), width: 1.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh_rounded, color: dfTealCyan, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Scan Again',
                            style: TextStyle(
                              color: dfTealCyan,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceTile(RikazDevice device) {
    int signalBars = 0;
    if (device.rssi > -60) signalBars = 4;
    else if (device.rssi > -70) signalBars = 3;
    else if (device.rssi > -80) signalBars = 2;
    else signalBars = 1;

    return _InteractivePill(
      onTap: () => _connectToDevice(device),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primaryBackgroundTop, width: 1.5),
          boxShadow: subtleShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Device icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dfTealCyan.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.settings_remote_rounded,
                  color: dfTealCyan,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Device info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: dfNavyIndigo,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.signal_cellular_alt_rounded,
                          size: 14,
                          color: secondaryTextGrey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${device.rssi} dBm',
                          style: const TextStyle(
                            fontSize: 12,
                            color: secondaryTextGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Signal strength bars
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(4, (index) {
                  return Container(
                    width: 4,
                    height: 8 + (index * 4.0),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: index < signalBars 
                        ? dfTealCyan 
                        : secondaryTextGrey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: secondaryTextGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- SHARED SQUISH PHYSICS COMPONENT ---
class _InteractivePill extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _InteractivePill({required this.child, required this.onTap});
  
  @override
  State<_InteractivePill> createState() => _InteractivePillState();
}

class _InteractivePillState extends State<_InteractivePill> {
  bool _isPressed = false;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) { setState(() => _isPressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0, 
        duration: const Duration(milliseconds: 150), 
        curve: Curves.easeOutCubic, 
        child: widget.child
      ),
    );
  }
}