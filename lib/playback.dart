import 'package:flutter/material.dart';
import 'package:music_client/backend.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final queueProvider = NotifierProvider<QueueNotifier, Queue>(QueueNotifier.new);

final playbackServiceProvider = Provider((ref) {
  return PlaybackService(ref);
});

final positionProvider = StreamProvider<Duration>((ref) {
  return ref.read(playbackServiceProvider).player.positionStream;
});

final durationProvider = StreamProvider<Duration?>((ref) {
  return ref.read(playbackServiceProvider).player.durationStream;
});

final playerStateProvider = StreamProvider<PlayerState>((ref) {
  return ref.read(playbackServiceProvider).player.playerStateStream;
});

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
class TrackList {
  final List<Track> tracks;

  const TrackList(this.tracks);
}

class StarredTracks extends TrackList {
  const StarredTracks(super.tracks);
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
      _userQueueEnd = 1;

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
    return Queue._internal(
      _previousQueue,
      _source,
      _queueEntries,
      _current + 1,
      _userQueueEnd + 1,
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

class PlaybackService {
  final Ref _ref;
  final AudioPlayer _player = AudioPlayer();

  PlaybackService(this._ref) {
    _ref.listen(queueProvider, (previous, next) {
      if (previous == next) return;
      final current = next[0];
      if (current == null) return;
      if (current.$2 == previous?[0]?.$2) return;
      _ref.read(audioSourceProvider(current.$1).future).then((source) async {
        await _player.setAudioSource(source);
        await _player.play();
      });
    });
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _ref.read(queueProvider.notifier).next();
      }
    });
  }

  Future<void> pause() => _player.pause();
  Future<void> play() => _player.play();
  AudioPlayer get player => _player;
}
