import 'package:flutter/material.dart';
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
import 'pages/subscreens/login.dart';

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
useMaterial3: true,
colorScheme: ColorScheme.fromSeed(
seedColor: const Color(0xFF6E5DE7),
brightness: Brightness.light,
).copyWith(
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

// ابدأ على صفحة اللوق إن (لأنك ما تستخدم ساين أب الآن)
initialRoute: '/login',

routes: {
'/signup': (context) => const SignupScreen(),
'/login' : (context) => const LoginScreen(),

// tabs تقرأ initialIndex من arguments
'/tabs': (context) {
final idx = ModalRoute.of(context)!.settings.arguments as int? ?? 0;
return TabsScreen(initialIndex: idx); // 0=Home, 1=Progress, 2=Games, 3=Profile
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
iconUnselectedForegroundColor: cs.onSurface.withValues(alpha: .5),
),
),
),
);
}
}