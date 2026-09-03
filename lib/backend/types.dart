import 'package:flutter/material.dart';
import 'package:music_client/backend/network_objects.dart';
import 'package:xml/xml.dart';

typedef TrackProvider = ObjectProvider<Track>;

@immutable
class Track extends ObjectProvider<Track> {
  final String id;
  final String title;
  final String artist;
  final String coverArt;
  final String artistId;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.coverArt,
    required this.artistId,
  });

  factory Track.fromXml(XmlElement element) {
    return Track(
      id: element.getAttribute('id') ?? '',
      title: element.getAttribute('title') ?? '',
      artist: element.getAttribute('artist') ?? '',
      coverArt: element.getAttribute('coverArt') ?? '',
      artistId: element.getAttribute('artistId') ?? '',
    );
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    final hasCoverArt = json['hasCoverArt'] as bool? ?? false;
    return Track(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      artistId: json['artistId'] as String? ?? '',
      // Navidrome serves cover art by track id when the track has embedded art
      coverArt: hasCoverArt ? (json['id'] as String? ?? '') : '',
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
class Album extends ObjectProvider<Album> {
  final String id;
  final String name;
  final String artist;
  final String coverArt;
  final String artistId;
  final String userRating;

  const Album({
    required this.id,
    required this.name,
    required this.artist,
    required this.coverArt,
    required this.artistId,
    required this.userRating,
  });

  factory Album.fromXml(XmlElement element) {
    return Album(
      id: element.getAttribute('id') ?? '',
      name: element.getAttribute('name') ?? '',
      artist: element.getAttribute('artist') ?? '',
      coverArt: element.getAttribute('coverArt') ?? '',
      artistId: element.getAttribute('artistId') ?? '',
      userRating: element.getAttribute('userRating') ?? '',
    );
  }
}

@immutable
class Artist {
  final String id;
  final String name;
  final String coverArt;
  final List<Album> albums;

  const Artist({
    required this.id,
    required this.name,
    required this.coverArt,
    required this.albums,
  });

  factory Artist.fromXml(XmlElement element) {
    return Artist(
      id: element.getAttribute('id') ?? '',
      name: element.getAttribute('name') ?? '',
      coverArt: element.getAttribute('coverArt') ?? '',
      albums: element.findElements('album').map(Album.fromXml).toList(),
    );
  }
}
