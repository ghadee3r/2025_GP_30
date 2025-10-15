import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart'; // NEW: for slide button

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isConnected = false; // NEW: track ESP connection state
  bool isLoading = false;
  String selectedPreset = 'Choose Preset';
  int selectedModeIndex = 0; // 0 = Pomodoro, 1 = Custom
  bool hasSelectedMode = false;

  final presets = ['Deep Work', 'Morning Focus', 'Study Session'];

  final modes = [
    {
      'title': 'Pomodoro Mode',
      'desc': 'Structured focus and break sessions',
    },
    {
      'title': 'Custom Mode',
      'desc': 'Set your own duration',
    },
  ];

  // Simulate connecting delay (replace this with actual ESP Wi-Fi logic)
  Future<void> handleConnect() async {
    setState(() => isLoading = true);

    // TODO: Replace this section with your ESP Wi-Fi connection logic
    // Example:
    // await WiFiConnection.connectToESP(ssid, password);
    // if (success) setState(() => isConnected = true);

    await Future.delayed(const Duration(seconds: 2)); // simulate delay
    setState(() {
      isConnected = true; // Mark as connected
      isLoading = false;
    });
  }

  void handleSetSession() {
    final selectedMode = modes[selectedModeIndex]['title']!;
    String routeName =
        selectedMode == "Pomodoro Mode" ? '/pomodoro' : '/custom';
    Navigator.of(context).pushNamed(routeName);
  }

  void handlePresetSelect(String preset) {
    setState(() => selectedPreset = preset);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currentDate = DateTime.now();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // --- BACKGROUND IMAGE ---
          Positioned.fill(
            child: Image.asset(
              'assets/images/BlueHaze.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // --- DRAGGABLE SHEET ---
          DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.65,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Stack(
                children: [
                  // --- FROSTED BLUR OVERLAY ---
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          color: Colors.white.withOpacity(0.75),
                        ),
                      ),
                    ),
                  ),

                  // --- SHEET CONTENT ---
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          offset: Offset(0, -4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- DRAG HANDLE ---
                          Center(
                            child: Container(
                              width: 54,
                              height: 6,
                              margin:
                                  const EdgeInsets.only(top: 8, bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),

                          // --- LOGO ---
                          Center(
                            child: CircleAvatar(
                              radius: 65,
                              backgroundColor: Colors.transparent,
                              backgroundImage: const AssetImage(
                                  'assets/images/RikazLogo.png'),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // --- HEADER ---
                          const Text(
                            'Welcome back, User!',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Ready for a productive day?',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 20),

                          // --- CONNECT CARD ---
                          Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: isConnected
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Connected',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF4f46e5),
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'You can now unlock custom presets and advanced features.',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Connect Rikaz Tools',
                                          style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Connect to unlock custom presets and advanced features',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey),
                                        ),
                                        const SizedBox(height: 10),

                                        // --- SLIDE TO CONNECT BUTTON ---
                                       Builder(
  builder: (context) {
    final key = GlobalKey<SlideActionState>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: SlideAction(
        key: key,
        text: "Slide to Connect",
        textStyle: const TextStyle(
          fontSize: 13,                // smaller font
          fontWeight: FontWeight.w600, // medium weight for clarity
          color: Colors.white,
        ),
        textColor: Colors.white,
        innerColor: Colors.white,
        outerColor: const Color(0xFF4f46e5),
        sliderButtonIcon: const Icon(
          Icons.wifi,
          color: Colors.black,
          size: 15, // smaller icon
        ),
         // smaller corner radius
        height: 40,       // smaller overall height
        onSubmit: () async {
          await handleConnect();

          // Reset slide action after 1s (optional for testing only)
          Future.delayed(
            const Duration(seconds: 1),
            () => key.currentState!.reset(),
          );
          return null;
        },
      ),
    );
  },
),

                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // --- START FOCUS SESSION ---
                          const Text(
                            'Start Focus Session',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),

                          // --- PRESET DROPDOWN ---
                          GestureDetector(
                            onTap: () => showModalBottomSheet(
                              context: context,
                              builder: (_) => ListView(
                                shrinkWrap: true,
                                children: presets
                                    .map(
                                      (p) => ListTile(
                                        title: Text(p),
                                        onTap: () => handlePresetSelect(p),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                    color: const Color(0xFFE6E2DC)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(selectedPreset,
                                      style: const TextStyle(
                                          fontSize: 16, color: Colors.black)),
                                  const Icon(Icons.keyboard_arrow_down,
                                      color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // --- MODE SELECTOR (SOLID BLUE STYLE) ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(modes.length, (index) {
                              final mode = modes[index];
                              final isSelected = selectedModeIndex == index;

                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedModeIndex = index;
                                      hasSelectedMode = true;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    height: 100,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF4f46e5)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF4f46e5)
                                            : Colors.grey.shade300,
                                        width: 2,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color:
                                                    const Color(0xFF4f46e5)
                                                        .withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              )
                                            ]
                                          : [],
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          mode['title']!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          mode['desc']!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isSelected
                                                ? Colors.white70
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),

                          const SizedBox(height: 24),

                          // --- SET SESSION BUTTON ---
                          SizedBox(
                            width: double.infinity,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: ElevatedButton(
                                onPressed: handleSetSession,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hasSelectedMode
                                      ? const Color.fromARGB(255, 0, 0, 0)
                                      : const Color.fromARGB(255, 83, 83, 83),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Set Session',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),

                          // --- UPCOMING SESSIONS (MOCK) ---
                          const Text(
                            'Upcoming Sessions',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Card(
                            color: Color.fromRGBO(255, 255, 255, 1),
                            child: ListTile(
                              title: const Text('Focus Session'),
                              subtitle: Text(
                                  'Today, ${currentDate.hour}:00 - Pomodoro'),
                              trailing: const Text(
                                'Edit',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          Card(
                            color: Color.fromRGBO(255, 255, 255, 1),
                            child: ListTile(
                              title: const Text('Deep Work'),
                              subtitle:
                                  const Text('Tomorrow, 9:00 AM - Custom'),
                              trailing: const Text(
                                'Edit',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
