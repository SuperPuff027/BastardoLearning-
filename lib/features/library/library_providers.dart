import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../data/library_repository.dart';

final foldersProvider = StreamProvider.autoDispose<List<FolderWithCount>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchFolders(),
);

/// Sets eines Ordners (`null` = Sets ohne Ordner).
final setsInFolderProvider = StreamProvider.autoDispose
    .family<List<SetWithCount>, int?>(
      (ref, folderId) =>
          ref.watch(libraryRepositoryProvider).watchSets(folderId: folderId),
    );

final allSetsProvider = StreamProvider.autoDispose<List<SetWithCount>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchAllSets(),
);

final folderProvider = StreamProvider.autoDispose.family<Folder?, int>(
  (ref, id) => ref.watch(libraryRepositoryProvider).watchFolder(id),
);

final setProvider = StreamProvider.autoDispose.family<VocabSet?, int>(
  (ref, id) => ref.watch(libraryRepositoryProvider).watchSet(id),
);

final cardsProvider = StreamProvider.autoDispose
    .family<List<VocabCard>, ({int setId, bool starredOnly})>(
      (ref, args) => ref
          .watch(libraryRepositoryProvider)
          .watchCards(args.setId, starredOnly: args.starredOnly),
    );
