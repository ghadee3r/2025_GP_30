import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isLoading = false;
  String selectedPreset = 'Choose Preset';
  String selectedMode = 'Pomodoro Mode';

  final presets = ['Deep Work', 'Morning Focus', 'Study Session'];

  void handleConnect() async {
    setState(() => isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => isLoading = false);
  }

  // --- FIXED FUNCTION START ---
  void handleSetSession() {
    // Determine the route name based on the selected mode
    String routeName;
    
    if (selectedMode == "Pomodoro Mode") {
      // Assuming you have a named route '/pomodoro'
      routeName = '/pomodoro';
    } else { // This covers 'Custom Mode'
      // Assuming you have a named route '/custom'
      routeName = '/custom';
    }

    debugPrint('Navigating to $routeName');
    
    // Perform the actual navigation using the determined routeName
    // NOTE: For this to work, you must register '/pomodoro' and '/custom' 
    // in your MaterialApp's `routes` property or your routing package (like GoRouter).
    Navigator.of(context).pushNamed(routeName); 
  }
  // --- FIXED FUNCTION END ---

  void handlePresetSelect(String preset) {
    setState(() => selectedPreset = preset);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currentDate = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F2E9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const CircleAvatar(
                    radius: 25,
                    backgroundImage: NetworkImage('https://via.placeholder.com/50'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Welcome back, User!',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Ready for a productive day?',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  const CircleAvatar(
                    radius: 25,
                    backgroundImage: NetworkImage(''),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Connect card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Connect Rikaz Tools',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                        'Connect to unlock custom presets and advanced features',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: isLoading ? null : handleConnect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5353),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Connect',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Start focus section
              const Text('Start Focus Session',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // Dropdown for presets
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  builder: (_) => ListView(
                    shrinkWrap: true,
                    children: presets
                        .map((p) => ListTile(
                              title: Text(p),
                              onTap: () => handlePresetSelect(p),
                            ))
                        .toList(),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE6E2DC)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(selectedPreset,
                          style: const TextStyle(fontSize: 16, color: Colors.black)),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Modes
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => selectedMode = 'Pomodoro Mode'),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selectedMode == 'Pomodoro Mode'
                              ? const Color(0xFFE7B7A6)
                              : const Color(0xFFEED0C5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selectedMode == 'Pomodoro Mode'
                                ? const Color(0xFFD8A594)
                                : const Color(0xFFE6E2DC),
                            width: 2,
                          ),
                        ),
                        child: const Column(
                          children: [
                            Text('Pomodoro Mode',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                            Text('Structured focus and break sessions',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => selectedMode = 'Custom Mode'),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selectedMode == 'Custom Mode'
                              ? const Color(0xFFB7C88A)
                              : const Color(0xFFC9D8A6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selectedMode == 'Custom Mode'
                                ? const Color(0xFFA7B97A)
                                : const Color(0xFFE6E2DC),
                            width: 2,
                          ),
                        ),
                        child: const Column(
                          children: [
                            Text('Custom Mode',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                            Text('Set your own duration',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Set session button
              SizedBox( // Wrap in a SizedBox to make the button full width
                width: double.infinity, 
                child: ElevatedButton(
                  onPressed: handleSetSession, // This now navigates!
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5353),
                    padding: const EdgeInsets.symmetric(vertical: 14), // Add padding for better look
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Set Session',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 30),

              // Upcoming sessions (mock)
              const Text('Upcoming Sessions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  title: const Text('Focus Session'),
                  subtitle: Text('Today, ${currentDate.hour}:00 - Pomodoro'),
                  trailing: const Text('Edit',
                      style: TextStyle(
                          color: Color(0xFF8B5353), fontWeight: FontWeight.bold)),
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('Deep Work'),
                  subtitle: Text('Tomorrow, 9:00 AM - Custom'),
                  trailing: const Text('Edit',
                      style: TextStyle(
                          color: Color(0xFF8B5353), fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}