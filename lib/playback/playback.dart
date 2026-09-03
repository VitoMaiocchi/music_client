import 'package:audio_service/audio_service.dart';
import 'package:music_client/backend/backend.dart';
import 'package:music_client/backend/subsonic.dart';
import 'package:music_client/backend/network_objects.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/playback/queue.dart';

final positionProvider = StreamProvider<Duration>((ref) {
  return ref.read(playbackServiceProvider).player.positionStream;
});

final durationProvider = StreamProvider<Duration?>((ref) {
  return ref.read(playbackServiceProvider).player.durationStream;
});

final playerStateProvider = StreamProvider<PlayerState>((ref) {
  return ref.read(playbackServiceProvider).player.playerStateStream;
});

late PlaybackService playbackService;

final playbackServiceProvider = Provider<PlaybackService>((ref) {
  playbackService.onSkipToNext = () => ref.read(queueProvider.notifier).next();
  playbackService.onSkipToPrevious = () =>
      ref.read(queueProvider.notifier).previous();

  ref.listen(queueProvider, (previous, next) {
    if (previous == next) return;

    if (next.size().$2 <= 0) return;
    final current = next[0];
    final previousID = previous != null
        ? (previous.size().$2 > 0 ? previous[0].$2 : null)
        : null;
    if (current.$2 == previousID) return;
    if (current.$1 == null) return;
    final track = getValue(current.$1!);
    if (track == null) return;

    playbackService.mediaItem.add(
      MediaItem(
        id: current.$2,
        title: track.title,
        artist: track.artist,
        artUri: getCoverUri(track.coverArt, 1000),
      ),
    );

    ref.read(audioSourceProvider(track).future).then((source) async {
      await playbackService.player.setAudioSource(source);
      await playbackService.play();
    });
  });

  playbackService.player.durationStream.listen((duration) {
    final current = playbackService.mediaItem.valueOrNull;
    if (current == null) return;
    playbackService.mediaItem.add(current.copyWith(duration: duration));
  });

  playbackService.player.playerStateStream.listen((state) {
    playbackService.playbackState.add(
      playbackService.playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (state.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        // Which controls show in the collapsed/compact notification view.
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (state.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: state.playing,
        updatePosition: playbackService.player.position,
        bufferedPosition: playbackService.player.bufferedPosition,
        speed: playbackService.player.speed,
      ),
    );

    if (state.processingState == ProcessingState.completed) {
      ref.read(queueProvider.notifier).next();
    }
  });

  return playbackService;
});

class PlaybackService extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();

  void Function()? onSkipToNext;
  void Function()? onSkipToPrevious;

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> skipToNext() async => onSkipToNext?.call();

  @override
  Future<void> skipToPrevious() async => onSkipToPrevious?.call();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  AudioPlayer get player => _player;
}
