import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:music_client/backend.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final queueProvider = NotifierProvider<QueueNotifier, Queue>(QueueNotifier.new);

final positionProvider = StreamProvider<Duration>((ref) {
  return ref.read(playbackServiceProvider).player.positionStream;
});

final durationProvider = StreamProvider<Duration?>((ref) {
  return ref.read(playbackServiceProvider).player.durationStream;
});

final playerStateProvider = StreamProvider<PlayerState>((ref) {
  return ref.read(playbackServiceProvider).player.playerStateStream;
});

@immutable
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

@immutable
class Playlist {
  final String id;
  final String name;
  final String coverArt;
  final int songCount;
  final Duration duration;

  const Playlist({
    required this.id,
    required this.name,
    required this.coverArt,
    required this.songCount,
    required this.duration,
  });

  factory Playlist.fromXml(XmlElement element) {
    return Playlist(
      id: element.getAttribute('id') ?? '',
      name: element.getAttribute('name') ?? '',
      coverArt: element.getAttribute('coverArt') ?? '',
      songCount: int.tryParse(element.getAttribute('songCount') ?? '0') ?? 0,
      duration: Duration(
        seconds: int.tryParse(element.getAttribute('duration') ?? '0') ?? 0,
      ),
    );
  }
}

@immutable
class TrackList {
  final List<Track> tracks;

  const TrackList(this.tracks);
}

class StarredTracks extends TrackList {
  const StarredTracks(super.tracks);
}

class AlbumTracks extends TrackList {
  final String albumId;

  const AlbumTracks(super.tracks, {required this.albumId});
}

class PlaylistTracks extends TrackList {
  final String playlistId;

  const PlaylistTracks(super.tracks, {required this.playlistId});
}

class EmptyTrackList extends TrackList {
  const EmptyTrackList() : super(const []);
}

@immutable
class _QueueEntry {
  final Track? track; //only defined for UserQueue entries
  final int? position; //only defined for SourceQueue entries
  final String uuid;

  const _QueueEntry(this.track, this.position, this.uuid);
}

@immutable
class Queue {
  final Queue? _previousQueue;
  final TrackList _source;
  final List<_QueueEntry> _queueEntries;
  final int _current;
  final int _userQueueEnd;

  Queue()
    : _previousQueue = null,
      _source = const EmptyTrackList(),
      _queueEntries = [],
      _current = 0,
      _userQueueEnd = 0;

  const Queue._internal(
    this._previousQueue,
    this._source,
    this._queueEntries,
    this._current,
    this._userQueueEnd,
  );

  (int, int, int) size() {
    // (history, queue size, userqueue end)
    return (
      -_current,
      _queueEntries.length - _current,
      _userQueueEnd - _current,
    );
  }

  // Returns track at index relative to current Track and its uuid. Returns null if index is out of bounds.
  (Track, String)? operator [](int index) {
    int queueIndex = _current + index;
    if (queueIndex < 0 || queueIndex >= _queueEntries.length) return null;
    final entry = _queueEntries[queueIndex];
    if (entry.track != null) {
      return (entry.track!, entry.uuid);
    } else {
      return (_source.tracks[entry.position!], entry.uuid);
    }
  }

  Queue setSource(TrackList newSource, int current) {
    final newQueueEntries = List.generate(
      newSource.tracks.length,
      (i) => _QueueEntry(null, i, const Uuid().v4()),
    );
    return Queue._internal(
      this,
      newSource,
      newQueueEntries,
      current,
      current + 1,
    );
  }

  Queue next() {
    if (_current + 1 > _queueEntries.length) return this;
    final newCurrent = _current + 1;
    final newUserQueueEnd = _userQueueEnd <= newCurrent
        ? newCurrent + 1
        : _userQueueEnd;
    return Queue._internal(
      _previousQueue,
      _source,
      _queueEntries,
      newCurrent,
      newUserQueueEnd,
    );
  }

  Queue previous() {
    if (_current - 1 < 0) return _previousQueue ?? this;
    return Queue._internal(
      _previousQueue,
      _source,
      _queueEntries,
      _current - 1,
      _userQueueEnd,
    );
  }

  Queue add(Track track) {
    final newQueue = List.of(_queueEntries)
      ..insert(_userQueueEnd, _QueueEntry(track, null, const Uuid().v4()));
    return Queue._internal(
      _previousQueue,
      _source,
      newQueue,
      _current,
      _userQueueEnd + 1,
    );
  }

  Queue reorder(int oldIndex, int newIndex) {
    if (oldIndex <= 0 || newIndex <= 0) return this;
    if (oldIndex == newIndex) return this;

    final absOld = _current + oldIndex;
    final absNew = _current + newIndex;
    if (absOld >= _queueEntries.length || absNew >= _queueEntries.length) {
      return this;
    }

    // absNew lives in the post-remove list. Recover the original-index destination
    // so the zone comparison against _userQueueEnd is correct.
    final wasUserQueue = absOld < _userQueueEnd;
    final originalDest = absOld < absNew ? absNew + 1 : absNew;
    final isNowUserQueue = originalDest < _userQueueEnd;

    int newUserQueueEnd = _userQueueEnd;
    if (wasUserQueue && !isNowUserQueue) newUserQueueEnd--;
    if (!wasUserQueue && isNowUserQueue) newUserQueueEnd++;

    final newEntries = List.of(_queueEntries);
    final entry = newEntries.removeAt(absOld);
    newEntries.insert(absNew, entry);

    return Queue._internal(
      _previousQueue,
      _source,
      newEntries,
      _current,
      newUserQueueEnd,
    );
  }
}

class QueueNotifier extends Notifier<Queue> {
  @override
  Queue build() => Queue();

  void setSource(TrackList source, int current) =>
      state = state.setSource(source, current);

  void next() => state = state.next();

  void previous() => state = state.previous();

  void add(Track track) => state = state.add(track);

  void reorder(int oldIndex, int newIndex) =>
      state = state.reorder(oldIndex, newIndex);
}

late PlaybackService playbackService;

final playbackServiceProvider = Provider<PlaybackService>((ref) {
  playbackService.onSkipToNext = () => ref.read(queueProvider.notifier).next();
  playbackService.onSkipToPrevious = () =>
      ref.read(queueProvider.notifier).previous();

  ref.listen(queueProvider, (previous, next) {
    if (previous == next) return;

    final current = next[0];
    if (current == null) return;
    if (current.$2 == previous?[0]?.$2) return;

    playbackService.mediaItem.add(
      MediaItem(
        id: current.$2,
        title: current.$1.title,
        artist: current.$1.artist,
        artUri: SubsonicService().getCoverUri(current.$1.coverArt, 1000),
      ),
    );

    ref.read(audioSourceProvider(current.$1).future).then((source) async {
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
