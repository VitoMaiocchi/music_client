import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'subsonic_service.dart';
import 'track.dart';

final subsonicServiceProvider = Provider((ref) => SubsonicService());

final starredTracksProvider = FutureProvider<List<Track>>((ref) async {
  return ref.read(subsonicServiceProvider).getStarred();
});
