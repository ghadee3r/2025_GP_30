import 'package:flutter/material.dart';

class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  String duration = '25min';
  double numberOfBlocks = 4;
  bool isConfigurationOpen = false;
  bool isCameraDetectionEnabled = true;
  double sensitivity = 0.5;
  String notificationStyle = 'Both';

  void handleStartPomodoroPress() {
    Navigator.pushNamed(
      context,
      '/session',
      arguments: {
        'sessionType': 'pomodoro',
        'duration': duration,
        'numberOfBlocks': numberOfBlocks.toInt().toString(),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Home > Set Session',
                          style: TextStyle(fontSize: 14, color: Colors.grey)),
                      SizedBox(height: 10),
                      Text('Pomodoro Session',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('Configure your structured focus routine',
                          style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Duration Options
                  const Text('Duration Options',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _durationOption('25min', '+ 5 min break'),
                  _durationOption('50min', '+ 10 min break'),

                  const SizedBox(height: 25),

                  // Number of Blocks
                  const Text('Number of Blocks',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      numberOfBlocks.toInt().toString(),
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Slider(
                    value: numberOfBlocks,
                    min: 1,
                    max: 8,
                    divisions: 7,
                    label: '${numberOfBlocks.toInt()}',
                    onChanged: (v) => setState(() => numberOfBlocks = v),
                    activeColor: Colors.black,
                    inactiveColor: Colors.grey[300],
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Blocks represent how many Pomodoro cycles you want to repeat.\n'
                      'One block = one focus session followed by its break.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Configuration dropdown
                  GestureDetector(
                    onTap: () => setState(() => isConfigurationOpen = !isConfigurationOpen),
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

            // Start button (fixed bottom)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: ElevatedButton(
                onPressed: handleStartPomodoroPress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Start Session',
                  style: TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Duration Option Widget
  Widget _durationOption(String label, String breakText) {
    final isSelected = duration == label;
    return GestureDetector(
      onTap: () => setState(() => duration = label),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? Colors.black : Colors.grey.shade300, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? Colors.black : Colors.grey),
                color: isSelected ? Colors.black : Colors.transparent,
              ),
            ),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 16, color: Colors.black)),
            ),
            Text(breakText, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // Configuration Menu Widget
  Widget _configurationMenu() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
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
                activeThumbColor: Colors.black,
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Triggers (dummy boxes)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Triggers', style: TextStyle(fontSize: 16)),
              Row(
                children: List.generate(
                  3,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 22,
                    height: 22,
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

          // Notification Style
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
