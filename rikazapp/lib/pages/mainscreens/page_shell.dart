import 'package:flutter/material.dart';

class PageShell extends StatelessWidget {
final String title;
final String subtitle;
final IconData icon;
final Widget? child; // ← محتوى اختياري للصفحة

const PageShell({
super.key,
required this.title,
required this.subtitle,
required this.icon,
this.child, // ← صار موجود
});

@override
Widget build(BuildContext context) {
final cs = Theme.of(context).colorScheme;
final text = Theme.of(context).textTheme;

return SingleChildScrollView(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Header موحّد
Row(
children: [
CircleAvatar(
radius: 24,
// withOpacity -> withValues لتفادي التحذير
backgroundColor: cs.primary.withValues(alpha: .12),
child: Icon(icon, size: 24, color: cs.primary),
),
const SizedBox(width: 12),
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
title,
style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
),
const SizedBox(height: 2),
Text(
subtitle,
style: text.bodySmall?.copyWith(
color: cs.onSurface.withValues(alpha: .6),
),
),
],
),
],
),

const SizedBox(height: 16),

// محتوى الصفحة
if (child != null)
child!
else
Container(
width: double.infinity,
height: 280,
decoration: BoxDecoration(
color: cs.surfaceContainerHighest,
borderRadius: BorderRadius.circular(20),
boxShadow: const [
BoxShadow(
blurRadius: 12,
spreadRadius: -4,
offset: Offset(0, 8),
color: Color(0x1A000000),
)
],
),
child: const Center(child: Text('ضع محتوى الصفحة هنا')),
),
],
),
);
}
}