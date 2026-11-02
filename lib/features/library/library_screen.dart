import 'package:flutter/material.dart';

import '../../app/placeholder_view.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meine Sets')),
      body: const PlaceholderView(
        icon: Icons.collections_bookmark_outlined,
        title: 'Noch keine Sets',
        message: 'Hier erscheinen deine Sets und Ordner.',
      ),
    );
  }
}
