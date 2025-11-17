import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/mainscreens/home.dart';
import 'pages/mainscreens/progress.dart';
import 'pages/mainscreens/games.dart';
import 'pages/mainscreens/profile.dart';
import 'pages/subscreens/SetSession.dart';
import 'pages/subscreens/session.dart';
import 'pages/subscreens/signup.dart';
import 'pages/subscreens/login.dart';
import 'pages/subscreens/ForgotPassword.dart';
import 'pages/subscreens/NewPassword.dart';

const Color primaryThemePurple = Color(0xFF7A68FF);
const Color primaryTextDark = Color(0xFF30304D);
const Color primaryBackground = Color(0xFFFFFFFF);
const double cardBorderRadius = 24.0;

const String supabaseUrl = 'https://fbjxvlzhxsxiyxuuvefu.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZianh2bHpoeHN4aXl4dXV2ZWZ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA1MTkxMzQsImV4cCI6MjA3NjA5NTEzNH0.3oSMgdkXhEl8peRyGvN1P6zlzxdd9fWXHcdXRuWqQLE';

// Global navigation key for handling auth events
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global state for Rikaz BLE connection (persists across navigation)
class RikazConnectionState {
  static bool isConnected = false; 
  
  static void setConnected(bool value) {
    isConnected = value;
    debugPrint('🔌 RIKAZ ESP32 Tools: ${value ? "CONNECTED" : "DISCONNECTED"}');
  }
  
  static void reset() {
    isConnected = false;
    debugPrint('🔌 RIKAZ ESP32 Tools: RESET');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: primaryThemePurple,
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rikaz',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme.copyWith(
          primary: primaryThemePurple,
          secondary: primaryThemePurple,
          surface: primaryBackground,
          surfaceContainerHighest: primaryBackground,
          onSurface: primaryTextDark,
        ),
        scaffoldBackgroundColor: primaryBackground,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: primaryBackground,
            backgroundColor: primaryThemePurple,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(cardBorderRadius / 2),
            ),
            textStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16),
            elevation: 4,
            shadowColor: primaryThemePurple.withOpacity(0.5),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: primaryBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(cardBorderRadius / 2),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(cardBorderRadius / 2),
            borderSide: BorderSide(
                color: primaryThemePurple.withOpacity(0.3),
                width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(cardBorderRadius / 2),
            borderSide:
                const BorderSide(color: primaryThemePurple, width: 2.0),
          ),
        ),
      ),
      routes: {
        '/signup': (context) => const SignupScreen(),
        '/login': (context) => const LoginScreen(),
        '/forgot-password': (context) => const ForgotPassword(),
        '/new-password': (context) => const NewPassword(),
        '/tabs': (context) {
          final idx = ModalRoute.of(context)!.settings.arguments as int? ?? 0;
          return MainTabsScreen(initialIndex: idx);
        },
        '/home': (context) => const HomePage(),
        '/SetSession': (context) {
          final initialMode =
              ModalRoute.of(context)!.settings.arguments as SessionMode?;
          return SetSessionPage(initialMode: initialMode);
        },
        '/session': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>? ?? {};
          return SessionPage(
            sessionType: args['sessionType'] ?? 'pomodoro',
            duration: args['duration'] ?? '25min',
            numberOfBlocks: args['numberOfBlocks'],
            isCameraDetectionEnabled: args['isCameraDetectionEnabled'],
            sensitivity: args['sensitivity'],
            notificationStyle: args['notificationStyle'],
            rikazConnected: args['rikazConnected'] ?? false,
          );
        },
      },
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isInitialAuthCheckComplete = false;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    _checkInitialAuthState();
  }

  void _setupAuthListener() {
    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      
      if (event == AuthChangeEvent.passwordRecovery) {
        debugPrint('PASSWORD RECOVERY EVENT - FORCING NAVIGATION');
        
        Future.delayed(Duration.zero, () {
          if (navigatorKey.currentState != null) {
            navigatorKey.currentState!.pushNamedAndRemoveUntil(
              '/new-password', 
              (route) => false
            );
          } else {
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/new-password', 
                (route) => false
              );
            }
          }
        });
      }
      
      // Reset Rikaz ESP32 hardware connection on logout
      if (event == AuthChangeEvent.signedOut) {
        RikazConnectionState.reset();
      }
    });
  }

  void _checkInitialAuthState() async {
    final currentSession = supabase.auth.currentSession;
    debugPrint('Initial auth check - Session: $currentSession');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isInitialAuthCheckComplete = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Session?>(
      future: Future.value(Supabase.instance.client.auth.currentSession),
      builder: (context, snapshot) {
        if (!_isInitialAuthCheckComplete) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: primaryThemePurple),
            ),
          );
        }

        final session = snapshot.data;
        debugPrint('FutureBuilder - Session: $session');

        if (session != null) {
          return const MainTabsScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  late int _currentIndex;
  final List<Widget> _tabs = [
    HomePage(),
    ProgressScreen(),
    GamesScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_esports),
            label: 'Games',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        selectedItemColor: primaryThemePurple,
        unselectedItemColor: primaryTextDark.withOpacity(0.5),
        backgroundColor: primaryBackground,
      ),
    );
  }
}