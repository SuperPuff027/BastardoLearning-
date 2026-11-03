import '../../data/media/media_store.dart';
import '../../data/vocab/vocab_repository.dart';

class PlatformServices {
  const PlatformServices({required this.media, required this.vocab});

  final MediaStore media;
  final VocabRepository vocab;
}
