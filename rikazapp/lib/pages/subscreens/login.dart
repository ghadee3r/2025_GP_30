import 'package:flutter/material.dart';
// Standard Dart package for JSON encoding/decoding
// ignore: unused_import
import 'dart:convert';

// NOTE: http and shared_preferences are commented out in the implementation
// below to fulfill the request to temporarily remove DB/API logic.
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';

// --- Constants (Shared across screens) ---
// IMPORTANT: You must update your pubspec.yaml to include http and shared_preferences when ready.
const String _rikazLogoPath = "assets/images/RikazLogo.png";
// Placeholder route names for navigation (use your actual Flutter route names)
const String _signupRoute = "/signup";
// ignore: unused_element
const String _tabsRoute = "/tabs";
// ignore: unused_element
const String _homeRoute = "/home";

// --- Custom Alert Dialog Widget (Replacement for Alert.alert) ---
void _showAlert(BuildContext context, String title, String message) {
showDialog(
context: context,
builder: (BuildContext context) {
return AlertDialog(
title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
content: Text(message),
actions: <Widget>[
TextButton(
child: const Text("OK", style: TextStyle(color: Color(0xFF4f46e5))),
onPressed: () {
Navigator.of(context).pop();
},
),
],
);
},
);
}

class LoginScreen extends StatefulWidget {
const LoginScreen({super.key});

@override
State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
// --- State and Controller Variables (Replacing React's useState) ---
final TextEditingController _emailController = TextEditingController();
final TextEditingController _passwordController = TextEditingController();
bool _isSubmitting = false;
@override
void dispose() {
// Dispose of controllers to free up memory
_emailController.dispose();
_passwordController.dispose();
super.dispose();
}

// --- Login Logic (Replacing handleLogin) ---
Future<void> _handleLogin() async {
final email = _emailController.text.trim();
final password = _passwordController.text;

if (email.isEmpty || password.isEmpty) {
_showAlert(context, "Missing Info", "Please fill in all fields.");
return;
}

setState(() {
_isSubmitting = true;
});

try {
// --- MOCK LOGIN: API and DB logic temporarily disabled ---
// Simulate network delay for user feedback
await Future.delayed(const Duration(seconds: 2));

// If the API were active, the structure would look like this:
/*
const String apiBaseUrl = "http://192.168.100.15:8000/api";
final url = Uri.parse('$apiBaseUrl/login');
final response = await http.post(
url,
headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8'},
body: jsonEncode(<String, String>{'email': email, 'password': password}),
);
final data = jsonDecode(response.body);
if (response.statusCode != 200 || data['success'] == false) {
throw Exception(data['message'] ?? "Invalid credentials.");
}
// Persistence (AsyncStorage replacement)
final prefs = await SharedPreferences.getInstance();
await prefs.setString('userSession', jsonEncode({'email': email}));
*/

if (mounted) {
_showAlert(context, "Welcome Back!", "Logged in as $email (MOCK SUCCESS)");
// Navigate on success (router.replace("/(tabs)") equivalent)
Navigator.of(context).pushNamedAndRemoveUntil(
'/tabs',
(route) => false,
arguments: 0, // افتح تبويب Home ومعه شريط التبويب
);
}

} catch (e) {
// Catch and display potential mock/real errors
debugPrint("Login Error: $e");
if (mounted) {
// Display a generic mock error
_showAlert(context, "Login Error", "Login failed temporarily. Try again.");
}
} finally {
if (mounted) {
setState(() {
_isSubmitting = false;
});
}
}
}

// --- Helper widget for consistent input styling ---
Widget _buildTextInput({
required TextEditingController controller,
required String hintText,
required TextInputType keyboardType,
bool obscureText = false,
bool autocorrect = true,
}) {
return TextField(
controller: controller,
keyboardType: keyboardType,
obscureText: obscureText,
autocorrect: autocorrect,
style: const TextStyle(fontSize: 16),
decoration: InputDecoration(
hintText: hintText,
contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(8),
borderSide: const BorderSide(color: Color(0xFFcccccc)),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(8),
borderSide: const BorderSide(color: Color(0xFFcccccc)),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(8),
borderSide: const BorderSide(color: Color(0xFF4f46e5), width: 2),
),
),
);
}

// --- UI Build ---
@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.white,
body: SafeArea(
child: SingleChildScrollView(
child: Padding(
padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
crossAxisAlignment: CrossAxisAlignment.stretch,
children: <Widget>[
// Logo
Image.asset(
_rikazLogoPath,
height: 150,
width: 150,
),
const SizedBox(height: 10),

// Title
const Text(
'Welcome Back!',
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 28,
fontWeight: FontWeight.bold,
color: Color(0xFF222222),
),
),
// Subtitle
const Text(
'Log in to continue',
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 14,
color: Color(0xFF666666),
),
),
const SizedBox(height: 24),

// Email Input
_buildTextInput(
controller: _emailController,
hintText: "Email",
keyboardType: TextInputType.emailAddress,
autocorrect: false,
),
const SizedBox(height: 12),
// Password Input
_buildTextInput(
controller: _passwordController,
hintText: "Password",
keyboardType: TextInputType.visiblePassword,
obscureText: true,
autocorrect: false,
),
const SizedBox(height: 16),

// Log In Button
ElevatedButton(
onPressed: _isSubmitting ? null : _handleLogin,
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFF4f46e5),
padding: const EdgeInsets.symmetric(vertical: 14),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(8),
),
elevation: 0,
),
child: Text(
_isSubmitting ? "Logging in..." : "Log In",
style: const TextStyle(
color: Colors.white,
fontSize: 16,
fontWeight: FontWeight.w600,
),
),
),
const SizedBox(height: 20),

// Sign Up Link (Navigates to /signup)
GestureDetector(
onTap: () {
if (!_isSubmitting) {
// Navigate to signup screen (router.replace("/signup") equivalent)
Navigator.of(context).pushReplacementNamed(_signupRoute);
}
},
child: const Padding(
padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
child: Text(
'Don’t have an account? Sign Up',
textAlign: TextAlign.center,
style: TextStyle(
color: Color(0xFF4f46e5),
fontSize: 15,
),
),
),
),
],
),
),
),
),
);
}
}
