import 'package:flutter/material.dart';

import '../../app/placeholder_view.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fortschritt')),
      body: const PlaceholderView(
        icon: Icons.insights_outlined,
        title: 'Noch keine Statistik',
        message: 'Lernzeit, Trefferquote und Streaks erscheinen hier.',
      ),
    );
  }
}
