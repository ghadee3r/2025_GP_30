import 'package:flutter/material.dart';
import 'page_shell.dart';

class GamesScreen extends StatelessWidget {
const GamesScreen({super.key});

@override
Widget build(BuildContext context) {
return Scaffold(
body: SafeArea(
child: PageShell(
title: 'Games',
subtitle: 'Mini games to train attention',
icon: Icons.sports_esports_rounded,
child: Column(
children: const [
Card(child: ListTile(title: Text('Reaction Time'), subtitle: Text('Tap when you see green'))),
Card(child: ListTile(title: Text('Number Memory'), subtitle: Text('Remember the digits'))),
Card(child: ListTile(title: Text('Focus Runner'), subtitle: Text('Avoid distractions'))),
],
),
),
),
);
}
}