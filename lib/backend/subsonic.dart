import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:music_client/backend/backend.dart';
import 'package:music_client/backend/types.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:xml/xml.dart';

String get _baseUrl => dotenv.env['SUBSONIC_URL']!;
String get _user => dotenv.env['SUBSONIC_USER']!;
String get _password => dotenv.env['SUBSONIC_PASSWORD']!;

// base params appended to every request
Map<String, String> get _baseParams => {
  'u': _user,
  'p': _password,
  'v': '1.12.0',
  'c': 'myapp',
  'f': 'xml',
};

Uri _buildUri(String endpoint, [Map<String, String>? extraParams]) {
  final params = {..._baseParams, ...?extraParams};
  return Uri.parse('$_baseUrl/rest/$endpoint').replace(queryParameters: params);
}

Future<XmlDocument> _fetchXml(
  String endpoint, [
  Map<String, String>? params,
]) async {
  final response = await http.get(_buildUri(endpoint, params));
  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}');
  }

  final document = XmlDocument.parse(utf8.decode(response.bodyBytes));
  final status = document
      .findAllElements('subsonic-response')
      .first
      .getAttribute('status');

  if (status != 'ok') {
    final error = document.findAllElements('error').first;
    throw Exception('Subsonic error: ${error.getAttribute('message')}');
  }

  return document;
}

Future<List<Track>> getStarred() async {
  final document = await _fetchXml('getStarred');
  return document.findAllElements('song').map(Track.fromXml).toList();
}

Future<List<Playlist>> getPlaylists() async {
  final document = await _fetchXml('getPlaylists');
  return document.findAllElements('playlist').map(Playlist.fromXml).toList();
}

Future<(Playlist, List<Track>)> getPlaylist(String id) async {
  final document = await _fetchXml('getPlaylist', {'id': id});
  final playlist = document.findAllElements('playlist').firstOrNull;

  if (playlist == null) {
    return (
      Playlist(
        id: "",
        name: "",
        coverArt: "",
        songCount: 0,
        duration: Duration(minutes: 0),
      ),
      const <Track>[],
    );
  }

  return (
    Playlist.fromXml(playlist),
    playlist.findElements('entry').map(Track.fromXml).toList(),
  );
}

Future<(Album, List<Track>)> getAlbumTracks(String id) async {
  final document = await _fetchXml('getAlbum', {'id': id});
  final album = document.findAllElements('album').firstOrNull;

  if (album == null) {
    return (
      Album(
        id: "",
        name: "",
        artist: "",
        coverArt: "",
        artistId: "",
        userRating: "",
      ),
      const <Track>[],
    );
  }

  return (
    Album.fromXml(album),
    album.findElements('song').map(Track.fromXml).toList(),
  );
}

Future<Artist> getArtist(String id) async {
  final document = await _fetchXml('getArtist', {'id': id});
  final artist = document.findAllElements('artist').firstOrNull;
  return artist == null
      ? Artist(id: '', name: '', coverArt: '', albums: const [])
      : Artist.fromXml(artist);
}

Future<(List<Album>, int)> getAlbumList({
  required int offset,
  int size = 50,
  String type = 'highest',
}) async {
  final response = await http.get(
    _buildUri('getAlbumList', {
      'type': type,
      'offset': '$offset',
      'size': '$size',
    }),
  );
  final totalCount = response.headers['x-total-count'];
  final body = utf8.decode(response.bodyBytes);
  return (
    XmlDocument.parse(
      body,
    ).findAllElements('album').map(Album.fromXml).toList(),
    int.tryParse(totalCount ?? '0') ?? 0,
  );
}

final HashMap<CoverRequest, ImageProvider> _coverCache = HashMap();
final HashMap<CoverRequest, Future<PaletteGenerator>> _paletteCache = HashMap();

Future<ImageProvider> getCover(CoverRequest req) async {
  return _coverCache.putIfAbsent(req, () {
    final params = <String, String>{
      'id': req.coverID,
      if (req.size != null) 'size': req.size.toString(),
    };

    return NetworkImage(_buildUri('getCoverArt', params).toString());
  });
}

Future<PaletteGenerator> getPalette(CoverRequest req) async {
  return _paletteCache.putIfAbsent(req, () async {
    final image = await getCover(req);
    return PaletteGenerator.fromImageProvider(image, maximumColorCount: 16);
  });
}

Future<AudioSource> getAudioSource(String trackId) async {
  final uri = _buildUri('stream', {'id': trackId});
  return AudioSource.uri(uri);
}

Uri getCoverUri(String coverArtId, [int? size]) {
  final params = <String, String>{
    'id': coverArtId,
    if (size != null) 'size': size.toString(),
  };

  return _buildUri('getCoverArt', params);
}
