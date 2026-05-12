import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/mainscreens/home.dart';
import 'pages/mainscreens/progress.dart';
import 'pages/mainscreens/games/games.dart';
import 'pages/mainscreens/profile.dart';
import 'pages/subscreens/SetSession.dart';
import 'pages/subscreens/session.dart';
import 'pages/subscreens/signup.dart';
import 'pages/subscreens/login.dart';
import 'pages/subscreens/ForgotPassword.dart';
import 'pages/subscreens/NewPassword.dart';

// --- NEW THEME COLORS (Matching home.dart) ---
const Color dfTealCyan = Color(0xFF68C29D);
const Color customModeColor = Color(0xFF7E84D4);
const Color primaryTextDark = Color(0xFF1B2536);
const Color secondaryTextGrey = Color(0xFF8B95A5);
const Color primaryBackground = Color(0xFFF2F6F9);
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
      seedColor: dfTealCyan,
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rikaz',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme.copyWith(
          primary: dfTealCyan,
          secondary: customModeColor,
          surface: Colors.white,
          surfaceContainerHighest: primaryBackground,
          onSurface: primaryTextDark,
        ),
        scaffoldBackgroundColor: primaryBackground,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: dfTealCyan,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(cardBorderRadius / 2),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            elevation: 4,
            shadowColor: dfTealCyan.withOpacity(0.4),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(cardBorderRadius / 2),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(cardBorderRadius / 2),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(cardBorderRadius / 2),
            borderSide: const BorderSide(color: dfTealCyan, width: 2.0),
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
          final args = ModalRoute.of(context)!.settings.arguments;
          SessionMode? initialMode;
          
          // Translate the string from HomePage into the enum SetSession expects
          if (args == 'pomodoro') {
            initialMode = SessionMode.pomodoro;
          } else if (args == 'custom') {
            initialMode = SessionMode.custom;
          } else if (args is SessionMode) {
            initialMode = args; // Fallback in case you pass the enum directly from elsewhere
          }

          return SetSessionPage(initialMode: initialMode);
        },
       '/session': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>? ?? {};
          
          debugPrint('📋 Session Route Args: $args');
          
          return SessionPage(
            sessionType: args['sessionType'] ?? 'pomodoro',
            duration: args['duration'] ?? '25min',
            numberOfBlocks: args['numberOfBlocks'],
            isCameraDetectionEnabled: args['isCameraDetectionEnabled'],
            sensitivity: args['sensitivity'],
            notificationStyle: args['notificationStyle'],
            subtleAlertType: args['subtleAlertType'],
            sleepTrigger: args['sleepTrigger'],
            presenceTrigger: args['presenceTrigger'],
            phoneTrigger: args['phoneTrigger'], 
            notificationSoundUrl: args['notificationSoundUrl'],
            rikazConnected: args['rikazConnected'] ?? false,
            selectedSoundId: args['selectedSoundId'],
            selectedSoundName: args['selectedSoundName'],
            selectedSoundUrl: args['selectedSoundUrl'],
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
            navigatorKey.currentState!.pushNamedAndRemoveUntil('/new-password', (route) => false);
          } else {
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/new-password', (route) => false);
            }
          }
        });
      }
      
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
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: dfTealCyan),
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
    const HomePage(),
    const ProgressScreen(),
    const GamesScreen(),
    const ProfileScreen(),
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
      backgroundColor: primaryBackground,
      extendBody: false, 
      body: _tabs[_currentIndex],
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 24, right: 24, bottom: 20, top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: dfTealCyan.withOpacity(0.12),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                outlineIcon: Icons.home_outlined,
                isSelected: _currentIndex == 0,
                onTap: () => _onTabTapped(0),
                activeColor: dfTealCyan,
              ),
              _NavItem(
                icon: Icons.trending_up_rounded,
                outlineIcon: Icons.show_chart_rounded, // Outline equivalent
                isSelected: _currentIndex == 1,
                onTap: () => _onTabTapped(1),
                activeColor: customModeColor, 
              ),
              _NavItem(
                icon: Icons.sports_esports_rounded,
                outlineIcon: Icons.sports_esports_outlined,
                isSelected: _currentIndex == 2,
                onTap: () => _onTabTapped(2),
                activeColor: dfTealCyan,
              ),
              _NavItem(
                icon: Icons.person_rounded,
                outlineIcon: Icons.person_outline_rounded,
                isSelected: _currentIndex == 3,
                onTap: () => _onTabTapped(3),
                activeColor: customModeColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// HIGHLY INTERACTIVE NAVIGATION ITEM
// Minimalist Icon + Dot Indicator (Matches Reference Image)
// ------------------------------------------------------------------
class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData outlineIcon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;

  const _NavItem({
    required this.icon,
    required this.outlineIcon,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isSelected ? widget.activeColor : secondaryTextGrey.withOpacity(0.6);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        // Satisfying squish when pressed
        scale: _isPressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Smoothly transitions between filled and outlined icons
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                child: Icon(
                  widget.isSelected ? widget.icon : widget.outlineIcon,
                  key: ValueKey<bool>(widget.isSelected),
                  color: iconColor,
                  size: 26,
                ),
              ),
              const SizedBox(height: 6),
              // The elegant dot indicator
              AnimatedScale(
                scale: widget.isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: widget.activeColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}