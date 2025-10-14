import 'package:flutter/material.dart';
import 'pages/mainscreens/home.dart';
import 'pages/subscreens/pomodoro.dart';
import 'pages/subscreens/custom.dart';
import 'pages/subscreens/session.dart'; // if you added it

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

      // ✅ Make Home the first page
      initialRoute: '/home',

      routes: {
        '/home': (context) => const HomePage(),
        '/pomodoro': (context) => const PomodoroPage(),
        '/custom': (context) => const CustomPage(),
        '/session': (context) {
          // If you have session.dart:
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
