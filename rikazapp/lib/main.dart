import 'package:flutter/material.dart';
// Main screens
import 'pages/mainscreens/home.dart';
// Sub screens (Assuming your auth files are here based on the screenshot)
import 'pages/subscreens/pomodoro.dart';
import 'pages/subscreens/custom.dart';
import 'pages/subscreens/session.dart'; 
import 'pages/subscreens/signup.dart'; // Import Signup Screen
import 'pages/subscreens/login.dart';  // Import Login Screen

// Placeholder for your main app layout after authentication
// You will need to create a TabsScreen or similar widget here.
class TabsScreen extends StatelessWidget {
  const TabsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text("Welcome to the Main App! (Tabs Screen)")),
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rikaz',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),

      // CHANGE 1: Set the initial page to the Sign Up screen
      initialRoute: '/signup',

      routes: {
        // --- Authentication Routes ---
        '/signup': (context) => const SignupScreen(), // Your new starting page
        '/login': (context) => const LoginScreen(),   // Login page
        '/tabs': (context) => const TabsScreen(),      // Main app layout after auth

        // --- Main App Feature Routes ---
        '/home': (context) => const HomePage(),
        '/pomodoro': (context) => const PomodoroPage(),
        '/custom': (context) => const CustomPage(),
        '/session': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>? ?? {};
          return SessionPage(
            sessionType: args['sessionType'] ?? 'pomodoro',
            duration: args['duration'] ?? '25min',
            numberOfBlocks: args['numberOfBlocks'],
          );
        },
      },
    );
  }
}
