import 'package:flutter/material.dart';
import 'page_shell.dart';

class ProgressScreen extends StatelessWidget {
const ProgressScreen({super.key});

@override
Widget build(BuildContext context) {
final cs = Theme.of(context).colorScheme;
final text = Theme.of(context).textTheme;

return Scaffold(
body: SafeArea(
child: PageShell(
title: 'Progress',
subtitle: 'Track your productivity and streaks',
icon: Icons.trending_up_rounded,
child: Column(
children: [
Card(
child: SizedBox(
height: 140,
child: Center(
child: Text('Weekly Focus Chart',
style: text.titleMedium?.copyWith(color: cs.primary)),
),
),
),
const SizedBox(height: 12),
Card(
child: ListTile(
title: const Text('Total Focus Time'),
trailing: Text('12h 40m', style: text.titleMedium),
),
),
Card(
child: ListTile(
title: const Text('Current Streak'),
trailing: Text('5 days', style: text.titleMedium),
),
),
],
),
),
),
);
}
}