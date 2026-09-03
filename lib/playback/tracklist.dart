import 'package:flutter/material.dart';
import 'package:music_client/backend/network_objects.dart';
import 'package:music_client/backend/types.dart';

@immutable
abstract class TrackList {
  TrackProvider operator [](int index);
  int get length;
}

@immutable
class SimpleTrackList extends TrackList {
  final List<Track> _tracks;

  SimpleTrackList(this._tracks);

  @override
  Track operator [](int index) => _tracks[index];

  @override
  int get length => _tracks.length;
}

@immutable
class StarredTracks extends SimpleTrackList {
  StarredTracks(super.tracks);
}

@immutable
class TopTracks extends TrackList {
  final NetworkList<Track> _tracks;

  TopTracks(this._tracks);

  @override
  TrackProvider operator [](int index) => _tracks[index];

  @override
  int get length => _tracks.itemCount;
}

@immutable
class AlbumTracks extends SimpleTrackList {
  final String albumId;

  AlbumTracks(super.tracks, {required this.albumId});
}

@immutable
class PlaylistTracks extends SimpleTrackList {
  final String playlistId;

  PlaylistTracks(super.tracks, {required this.playlistId});
}

@immutable
class EmptyTrackList extends TrackList {
  @override
  Track operator [](int index) => throw RangeError('Index out of range');

  @override
  int get length => 0;
}
