import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // REQUIRED: Supabase Import
import 'package:fluid_bottom_nav_bar/fluid_bottom_nav_bar.dart'; 

// الشاشات الرئيسية
import 'pages/mainscreens/home.dart';
import 'pages/mainscreens/progress.dart';
import 'pages/mainscreens/games.dart';
import 'pages/mainscreens/profile.dart';

// الشاشات الفرعية (المصادقة وغيرها)
import 'pages/subscreens/pomodoro.dart';
import 'pages/subscreens/custom.dart';
import 'pages/subscreens/session.dart';
import 'pages/subscreens/signup.dart';
import 'pages/subscreens/login.dart'; // <<< This import makes LoginScreen available

// ====================================================================
// 🚨 SUPABASE CREDENTIALS🚨
// ====================================================================
const String supabaseUrl = 'https://fbjxvlzhxsxiyxuuvefu.supabase.co'; 
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZianh2bHpoeHN4aXl4dXV2ZWZ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA1MTkxMzQsImV4cCI6MjA3NjA5NTEzNH0.3oSMgdkXhEl8peRyGvN1P6zlzxdd9fWXHcdXRuWqQLE';

// ====================================================================
// STEP 1: INITIALIZE SUPABASE AND RUN APP
// ====================================================================
void main() async {
  // REQUIRED: Allows async operations before Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized(); 

  // Initialize Supabase client
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
const MyApp({super.key});

@override
Widget build(BuildContext context) {
final ColorScheme colorScheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF6E5DE7),
  brightness: Brightness.light,
);

return MaterialApp(
debugShowCheckedModeBanner: false,
title: 'Rikaz',
theme: ThemeData(
useMaterial3: true,
colorScheme: colorScheme.copyWith(
primary: const Color(0xFF6E5DE7),
surface: const Color(0xFFF7F7FB),
surfaceContainerHighest: Colors.white,
),
scaffoldBackgroundColor: const Color(0xFFF7F7FB),
elevatedButtonTheme: ElevatedButtonThemeData(
style: ElevatedButton.styleFrom(
foregroundColor: Colors.white,
backgroundColor: const Color(0xFF6E5DE7),
padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
textStyle: const TextStyle(fontWeight: FontWeight.w700),
),
),
cardTheme: CardThemeData(
color: Colors.white,
elevation: 0,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
margin: const EdgeInsets.symmetric(vertical: 8),
shadowColor: Colors.black12,
),
inputDecorationTheme: InputDecorationTheme(
filled: true,
fillColor: Colors.white,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
),
),
),

// RENAME 'initialRoute' to 'home' and use AuthWrapper
// initialRoute: '/login', // REMOVED

routes: {
'/signup': (context) => const SignupScreen(),
'/login' : (context) => const LoginScreen(),

// tabs تقرأ initialIndex من arguments
'/tabs': (context) {
final idx = ModalRoute.of(context)!.settings.arguments as int? ?? 0;
return TabsScreen(initialIndex: idx); 
},

// بقية الصفحات
'/home' : (context) => const HomePage(),
'/pomodoro': (context) => const PomodoroPage(),
'/custom' : (context) => const CustomPage(),
'/session' : (context) {
final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>? ?? {};
return SessionPage(
sessionType: args['sessionType'] ?? 'pomodoro',
duration: args['duration'] ?? '25min',
numberOfBlocks: args['numberOfBlocks'],
);
},
},

// ADDED: AuthWrapper is the entry point now
home: const AuthWrapper(),
);
}
}

// ====================================================================
// AUTH WRAPPER: Handles initial routing based on Supabase session state
// ====================================================================
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // The client is retrieved once and used for listening
  final SupabaseClient supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Listen for auth changes to handle sign out/sign in events
    supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      
      if (session == null && event == AuthChangeEvent.signedOut) {
        // User logged out, navigate to login
        if (mounted) {
          // Use pushNamedAndRemoveUntil to clear the navigation stack
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } else if (session != null && event == AuthChangeEvent.signedIn) {
        // User logged in, navigate to tabs
        if (mounted) {
          // Use pushNamedAndRemoveUntil to clear the navigation stack
          Navigator.of(context).pushNamedAndRemoveUntil('/tabs', (route) => false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Changed to use refreshSession() which correctly returns a Future<Session?>.
    // This is the most reliable way to check the initial session state from secure storage.
    return FutureBuilder<Session?>(
      future: supabase.auth.refreshSession().catchError((error) {
        // Catch network or storage errors during refresh and treat as logged out
        return null;
      }).then((response) => response.session), // Extract the session from the response
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           // Show loader while loading initial session from secure storage
           return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If the snapshot has an active session (snapshot.data is the Session object)
        if (snapshot.data?.user != null) { 
          return const TabsScreen();
        }

        // Default to login screen if no session is found
        return const LoginScreen();
      },
    );
  }
}


/// شاشة التبويبات الرئيسية
class TabsScreen extends StatefulWidget {
const TabsScreen({super.key, this.initialIndex = 0}); // 0 = Home
final int initialIndex;

@override
State<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends State<TabsScreen> {
late int _index;

@override
void initState() {
super.initState();
_index = widget.initialIndex; // ابدأ بالتبويب المطلوب
}

// لا تجعل القائمة const لتفادي مشاكل مستقبلية
final List<Widget> _tabs = [
const HomePage(),
const ProgressScreen(),
const GamesScreen(),
const ProfileScreen(),
];

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
// FIX: Corrected syntax for opacity (was .withValues(alpha: .5)
iconUnselectedForegroundColor: cs.onSurface.withOpacity(0.5), 
),
),
),
);
}
}
