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

Future<List<Track>> getStarred() async {
  final response = await http.get(_buildUri('getStarred'));

  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}');
  }

  final body = utf8.decode(response.bodyBytes);
  return _parseStarredTracks(body);
}

List<Track> _parseStarredTracks(String xmlBody) {
  final document = XmlDocument.parse(xmlBody);

  // check for subsonic error
  final status = document
      .findAllElements('subsonic-response')
      .first
      .getAttribute('status');

  if (status != 'ok') {
    final error = document.findAllElements('error').first;
    throw Exception('Subsonic error: ${error.getAttribute('message')}');
  }

  return document
      .findAllElements('song')
      .map((element) => Track.fromXml(element))
      .toList();
}

Future<List<Playlist>> getPlaylists() async {
  final response = await http.get(_buildUri('getPlaylists'));

  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}');
  }

  final body = utf8.decode(response.bodyBytes);
  return _parsePlaylists(body);
}

List<Playlist> _parsePlaylists(String xmlBody) {
  final document = XmlDocument.parse(xmlBody);

  // check for subsonic error
  final status = document
      .findAllElements('subsonic-response')
      .first
      .getAttribute('status');

  if (status != 'ok') {
    final error = document.findAllElements('error').first;
    throw Exception('Subsonic error: ${error.getAttribute('message')}');
  }

  return document
      .findAllElements('playlist')
      .map((element) => Playlist.fromXml(element))
      .toList();
}

Future<(Playlist, List<Track>)> getPlaylist(String id) async {
  final response = await http.get(_buildUri('getPlaylist', {'id': id}));

  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}');
  }

  final body = utf8.decode(response.bodyBytes);
  return _parsePlaylistTracks(body);
}

(Playlist, List<Track>) _parsePlaylistTracks(String xmlBody) {
  final document = XmlDocument.parse(xmlBody);

  final status = document
      .findAllElements('subsonic-response')
      .first
      .getAttribute('status');

  if (status != 'ok') {
    final error = document.findAllElements('error').first;
    throw Exception('Subsonic error: ${error.getAttribute('message')}');
  }

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
  final response = await http.get(_buildUri('getAlbum', {'id': id}));

  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}');
  }

  final body = utf8.decode(response.bodyBytes);
  return _parseAlbumTracks(body);
}

(Album, List<Track>) _parseAlbumTracks(String xmlBody) {
  final document = XmlDocument.parse(xmlBody);

  final status = document
      .findAllElements('subsonic-response')
      .first
      .getAttribute('status');

  if (status != 'ok') {
    final error = document.findAllElements('error').first;
    throw Exception('Subsonic error: ${error.getAttribute('message')}');
  }

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
  final response = await http.get(_buildUri('getArtist', {'id': id}));

  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}');
  }

  final body = utf8.decode(response.bodyBytes);
  return _parseArtist(body);
}

Artist _parseArtist(String xmlBody) {
  final document = XmlDocument.parse(xmlBody);

  final status = document
      .findAllElements('subsonic-response')
      .first
      .getAttribute('status');

  if (status != 'ok') {
    final error = document.findAllElements('error').first;
    throw Exception('Subsonic error: ${error.getAttribute('message')}');
  }

  final artist = document.findAllElements('artist').firstOrNull;
  if (artist == null)
    return Artist(id: '', name: '', coverArt: '', albums: const []);

  return Artist.fromXml(artist);
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

    final uri = _buildUri('getCoverArt', params);
    final image = NetworkImage(uri.toString());
    return image;
  });
}

Future<PaletteGenerator> getPalette(CoverRequest req) async {
  return _paletteCache.putIfAbsent(req, () async {
    final image = await getCover(req);
    return PaletteGenerator.fromImageProvider(image, maximumColorCount: 16);
  });
}

Future<AudioSource> getAudioSource(String trackId) async {
  final params = {'id': trackId};
  final uri = _buildUri('stream', params);
  return AudioSource.uri(Uri.parse(uri.toString()));
}

Uri getCoverUri(String coverArtId, [int? size]) {
  final params = <String, String>{
    'id': coverArtId,
    if (size != null) 'size': size.toString(),
  };

  return _buildUri('getCoverArt', params);
}
