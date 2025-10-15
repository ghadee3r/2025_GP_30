import 'package:flutter/material.dart';

class CustomPage extends StatefulWidget {
const CustomPage({super.key});

@override
State<CustomPage> createState() => _CustomPageState();
}

class _CustomPageState extends State<CustomPage> {
bool isLoading = false;
double sessionDuration = 70;
bool isConfigurationOpen = false;
bool isCameraDetectionEnabled = true;
double sensitivity = 0.5;
String notificationStyle = 'Both';

void resetForm() {
setState(() {
sessionDuration = 70;
isConfigurationOpen = false;
isCameraDetectionEnabled = true;
sensitivity = 0.5;
notificationStyle = 'Both';
});
}

void handleStartSessionPress() {
Navigator.pushNamed(
context,
'/session',
arguments: {
'sessionType': 'custom',
'duration': sessionDuration.toInt().toString(),
},
);
}

// زر رجوع صغير يرجّع للهوم داخل Tabs
Widget _backMiniLink(ColorScheme cs, TextTheme text) {
return Align(
alignment: Alignment.centerLeft,
child: InkWell(
borderRadius: BorderRadius.circular(999),
onTap: () {
// نرجع للهوم داخل شريط التبويبات
Navigator.of(context).pushNamedAndRemoveUntil(
'/tabs',
(route) => false,
arguments: 0, // 0 = Home tab
);
},
child: Padding(
padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: cs.primary),
const SizedBox(width: 4),
Text(
'Back',
style: text.labelSmall?.copyWith(
color: cs.primary,
fontWeight: FontWeight.w600,
letterSpacing: .2,
),
),
],
),
),
),
);
}

@override
Widget build(BuildContext context) {
final cs = Theme.of(context).colorScheme;
final textTheme = Theme.of(context).textTheme;

return Scaffold(
backgroundColor: Theme.of(context).scaffoldBackgroundColor,
body: SafeArea(
child: Stack(
children: [
SingleChildScrollView(
padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// ← زر رجوع صغير
_backMiniLink(cs, textTheme),
const SizedBox(height: 8),

// Header (breadcrumbs + عناوين)
Text(
'Home > Set Session',
style: textTheme.bodySmall?.copyWith(
color: cs.onSurface.withValues(alpha: .6),
),
),
const SizedBox(height: 10),
Text('Custom Session',
style: textTheme.headlineSmall?.copyWith(
fontWeight: FontWeight.bold,
color: cs.onSurface,
)),
Text('Set your own timing',
style: textTheme.bodyMedium?.copyWith(
color: cs.onSurfaceVariant,
)),
const SizedBox(height: 25),

// Session Duration
Text('Session Duration',
style: textTheme.titleMedium?.copyWith(
fontWeight: FontWeight.w700,
color: cs.onSurface,
)),
const SizedBox(height: 10),
Center(
child: Text(
'${sessionDuration.toInt()}:00',
style: textTheme.displaySmall?.copyWith(
fontWeight: FontWeight.bold,
color: cs.onSurface,
),
),
),
Text('No Breaks',
textAlign: TextAlign.center,
style: textTheme.bodyMedium?.copyWith(
color: cs.onSurfaceVariant,
)),
const SizedBox(height: 10),
Slider(
value: sessionDuration,
min: 25,
max: 120,
divisions: 95,
label: '${sessionDuration.toInt()} min',
onChanged: (v) => setState(() => sessionDuration = v),
activeColor: cs.primary,
inactiveColor: cs.surfaceVariant,
),
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text('25 Minutes',
style: textTheme.labelSmall?.copyWith(
color: cs.onSurfaceVariant,
)),
Text('120 Minutes',
style: textTheme.labelSmall?.copyWith(
color: cs.onSurfaceVariant,
)),
],
),
const SizedBox(height: 25),

// Rikaz Tools Configuration
GestureDetector(
onTap: () =>
setState(() => isConfigurationOpen = !isConfigurationOpen),
child: Container(
padding:
const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
decoration: BoxDecoration(
color: cs.surface,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: cs.outlineVariant),
),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text('Rikaz Tools Configuration',
style: textTheme.bodyLarge?.copyWith(
color: cs.onSurface,
)),
Icon(
isConfigurationOpen
? Icons.keyboard_arrow_up
: Icons.keyboard_arrow_down,
color: cs.onSurface,
),
],
),
),
),
const SizedBox(height: 10),

if (isConfigurationOpen) _configurationMenu(cs, textTheme),
const SizedBox(height: 100),
],
),
),

// Start button (يلتقط ألوانه من ElevatedButtonTheme)
Positioned(
left: 20,
right: 20,
bottom: 20,
child: ElevatedButton(
onPressed: isLoading ? null : handleStartSessionPress,
child: isLoading
? const SizedBox(
width: 22,
height: 22,
child: CircularProgressIndicator(strokeWidth: 2),
)
: const Text('Start Session'),
),
),
],
),
),
);
}

// Configuration section widget
Widget _configurationMenu(ColorScheme cs, TextTheme textTheme) {
return Container(
padding: const EdgeInsets.all(15),
decoration: BoxDecoration(
color: cs.surface,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: cs.outlineVariant),
boxShadow: const [
BoxShadow(
color: Color(0x14000000),
offset: Offset(0, 2),
blurRadius: 5,
),
],
),
child: Column(
children: [
// Camera
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text('Camera Detection', style: textTheme.bodyLarge),
Switch(
value: isCameraDetectionEnabled,
onChanged: (v) => setState(() => isCameraDetectionEnabled = v),
activeColor: cs.primary,
trackOutlineColor: WidgetStatePropertyAll(cs.outlineVariant),
),
],
),
const SizedBox(height: 15),

// Triggers (تم تلوينها من الثيم فقط)
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text('Triggers', style: textTheme.bodyLarge),
Row(
children: List.generate(
3,
(index) => Container(
margin: const EdgeInsets.symmetric(horizontal: 6),
width: 20,
height: 20,
decoration: BoxDecoration(
border: Border.all(color: cs.primary, width: 2),
borderRadius: BorderRadius.circular(5),
color: cs.primary.withValues(alpha: .08),
),
),
),
),
],
),
const SizedBox(height: 15),

// Sensitivity
Row(
children: [
Text('Sensitivity', style: textTheme.bodyLarge),
const SizedBox(width: 10),
Text('Low', style: textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
Expanded(
child: Slider(
value: sensitivity,
min: 0,
max: 1,
divisions: 2,
label: sensitivity == 0
? 'Low'
: sensitivity == 0.5
? 'Medium'
: 'High',
onChanged: (v) => setState(() => sensitivity = v),
activeColor: cs.primary,
inactiveColor: cs.surfaceVariant,
),
),
Text('High', style: textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
],
),
const SizedBox(height: 15),

// Notification
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Notification', style: textTheme.bodyLarge),
const SizedBox(height: 10),
Row(
mainAxisAlignment: MainAxisAlignment.spaceAround,
children: ['Light', 'Sound', 'Both'].map((option) {
final isSelected = notificationStyle == option;
return GestureDetector(
onTap: () => setState(() => notificationStyle = option),
child: Row(
children: [
Container(
width: 20,
height: 20,
margin: const EdgeInsets.only(right: 5),
decoration: BoxDecoration(
shape: BoxShape.circle,
border: Border.all(
color: isSelected ? cs.primary : cs.outline,
),
color: isSelected ? cs.primary : Colors.transparent,
),
),
Text(option, style: textTheme.bodyMedium),
],
),
);
}).toList(),
),
],
),
],
),
);
}
}