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

// ─────────────────────────────────────────────────────────────────────────
// Abstraction
//
// Everything below `PlaybackService` (the providers, the queue-following
// logic, the widgets that consume it) only ever talks to this interface.
// Android gets OS-level media-session integration via `audio_service`;
// Linux has no such integration available, so it's just a thin wrapper
// around the underlying `AudioPlayer` that still exposes the same
// `mediaItem` / `playbackState` streams so the shared code doesn't need to
// know which platform it's running on.
// ─────────────────────────────────────────────────────────────────────────

abstract class PlaybackService {
  AudioPlayer get player;

  void Function()? onSkipToNext;
  void Function()? onSkipToPrevious;

  /// Currently playing track, mirrored to the OS media session on
  /// platforms that support one.
  BehaviorSubject<MediaItem?> get mediaItem;

  /// Current transport/processing state, mirrored to the OS media session
  /// on platforms that support one.
  BehaviorSubject<PlaybackState> get playbackState;

  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
}

// ─────────────────────────────────────────────────────────────────────────
// Android implementation
//
// Extends `BaseAudioHandler` so playback shows up in the notification
// shade / lock screen and responds to Bluetooth/headset controls. Must be
// constructed via `AudioService.init` (see `initPlaybackService` below) so
// the platform channel is actually wired up.
// ─────────────────────────────────────────────────────────────────────────

class AndroidPlaybackService extends BaseAudioHandler
    implements PlaybackService {
  final AudioPlayer _player = AudioPlayer();

  @override
  AudioPlayer get player => _player;

  @override
  void Function()? onSkipToNext;

  @override
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

  // `mediaItem` and `playbackState` are inherited from `BaseAudioHandler`,
  // which already exposes them as `BehaviorSubject`s.
}

// ─────────────────────────────────────────────────────────────────────────
// Linux implementation
//
// No OS media-session API to hook into, so this just drives `AudioPlayer`
// directly and keeps its own `mediaItem`/`playbackState` subjects purely
// for the app's own use (e.g. anything reading `playbackServiceProvider`).
// If Linux desktop-integration (MPRIS) is ever wanted, it would plug in
// here without touching any shared code.
// ─────────────────────────────────────────────────────────────────────────

class LinuxPlaybackService implements PlaybackService {
  // just_audio has no built-in Linux backend, so it must be pointed at
  // media_kit/libmpv before the first AudioPlayer is created. Safe to call
  // more than once; only relevant here since this class is Linux-only.
  LinuxPlaybackService() {
    JustAudioMediaKit.ensureInitialized(linux: true);
  }

  final AudioPlayer _player = AudioPlayer();

  @override
  AudioPlayer get player => _player;

  @override
  void Function()? onSkipToNext;

  @override
  void Function()? onSkipToPrevious;

  @override
  final BehaviorSubject<MediaItem?> mediaItem = BehaviorSubject.seeded(null);

  @override
  final BehaviorSubject<PlaybackState> playbackState = BehaviorSubject.seeded(
    PlaybackState(),
  );

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
}

// ─────────────────────────────────────────────────────────────────────────
// Platform selection
//
// Call this once from `main()` (instead of calling `AudioService.init`
// directly) and store the result in `playbackService` before `runApp`.
// ─────────────────────────────────────────────────────────────────────────

Future<PlaybackService> initPlaybackService() async {
  if (!kIsWeb && Platform.isLinux) {
    return LinuxPlaybackService();
  }

  // Android (and any other audio_service-supported platform): route
  // through AudioService.init so the handler is actually registered with
  // the OS media session / notification channel.
  //
  // The <AndroidPlaybackService> type argument has to be explicit here:
  // AudioService.init<T extends BaseAudioHandler> can't infer T from this
  // function's Future<PlaybackService> return type, since PlaybackService
  // itself isn't bound to BaseAudioHandler. Without it, inference falls
  // back to Never and the builder closure fails to typecheck.
  return AudioService.init<AndroidPlaybackService>(
    builder: () => AndroidPlaybackService(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'music',
      androidNotificationChannelName: 'Music',
    ),
  );
}

/// Set once at startup via `playbackService = await initPlaybackService();`.
late PlaybackService playbackService;

// ─────────────────────────────────────────────────────────────────────────
// Riverpod providers — platform-agnostic from here on
// ─────────────────────────────────────────────────────────────────────────

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
        // Which controls show in the collapsed/compact notification view
        // (Android-only; harmless no-op elsewhere).
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
