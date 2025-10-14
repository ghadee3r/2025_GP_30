import 'package:flutter/material.dart';

class CustomPage extends StatefulWidget {
  const CustomPage({super.key});

  @override
  State<CustomPage> createState() => _CustomPageState();
}

class _CustomPageState extends State<CustomPage> {
  bool isLoading = false;
  double sessionDuration = 70;
  bool isConfigurationOpen = false;
  bool isCameraDetectionEnabled = true;
  double sensitivity = 0.5;
  String notificationStyle = 'Both';

  void resetForm() {
    setState(() {
      sessionDuration = 70;
      isConfigurationOpen = false;
      isCameraDetectionEnabled = true;
      sensitivity = 0.5;
      notificationStyle = 'Both';
    });
  }

  void handleStartSessionPress() {
    Navigator.pushNamed(
      context,
      '/session',
      arguments: {
        'sessionType': 'custom',
        'duration': sessionDuration.toInt().toString(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text('Home > Set Session',
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 10),
                  const Text('Custom Session',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('Set your own timing',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 25),

                  // Session Duration
                  const Text('Session Duration',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      '${sessionDuration.toInt()}:00',
                      style: const TextStyle(
                          fontSize: 48, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Text('No Breaks',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Slider(
                    value: sessionDuration,
                    min: 25,
                    max: 120,
                    divisions: 95,
                    label: '${sessionDuration.toInt()} min',
                    onChanged: (v) => setState(() => sessionDuration = v),
                    activeColor: Colors.black,
                    inactiveColor: Colors.grey[300],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('25 Minutes', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('120 Minutes', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Rikaz Tools Configuration
                  GestureDetector(
                    onTap: () =>
                        setState(() => isConfigurationOpen = !isConfigurationOpen),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Rikaz Tools Configuration',
                              style: TextStyle(color: Colors.black)),
                          Text(isConfigurationOpen ? '▲' : '▼',
                              style: const TextStyle(fontSize: 18, color: Colors.black)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (isConfigurationOpen) _configurationMenu(),
                  const SizedBox(height: 100),
                ],
              ),
            ),

            // Start button
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: ElevatedButton(
                onPressed: isLoading ? null : handleStartSessionPress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Start Session',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Configuration section widget
  Widget _configurationMenu() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Camera
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Camera Detection', style: TextStyle(fontSize: 16)),
              Switch(
                value: isCameraDetectionEnabled,
                onChanged: (v) => setState(() => isCameraDetectionEnabled = v),
                activeColor: Colors.black,
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Triggers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Triggers', style: TextStyle(fontSize: 16)),
              Row(
                children: List.generate(
                  3,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 2),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Sensitivity
          Row(
            children: [
              const Text('Sensitivity', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              const Text('Low', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: sensitivity,
                  min: 0,
                  max: 1,
                  divisions: 2,
                  label: sensitivity == 0
                      ? 'Low'
                      : sensitivity == 0.5
                          ? 'Medium'
                          : 'High',
                  onChanged: (v) => setState(() => sensitivity = v),
                  activeColor: Colors.black,
                  inactiveColor: Colors.grey[300],
                ),
              ),
              const Text('High', style: TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 15),

          // Notification
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notification', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Light', 'Sound', 'Both'].map((option) {
                  final isSelected = notificationStyle == option;
                  return GestureDetector(
                    onTap: () => setState(() => notificationStyle = option),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: isSelected ? Colors.black : Colors.grey),
                            color:
                                isSelected ? Colors.black : Colors.transparent,
                          ),
                        ),
                        Text(option),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
