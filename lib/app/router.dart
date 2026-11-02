import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/learn/learn_screen.dart';
import '../features/library/card_edit_screen.dart';
import '../features/library/folder_screen.dart';
import '../features/library/import_screen.dart';
import '../features/library/library_screen.dart';
import '../features/library/set_detail_screen.dart';
import '../features/library/set_form_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/study/flashcards_screen.dart';
import '../features/study/learn_mode_screen.dart';
import '../features/study/review_screen.dart';
import '../features/study/study_options.dart';
import '../features/study/test_screen.dart';
import '../features/study/write_screen.dart';

abstract final class Routes {
  static const library = '/sets';
  static const learn = '/lernen';
  static const progress = '/fortschritt';
  static const settings = '/einstellungen';

  static String newSet({int? folderId}) =>
      folderId == null ? '$library/neu' : '$library/neu?ordner=$folderId';
  static String folder(int id) => '$library/ordner/$id';
  static String set(int id) => '$library/set/$id';
  static String editSet(int id) => '${set(id)}/bearbeiten';
  static String importCards(int setId) => '${set(setId)}/import';
  static String newCard(int setId) => '${set(setId)}/karte/neu';
  static String card(int setId, int cardId) => '${set(setId)}/karte/$cardId';

  /// Lernmodus eines Sets (Vollbild, ohne Tab-Leiste).
  static String study(int setId, StudyModeKind mode, StudyOptions options) =>
      Uri(
        path: '/ueben/$setId/${mode.path}',
        queryParameters: options.toQuery(),
      ).toString();

  /// Spaced-Repetition-Wiederholung; ohne [setId] für alle Sets.
  static String review({int? setId}) =>
      setId == null ? '/wiederholen' : '/wiederholen?set=$setId';
}

Widget _studyScreen(GoRouterState state, StudyModeKind mode) {
  final setId = _id(state, 'setId');
  final options = StudyOptions.fromQuery(state.uri.queryParameters);
  return switch (mode) {
    StudyModeKind.flashcards => FlashcardsScreen(
      setId: setId,
      options: options,
    ),
    StudyModeKind.learn => LearnModeScreen(setId: setId, options: options),
    StudyModeKind.write => WriteScreen(setId: setId, options: options),
    StudyModeKind.test => TestScreen(setId: setId, options: options),
  };
}

int _id(GoRouterState state, String name) =>
    int.parse(state.pathParameters[name]!);

GoRouter buildRouter() => GoRouter(
  initialLocation: Routes.library,
  routes: [
    for (final mode in StudyModeKind.values)
      GoRoute(
        path: '/ueben/:setId/${mode.path}',
        builder: (_, state) => _studyScreen(state, mode),
      ),
    GoRoute(
      path: '/wiederholen',
      builder: (_, state) => ReviewScreen(
        setId: int.tryParse(state.uri.queryParameters['set'] ?? ''),
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => HomeShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.library,
              builder: (_, _) => const LibraryScreen(),
              routes: [
                GoRoute(
                  path: 'neu',
                  builder: (_, state) => SetFormScreen(
                    initialFolderId: int.tryParse(
                      state.uri.queryParameters['ordner'] ?? '',
                    ),
                  ),
                ),
                GoRoute(
                  path: 'ordner/:folderId',
                  builder: (_, state) =>
                      FolderScreen(folderId: _id(state, 'folderId')),
                ),
                GoRoute(
                  path: 'set/:setId',
                  builder: (_, state) =>
                      SetDetailScreen(setId: _id(state, 'setId')),
                  routes: [
                    GoRoute(
                      path: 'bearbeiten',
                      builder: (_, state) =>
                          SetFormScreen(setId: _id(state, 'setId')),
                    ),
                    GoRoute(
                      path: 'import',
                      builder: (_, state) =>
                          ImportScreen(setId: _id(state, 'setId')),
                    ),
                    GoRoute(
                      path: 'karte/neu',
                      builder: (_, state) =>
                          CardEditScreen(setId: _id(state, 'setId')),
                    ),
                    GoRoute(
                      path: 'karte/:cardId',
                      builder: (_, state) => CardEditScreen(
                        setId: _id(state, 'setId'),
                        cardId: _id(state, 'cardId'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.learn, builder: (_, _) => const LearnScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.progress,
              builder: (_, _) => const ProgressScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.settings,
              builder: (_, _) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark),
            label: 'Sets',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Lernen',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Fortschritt',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Einstellungen',
          ),
        ],
      ),
    );
  }
}
