import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // REQUIRED: Supabase Import
import 'package:fluid_bottom_nav_bar/fluid_bottom_nav_bar.dart'; 

// الشاشات الرئيسية
import 'pages/mainscreens/home.dart';
import 'pages/mainscreens/progress.dart';
import 'pages/mainscreens/games.dart';
import 'pages/mainscreens/profile.dart';

// الشاشات الفرعية (المصادقة وغيرها)
// FIXED IMPORT: Using the unified SetSessionPage and removing old pomodoro/custom.

import 'pages/subscreens/SetSession.dart';
// import 'pages/subscreens/pomodoro.dart'; // Removed
// import 'pages/subscreens/custom.dart'; // Removed
import 'pages/subscreens/session.dart';
import 'pages/subscreens/signup.dart';
import 'pages/subscreens/login.dart'; // <<< This import makes LoginScreen available

// =============================================================================
// 1. FINAL REFINED THEME DEFINITIONS (Global Constants)
// =============================================================================

const Color primaryThemePurple = Color(0xFF7A68FF); 
const Color primaryTextDark = Color(0xFF30304D); 
const Color secondaryTextGrey = Color(0xFF8C8C99); 
const Color primaryBackground = Color(0xFFFFFFFF); 

const double cardBorderRadius = 24.0; 

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
            seedColor: primaryThemePurple,
            brightness: Brightness.light,
        );

        return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Rikaz',
            theme: ThemeData(
                useMaterial3: true,
                // --- THEME CUSTOMIZATION START ---
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius / 2)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        elevation: 4,
                        shadowColor: primaryThemePurple.withOpacity(0.5),
                    ),
                ),
                cardTheme: CardTheme.of(context).copyWith(
                    color: primaryBackground, 
                    elevation: 8, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
                    shadowColor: primaryThemePurple.withOpacity(0.3), 
                    margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
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
                        borderSide: BorderSide(color: primaryThemePurple.withOpacity(0.3), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(cardBorderRadius / 2),
                        borderSide: const BorderSide(color: primaryThemePurple, width: 2.0),
                    ),
                ),
                // --- THEME CUSTOMIZATION END ---
            ),

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
                
                // FIXED ERROR 1: Using the new, merged route
                '/SetSession': (context) {
  // Retrieve the argument passed via Navigator.pushNamed
  final initialMode = ModalRoute.of(context)!.settings.arguments as SessionMode?;
  
  // Pass the argument to the SetSessionPage constructor
  return SetSessionPage(initialMode: initialMode);
},
                
                // FIXED ERRORS 2, 3, 4: Added the required named parameters to pass config data
                '/session' : (context) {
                    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>? ?? {};
                    return SessionPage(
                        sessionType: args['sessionType'] ?? 'pomodoro',
                        duration: args['duration'] ?? '25min',
                        numberOfBlocks: args['numberOfBlocks'],
                        isCameraDetectionEnabled: args['isCameraDetectionEnabled'], // FIX
                        sensitivity: args['sensitivity'],                       // FIX
                        notificationStyle: args['notificationStyle'],           // FIX
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
        return FutureBuilder<Session?>(
            future: supabase.auth.refreshSession().catchError((error) {
                // Catch network or storage errors during refresh and treat as logged out
                return null;
            }).then((response) => response.session), // Extract the session from the response
            builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                    // Show loader while loading initial session from secure storage
                    return Scaffold(
                        body: Center(child: CircularProgressIndicator(color: primaryThemePurple)),
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
