import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluid_bottom_nav_bar/fluid_bottom_nav_bar.dart';

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
            padding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(cardBorderRadius / 2),
            ),
            textStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16),
            elevation: 4,
            shadowColor: primaryThemePurple.withValues(alpha: 0.5),
          ),
        ),
        cardTheme: CardThemeData(
          color: primaryBackground,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardBorderRadius),
          ),
          shadowColor: primaryThemePurple.withValues(alpha: 0.3),
          margin: const EdgeInsets.symmetric(vertical: 10),
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
                color: primaryThemePurple.withValues(alpha: 0.3),
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
          final idx =
              ModalRoute.of(context)!.settings.arguments as int? ?? 0;
          return TabsScreen(initialIndex: idx);
        },
        '/home': (context) => const HomePage(),
        '/SetSession': (context) {
          final initialMode =
              ModalRoute.of(context)!.settings.arguments as SessionMode?;
          return SetSessionPage(initialMode: initialMode);
        },
        '/session': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                      as Map<String, dynamic>? ??
                  {};
          return SessionPage(
            sessionType: args['sessionType'] ?? 'pomodoro',
            duration: args['duration'] ?? '25min',
            numberOfBlocks: args['numberOfBlocks'],
            isCameraDetectionEnabled: args['isCameraDetectionEnabled'],
            sensitivity: args['sensitivity'],
            notificationStyle: args['notificationStyle'],
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

  @override
  void initState() {
    super.initState();
    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      debugPrint('Auth event detected: $event');
      if (event == AuthChangeEvent.passwordRecovery) {
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/new-password', (route) => false);
        }
      } else if (event == AuthChangeEvent.signedOut) {
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } else if (event == AuthChangeEvent.signedIn) {
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/tabs', (route) => false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Session?>(
      future: Future.value(Supabase.instance.client.auth.currentSession),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: primaryThemePurple),
            ),
          );
        }
        final session = snapshot.data;
        if (session != null) {
          return const TabsScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class TabsScreen extends StatefulWidget {
  const TabsScreen({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends State<TabsScreen> {
  late int _index;
  final List<Widget> _tabs = [
    HomePage(),
    ProgressScreen(),
    GamesScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  void _onTabChange(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _tabs[_index],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: FluidNavBar(
          icons: [
            FluidNavBarIcon(icon: Icons.home),
            FluidNavBarIcon(icon: Icons.trending_up),
            FluidNavBarIcon(icon: Icons.sports_esports),
            FluidNavBarIcon(icon: Icons.person),
          ],
          onChange: _onTabChange,
          defaultIndex: _index,
          style: FluidNavBarStyle(
            barBackgroundColor: cs.surfaceContainerHighest,
            iconSelectedForegroundColor: cs.primary,
            iconUnselectedForegroundColor:
                cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
