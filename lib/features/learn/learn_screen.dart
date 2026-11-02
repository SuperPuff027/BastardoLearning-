import 'package:flutter/material.dart';

import '../../app/placeholder_view.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lernen')),
      body: const PlaceholderView(
        icon: Icons.school_outlined,
        title: 'Nichts fällig',
        message: 'Sobald du Sets hast, findest du hier deine fälligen Karten.',
      ),
    );
  }
}
