import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ========= Constants =========
const String _apiBaseUrl = "http://192.168.100.15:8000/api";
const String _rikazLogoPath = "assets/images/RikazLogo.png";
const String _googleIconUrl = "https://developers.google.com/identity/images/g-logo.png";

// ========= Helpers =========
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
onPressed: () => Navigator.of(context).pop(),
),
],
);
},
);
}

// ========= Widget =========
class SignupScreen extends StatefulWidget {
const SignupScreen({super.key});

@override
State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
final TextEditingController _nameController = TextEditingController();
final TextEditingController _emailController = TextEditingController();
final TextEditingController _passwordController = TextEditingController();

bool _isSubmitting = false;
bool _isGoogleAuthReady = true; // موك

@override
void dispose() {
_nameController.dispose();
_emailController.dispose();
_passwordController.dispose();
super.dispose();
}

Future<void> _handleSignup() async {
final name = _nameController.text.trim();
final email = _emailController.text.trim();
final password = _passwordController.text;

if (name.isEmpty || email.isEmpty || password.isEmpty) {
_showAlert(context, "Missing Info", "Please fill in all fields.");
return;
}

setState(() => _isSubmitting = true);

try {
final url = Uri.parse('$_apiBaseUrl/register');
final response = await http.post(
url,
headers: const {'Content-Type': 'application/json; charset=UTF-8'},
body: jsonEncode({'name': name, 'email': email, 'password': password}),
);

// نحاول نفك الـ JSON بأمان
Map<String, dynamic> data = {};
try {
data = jsonDecode(response.body) as Map<String, dynamic>;
} catch (_) {
// خليه فاضي—نعتمد على statusCode
}

if (response.statusCode != 200 || (data['success'] == false)) {
final msg = (data['message']?.toString().trim().isNotEmpty ?? false)
? data['message'].toString()
: "Registration failed.";
throw Exception(msg);
}

// حفظ جلسة بسيطة
final prefs = await SharedPreferences.getInstance();
await prefs.setString('userSession', jsonEncode({'email': email}));

if (!mounted) return;

_showAlert(context, "Account Created", "Welcome, $name!");

// بعد النجاح → افتح Tabs على تبويب Home (index 0) وامسح الستاك
Navigator.of(context).pushNamedAndRemoveUntil(
'/tabs',
(route) => false,
arguments: 0, // 0 = Home tab
);
} catch (e) {
if (!mounted) return;
final msg = e.toString().replaceFirst('Exception: ', '');
_showAlert(context, "Signup Error", msg.isEmpty ? "An unexpected error occurred." : msg);
} finally {
if (mounted) setState(() => _isSubmitting = false);
}
}

void _handleGoogleConnect() {
_showAlert(
context,
"Feature Placeholder",
"Google Sign-In requires the 'google_sign_in' package and native setup. Currently mocked.",
);
}

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

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.white,
body: SafeArea(
child: SingleChildScrollView(
padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: <Widget>[
// Logo
Image.asset(_rikazLogoPath, height: 150, width: 150),
const SizedBox(height: 10),

const Text(
'Create Account',
textAlign: TextAlign.center,
style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF222222)),
),
const SizedBox(height: 24),

_buildTextInput(
controller: _nameController,
hintText: "Full Name",
keyboardType: TextInputType.text,
),
const SizedBox(height: 12),
_buildTextInput(
controller: _emailController,
hintText: "Email",
keyboardType: TextInputType.emailAddress,
autocorrect: false,
),
const SizedBox(height: 12),
_buildTextInput(
controller: _passwordController,
hintText: "Password",
keyboardType: TextInputType.visiblePassword,
obscureText: true,
autocorrect: false,
),
const SizedBox(height: 16),

ElevatedButton(
onPressed: _isSubmitting ? null : _handleSignup,
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFF4f46e5),
padding: const EdgeInsets.symmetric(vertical: 14),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
elevation: 0,
),
child: Text(
_isSubmitting ? "Creating..." : "Sign Up",
style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
),
),
const SizedBox(height: 10),

const Text('or', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF666666), fontSize: 16)),
const SizedBox(height: 10),

OutlinedButton(
onPressed: (_isSubmitting || !_isGoogleAuthReady) ? null : _handleGoogleConnect,
style: OutlinedButton.styleFrom(
padding: const EdgeInsets.symmetric(vertical: 12),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
side: const BorderSide(color: Color(0xFFcccccc), width: 1),
),
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
children: <Widget>[
Image.network(_googleIconUrl, width: 22, height: 22),
const SizedBox(width: 8),
const Text('Connect Google Calendar', style: TextStyle(fontSize: 15, color: Color(0xFF333333))),
],
),
),
const SizedBox(height: 20),

// Log In link
GestureDetector(
onTap: _isSubmitting ? null : () => Navigator.of(context).pushReplacementNamed('/login'),
child: const Padding(
padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
child: Text(
'Already have an account? Log in',
textAlign: TextAlign.center,
style: TextStyle(color: Color(0xFF4f46e5), fontSize: 15),
),
),
),

// Skip (No DB) → افتح Tabs على Home
const SizedBox(height: 10),
TextButton(
onPressed: _isSubmitting
? null
: () {
Navigator.of(context).pushNamedAndRemoveUntil(
'/tabs',
(route) => false,
arguments: 0, // افتح تبويب Home ومعه شريط التبويب
);
},
child: const Text(
'Skip for now (No DB)',
style: TextStyle(
color: Color(0xFF9ca3af),
fontSize: 14,
decoration: TextDecoration.underline,
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