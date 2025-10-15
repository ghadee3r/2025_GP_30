import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';

class HomePage extends StatefulWidget {
const HomePage({super.key});

@override
State<HomePage> createState() => _HomePageState(); // ✅ fix
}

class _HomePageState extends State<HomePage> {
bool isConnected = false; // تتبّع الاتصال
bool isLoading = false;
String selectedPreset = 'Choose Preset';
int selectedModeIndex = 0; // 0 = Pomodoro, 1 = Custom
bool hasSelectedMode = false;

static const List<String> presets = [
'Deep Work',
'Morning Focus',
'Study Session',
];

final List<Map<String, String>> modes = const [
{
'title': 'Pomodoro Mode',
'desc': 'Structured focus and break sessions',
},
{
'title': 'Custom Mode',
'desc': 'Set your own duration',
},
];

// اتصال (محاكاة)
Future<void> handleConnect() async {
setState(() => isLoading = true);
await Future.delayed(const Duration(seconds: 2));
if (!mounted) return;
setState(() {
isConnected = true;
isLoading = false;
});
}

void handleSetSession() {
final selectedTitle = modes[selectedModeIndex]['title']!;
final routeName = (selectedTitle == 'Pomodoro Mode') ? '/pomodoro' : '/custom';
Navigator.of(context).pushNamed(routeName);
}

void handlePresetSelect(String preset) {
setState(() => selectedPreset = preset);
Navigator.of(context).pop(); // يقفل الـbottomSheet
}

@override
Widget build(BuildContext context) {
final currentDate = DateTime.now();

return Scaffold(
backgroundColor: Colors.white,
body: Stack(
children: [
// الخلفية
Positioned.fill(
child: Image.asset(
'assets/images/BlueHaze.jpg',
fit: BoxFit.cover,
),
),

// الورقة القابلة للسحب
DraggableScrollableSheet(
initialChildSize: 0.7,
minChildSize: 0.65,
maxChildSize: 0.95,
builder: (context, scrollController) {
return Stack(
children: [
// طبقة بلور
Positioned.fill(
child: ClipRRect(
borderRadius: const BorderRadius.only(
topLeft: Radius.circular(28),
topRight: Radius.circular(28),
),
child: BackdropFilter(
filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
child: Container(color: Colors.white.withOpacity(0.75)),
),
),
),

// المحتوى
Container(
decoration: const BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.only(
topLeft: Radius.circular(28),
topRight: Radius.circular(28),
),
boxShadow: [
BoxShadow(
color: Colors.black26,
offset: Offset(0, -4),
blurRadius: 10,
),
],
),
child: SingleChildScrollView(
controller: scrollController,
padding: const EdgeInsets.all(18),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// المقبض
Center(
child: Container(
width: 54,
height: 6,
margin: const EdgeInsets.only(top: 8, bottom: 12),
decoration: BoxDecoration(
color: Colors.grey[300],
borderRadius: BorderRadius.circular(3),
),
),
),

// الشعار
const Center(
child: CircleAvatar(
radius: 65,
backgroundColor: Colors.transparent,
backgroundImage:
AssetImage('assets/images/RikazLogo.png'),
),
),
const SizedBox(height: 10),

// ترحيب
const Text(
'Welcome back, User!',
style:
TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
),
const Text(
'Ready for a productive day?',
style: TextStyle(color: Colors.grey),
),
const SizedBox(height: 20),

// بطاقة الاتصال
Card(
color: Colors.white,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),
),
elevation: 2,
child: Padding(
padding: const EdgeInsets.all(16),
child: isConnected
? Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: const [
Text(
'Connected',
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
color: Color(0xFF4f46e5),
),
),
SizedBox(height: 8),
Text(
'You can now unlock custom presets and advanced features.',
style: TextStyle(color: Colors.grey),
),
],
)
: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Connect Rikaz Tools',
style: TextStyle(
fontSize: 17,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 6),
const Text(
'Connect to unlock custom presets and advanced features',
style: TextStyle(
fontSize: 13,
color: Colors.grey,
),
),
const SizedBox(height: 10),

// زر السحب للاتصال
Builder(
builder: (context) {
final key =
GlobalKey<SlideActionState>();
return Padding(
padding: const EdgeInsets.symmetric(
horizontal: 8.0),
child: SlideAction(
key: key,
text: "Slide to Connect",
textStyle: const TextStyle(
fontSize: 13,
fontWeight: FontWeight.w600,
color: Colors.white,
),
innerColor: Colors.white,
outerColor:
const Color(0xFF4f46e5),
sliderButtonIcon: const Icon(
Icons.wifi,
color: Colors.black,
size: 15,
),
height: 40,
onSubmit: () async {
await handleConnect();
// اختياري: رجّع السلايدر
Future.delayed(
const Duration(seconds: 1),
() =>
key.currentState?.reset(),
);
return null;
},
),
);
},
),
],
),
),
),

const SizedBox(height: 24),

// البداية
const Text(
'Start Focus Session',
style: TextStyle(
fontSize: 18, fontWeight: FontWeight.bold),
),
const SizedBox(height: 8),

// اختيار الـpreset
GestureDetector(
onTap: () => showModalBottomSheet(
context: context,
builder: (_) => ListView(
shrinkWrap: true,
children: presets
.map((p) => ListTile(
title: Text(p),
onTap: () => handlePresetSelect(p),
))
.toList(),
),
),
child: Container(
padding: const EdgeInsets.symmetric(
horizontal: 14, vertical: 14),
decoration: BoxDecoration(
color: Colors.white,
border: Border.all(
color: const Color(0xFFE6E2DC),
),
borderRadius: BorderRadius.circular(12),
),
child: Row(
mainAxisAlignment:
MainAxisAlignment.spaceBetween,
children: [
Text(
selectedPreset,
style: const TextStyle(
fontSize: 16, color: Colors.black),
),
const Icon(Icons.keyboard_arrow_down,
color: Colors.grey),
],
),
),
),

const SizedBox(height: 24),

// اختيار الـMode (بطاقات زرقاء)
Row(
mainAxisAlignment:
MainAxisAlignment.spaceBetween,
children: List.generate(modes.length, (index) {
final mode = modes[index];
final isSelected =
selectedModeIndex == index;

return Expanded(
child: GestureDetector(
onTap: () {
setState(() {
selectedModeIndex = index;
hasSelectedMode = true;
});
},
child: AnimatedContainer(
duration:
const Duration(milliseconds: 300),
margin: const EdgeInsets.symmetric(
horizontal: 6),
height: 100,
padding: const EdgeInsets.symmetric(
vertical: 14, horizontal: 10),
decoration: BoxDecoration(
color: isSelected
? const Color(0xFF4f46e5)
: Colors.white,
borderRadius:
BorderRadius.circular(16),
border: Border.all(
color: isSelected
? const Color(0xFF4f46e5)
: Colors.grey.shade300,
width: 2,
),
boxShadow: isSelected
? [
BoxShadow(
color:
const Color(0xFF4f46e5)
.withOpacity(0.3),
blurRadius: 8,
offset: const Offset(0, 4),
)
]
: [],
),
child: Column(
mainAxisAlignment:
MainAxisAlignment.center,
children: [
Text(
mode['title']!,
textAlign: TextAlign.center,
style: TextStyle(
fontWeight: FontWeight.bold,
fontSize: 14,
color: isSelected
? Colors.white
: Colors.black,
),
),
const SizedBox(height: 6),
Text(
mode['desc']!,
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 12,
color: isSelected
? Colors.white70
: Colors.grey,
),
),
],
),
),
),
);
}),
),

const SizedBox(height: 24),

// زر Set Session
SizedBox(
width: double.infinity,
child: AnimatedContainer(
duration:
const Duration(milliseconds: 300),
curve: Curves.easeInOut,
child: ElevatedButton(
onPressed: handleSetSession,
style: ElevatedButton.styleFrom(
backgroundColor: hasSelectedMode
? const Color(0xFF000000)
: const Color(0xFF535353),
padding: const EdgeInsets.symmetric(
vertical: 14),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(14),
),
),
child: const Text(
'Set Session',
style: TextStyle(
color: Colors.white,
fontWeight: FontWeight.bold,
fontSize: 16,
),
),
),
),
),

const SizedBox(height: 30),

// المواعيد القادمة
const Text(
'Upcoming Sessions',
style: TextStyle(
fontSize: 18, fontWeight: FontWeight.bold),
),
const SizedBox(height: 10),

Card(
color: const Color.fromRGBO(255, 255, 255, 1),
child: ListTile(
title: const Text('Focus Session'),
subtitle: Text(
'Today, ${currentDate.hour}:00 - Pomodoro',
),
trailing: const Text(
'Edit',
style: TextStyle(
color: Colors.black,
fontWeight: FontWeight.bold,
),
),
),
),
Card(
color: const Color.fromRGBO(255, 255, 255, 1),
child: const ListTile(
title: Text('Deep Work'),
subtitle: Text('Tomorrow, 9:00 AM - Custom'),
trailing: Text(
'Edit',
style: TextStyle(
color: Colors.black,
fontWeight: FontWeight.bold,
),
),
),
),
],
),
),
),
],
);
},
),
],
),
);
}
}