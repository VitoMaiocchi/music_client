import 'package:flutter/material.dart';
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

class _QueueEntry {
  final Track? track; //only defined for UserQueue entries
  final int? position; //only defined for SourceQueue entries

  const _QueueEntry(this.track, this.position);
}

class _Queue {
  final TrackList source;
  final List<_QueueEntry> _queueEntries;
  int _current = 0;
  int _userQueueEnd = 0;

  _Queue(this.source)
    : _queueEntries = List.generate(
        source.tracks.length,
        (i) => _QueueEntry(null, i),
      );

  (int, int, int) size() {
    // (history, queue size, userqueue end)
    return (
      -_current,
      _queueEntries.length - _current,
      _userQueueEnd - _current,
    );
  }

  // Returns track at index relative to current Track
  Track? operator [](int index) {
    int queueIndex = _current + index;
    if (queueIndex < 0 || queueIndex >= _queueEntries.length) return null;
    final entry = _queueEntries[queueIndex];
    if (entry.track != null) {
      return entry.track!;
    } else {
      return source.tracks[entry.position!];
    }
  }

  Track? next() {
    if (_current + 1 >= _queueEntries.length) return null;
    _current++;
    return this[0];
  }

  Track? previous() {
    if (_current - 1 < 0) return null;
    _current--;
    return this[0];
  }

  Track add(Track track) {
    _queueEntries.insert(_userQueueEnd, _QueueEntry(track, null));
    _userQueueEnd++;
    return this[0]!;
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex <= _current || oldIndex >= _queueEntries.length) return;
    if (newIndex <= _current || newIndex >= _queueEntries.length) return;
    final entry = _queueEntries.removeAt(oldIndex);
    _queueEntries.insert(newIndex, entry);
  }
}

// class _Queue {
//   final TrackList source;
//   final List<int> _order;
//   final List<Track> _userQueue = [];
//   final List<_QueueEntry> _history = [];
//   int _current = 0;
//   bool playingQueue = false;

//   _Queue(this.source) : _order = List.generate(source.tracks.length, (i) => i);

//   (int, int) size() {
//     return (-_history.length, _userQueue.length + _order.length - _current);
//   }

//   // Returns track at index relative to current Track
//   Track? operator [](int index) {
//     if (index < 0) {
//       int i = _history.length + index;
//       if (i < 0) return null;
//       return _history[i].track;
//     }

//     if (playingQueue) {
//       if (index < _userQueue.length) {
//         return _userQueue[index];
//       }
//       int orderIndex = _current + index - _userQueue.length;
//       if (orderIndex >= _order.length) return null;
//       return source.tracks[_order[orderIndex]];
//     }

//     if (index == 0) {
//       if (_current >= _order.length) return null;
//       return source.tracks[_order[_current]];
//     }

//     if (index + 1 < _userQueue.length) {
//       return _userQueue[index + 1];
//     }
//     int orderIndex = _current + index - _userQueue.length;
//     if (orderIndex >= _order.length) return null;
//     return source.tracks[_order[orderIndex]];
//   }

//   Track? next() {
//     if (playingQueue) {
//       assert(_userQueue.isNotEmpty);
//       final track = _userQueue.removeAt(0);
//       _history.add(_QueueEntry(track, null));
//       if (_userQueue.isEmpty) playingQueue = false;
//       return this[0];
//     }

//     if (_current >= _order.length) return null;
//     _history.add(_QueueEntry(null, _current));

//     if (_userQueue.isNotEmpty) {
//       playingQueue = true;
//       return this[0];
//     }

//     if (_current < _order.length) _current++;
//     return this[0];
//   }

//   Track? previous() {
//     if (_history.isEmpty) return null;
//     final last = _history.removeLast();
//     if (last.track != null) {
//       _userQueue.insert(0, last.track!);
//       playingQueue = true;
//     } else {
//       _current = last.position!;
//       playingQueue = false;
//     }
//     return this[0];
//   }

//   Track add(Track track) {
//     _userQueue.add(track);
//     if (_current >= _order.length) playingQueue = true;
//     return this[0]!;
//   }

//   // List<QueueItem> constructQueueItemList() {
//   //   if (size().$2 == 0) {
//   //     return [const QueueItem(QueueItemType.empty, null)];
//   //   }

//   //   List<QueueItem> items = [];
//   //   items.add(const QueueItem(QueueItemType.start, null));
//   //   if (playingQueue) {
//   //     items.add(QueueItem(QueueItemType.track, _userQueue[0]));
//   //     if (_userQueue.length > 1) {
//   //       items.add(const QueueItem(QueueItemType.queue, null));
//   //       for (int i = 1; i < _userQueue.length; i++) {
//   //         items.add(QueueItem(QueueItemType.track, _userQueue[i]));
//   //       }
//   //     }
//   //     if (_current < _order.length) {
//   //       items.add(const QueueItem(QueueItemType.source, null));
//   //       for (int i = _current; i < _order.length; i++) {
//   //         items.add(QueueItem(QueueItemType.track, source.tracks[_order[i]]));
//   //       }
//   //     }
//   //   } else {
//   //     if (_current < _order.length) {
//   //       items.add(
//   //         QueueItem(QueueItemType.track, source.tracks[_order[_current]]),
//   //       );
//   //     }
//   //     if (_userQueue.isNotEmpty) {
//   //       items.add(const QueueItem(QueueItemType.queue, null));
//   //       for (int i = 0; i < _userQueue.length; i++) {
//   //         items.add(QueueItem(QueueItemType.track, _userQueue[i]));
//   //       }
//   //     }
//   //     if (_current + 1 < _order.length) {
//   //       items.add(const QueueItem(QueueItemType.source, null));
//   //       for (int i = _current + 1; i < _order.length; i++) {
//   //         items.add(QueueItem(QueueItemType.track, source.tracks[_order[i]]));
//   //       }
//   //     }
//   //   }

//   //   return items;
//   // }
// }

enum QueueItemType { start, queue, source, track, empty }

class QueueItem {
  final QueueItemType type;
  final Track? track;
  const QueueItem(this.type, this.track);
}

class Queue extends ChangeNotifier {
  _Queue? _queue;
  _Queue? _lastQueue;

  (int, int, int) size() {
    if (_queue == null) return (0, 0, 0);
    return _queue!.size();
  }

  Track? operator [](int index) => _queue?[index];
  Track? next() {
    final track = _queue?.next();
    notifyListeners();
    return track;
  }

  Track? previous() {
    Track? track = _queue?.previous();
    if (track != null) {
      _queue = _lastQueue;
      _lastQueue = null;
      track = _queue?[0];
    }
    notifyListeners();
    return track;
  }

  Track add(Track track) {
    _queue ??= _Queue(EmptyTrackList());
    final current = _queue!.add(track);
    notifyListeners();
    return current;
  }

  Track? setSource(TrackList source) {
    if (_queue != null) {
      _lastQueue = _queue;
    }
    _queue = _Queue(source);
    notifyListeners();
    return _queue![0];
  }

  void reorder(int oldIndex, int newIndex) {
    if (_queue == null) return;
    _queue!.reorder(oldIndex, newIndex);
    notifyListeners();
  }
}

final playbackServiceProvider = Provider((ref) {
  return PlaybackService(ref);
});

class CurrentTrackNotifier extends Notifier<Track?> {
  @override
  Track? build() => null;

  void set(Track? track) => state = track;
}

final currentTrackProvider = NotifierProvider<CurrentTrackNotifier, Track?>(
  CurrentTrackNotifier.new,
);

final positionProvider = StreamProvider<Duration>((ref) {
  return ref.read(playbackServiceProvider).player.positionStream;
});

final durationProvider = StreamProvider<Duration?>((ref) {
  return ref.read(playbackServiceProvider).player.durationStream;
});

final playerStateProvider = StreamProvider<PlayerState>((ref) {
  return ref.read(playbackServiceProvider).player.playerStateStream;
});

class PlaybackService {
  final Ref ref;
  final AudioPlayer _player = AudioPlayer();
  final Queue queue = Queue();

  PlaybackService(this.ref);

  Future<void> play(List<Track> tracks, int index) async {
    queue.setSource(TrackList(tracks));
    final track = tracks[index];
    ref.read(currentTrackProvider.notifier).set(track);
    final source = await ref.read(audioSourceProvider(track).future);
    await _player.setAudioSource(source);
    await _player.play();
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
  Future<void> stop() => _player.stop();
  AudioPlayer get player => _player;
}
