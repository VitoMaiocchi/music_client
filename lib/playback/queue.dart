import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/backend/types.dart';
import 'package:music_client/playback/tracklist.dart';
import 'package:uuid/uuid.dart';

final queueProvider = NotifierProvider<QueueNotifier, Queue>(QueueNotifier.new);

@immutable
class _QueueEntry {
  final TrackProvider? track; //only defined for UserQueue entries
  final int? position; //only defined for SourceQueue entries
  final String uuid;

  const _QueueEntry(this.track, this.position, this.uuid);
}

class QueueNotifier extends Notifier<Queue> {
  @override
  Queue build() => Queue();

  void setSource(TrackList source, int current) =>
      state = state.setSource(source, current);

  void next() => state = state.next();

  void previous() => state = state.previous();

  void add(TrackProvider track) => state = state.add(track);

  void reorder(int oldIndex, int newIndex) =>
      state = state.reorder(oldIndex, newIndex);
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
      _source = EmptyTrackList(),
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

  int historySize() => -_current;
  int size() => _queueEntries.length - _current;
  int userQueueSize() => _userQueueEnd - _current;

  String getKeyAtPosition(int index) {
    int queueIndex = _current + index;
    assert(queueIndex >= 0 && queueIndex < _queueEntries.length);
    return _queueEntries[queueIndex].uuid;
  }

  (TrackProvider?, String) operator [](int index) {
    int queueIndex = _current + index;
    assert(queueIndex >= 0 && queueIndex < _queueEntries.length);
    final entry = _queueEntries[queueIndex];
    if (entry.track != null) {
      return (entry.track!, entry.uuid);
    } else {
      return (_source[entry.position!], entry.uuid);
    }
  }

  Queue setSource(TrackList newSource, int current) {
    final newQueueEntries = List.generate(
      newSource.length,
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

  Queue add(TrackProvider track) {
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
