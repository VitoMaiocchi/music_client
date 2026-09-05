import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:music_client/backend/backend.dart';
import 'package:music_client/backend/network_objects.dart';
import 'package:music_client/backend/subsonic.dart';
import 'package:music_client/playback/queue.dart';
import 'package:rxdart/rxdart.dart';

/// What the rest of the app talks to, regardless of platform.
abstract class PlaybackService {
  AudioPlayer get player;

  void Function()? onSkipToNext;
  void Function()? onSkipToPrevious;

  BehaviorSubject<MediaItem?> get mediaItem;
  BehaviorSubject<PlaybackState> get playbackState;

  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
}

/// Forwards transport controls to an AudioPlayer. Shared by both
/// implementations below so they don't each repeat it.
mixin _PlayerControls implements PlaybackService {
  AudioPlayer get _player;

  @override
  AudioPlayer get player => _player;

  @override
  void Function()? onSkipToNext;

  @override
  void Function()? onSkipToPrevious;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async => onSkipToNext?.call();

  @override
  Future<void> skipToPrevious() async => onSkipToPrevious?.call();
}

/// Android + Linux: routed through audio_service, so playback shows up in
/// the OS media session (notification on Android, MPRIS on Linux).
class NativePlaybackService extends BaseAudioHandler with _PlayerControls {
  @override
  final AudioPlayer _player = AudioPlayer();
}

/// Web: audio_service isn't supported there, so this just wraps
/// AudioPlayer directly with its own mediaItem/playbackState.
class WebPlaybackService with _PlayerControls {
  @override
  final AudioPlayer _player = AudioPlayer();

  @override
  final BehaviorSubject<MediaItem?> mediaItem = BehaviorSubject.seeded(null);

  @override
  final BehaviorSubject<PlaybackState> playbackState = BehaviorSubject.seeded(
    PlaybackState(),
  );
}

/// Call once from main() and store the result before runApp().
Future<PlaybackService> initPlaybackService() async {
  if (kIsWeb) return WebPlaybackService();

  if (Platform.isLinux) {
    // just_audio has no built-in Linux backend; route it through
    // media_kit/libmpv before AudioPlayer is created below.
    JustAudioMediaKit.ensureInitialized(linux: true);
  }

  // <NativePlaybackService> must be explicit: AudioService.init can't infer
  // it from this function's Future<PlaybackService> return type.
  return AudioService.init<NativePlaybackService>(
    builder: () => NativePlaybackService(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'music',
      androidNotificationChannelName: 'Music',
    ),
  );
}

late PlaybackService playbackService;

final positionProvider = StreamProvider<Duration>((ref) {
  return ref.read(playbackServiceProvider).player.positionStream;
});

final durationProvider = StreamProvider<Duration?>((ref) {
  return ref.read(playbackServiceProvider).player.durationStream;
});

final playerStateProvider = StreamProvider<PlayerState>((ref) {
  return ref.read(playbackServiceProvider).player.playerStateStream;
});

final playbackServiceProvider = Provider<PlaybackService>((ref) {
  playbackService.onSkipToNext = () => ref.read(queueProvider.notifier).next();
  playbackService.onSkipToPrevious = () =>
      ref.read(queueProvider.notifier).previous();

  ref.listen(queueProvider, (previous, next) {
    if (previous == next) return;

    if (next.size() <= 0) return;
    final current = next[0];
    final previousID = previous != null
        ? (previous.size() > 0 ? previous[0].$2 : null)
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
      if (kIsWeb) {
        //TODO: fix for web
        await playbackService.player.stop();
      }
      await playbackService.player.setAudioSource(source, preload: true);
      await playbackService.play();
    });
  }, fireImmediately: true);

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
