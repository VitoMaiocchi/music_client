import 'package:music_client/backend.dart';
import 'package:xml/xml.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Track {
  final String id;
  final String title;
  final String artist;
  final String coverArt;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.coverArt,
  });

  factory Track.fromXml(XmlElement element) {
    return Track(
      id: element.getAttribute('id') ?? '',
      title: element.getAttribute('title') ?? '',
      artist: element.getAttribute('artist') ?? '',
      coverArt: element.getAttribute('coverArt') ?? '',
    );
  }

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

final playbackServiceProvider = Provider((ref) {
  return PlaybackService(ref);
});

class PlaybackService {
  final Ref ref;
  final AudioPlayer _player = AudioPlayer();

  PlaybackService(this.ref);

  Future<void> play(Track track) async {
    final source = await ref.read(audioSourceProvider(track).future);

    await _player.setAudioSource(source);
    await _player.play();
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
  Future<void> stop() => _player.stop();

  AudioPlayer get player => _player;
}
