import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:xml/xml.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'playback.dart';
import 'package:palette_generator/palette_generator.dart';

final subsonicServiceProvider = Provider((ref) => SubsonicService());

final starredTracksProvider = FutureProvider<List<Track>>((ref) async {
  return ref.read(subsonicServiceProvider).getStarred();
});

final playlistsProvider = FutureProvider<List<Playlist>>((ref) async {
  return ref.read(subsonicServiceProvider).getPlaylists();
});

final audioSourceProvider = FutureProvider.family<AudioSource, Track>((
  ref,
  track,
) async {
  return ref.read(subsonicServiceProvider).getAudioSource(track.id);
});

final coverProvider = FutureProvider.family<ImageProvider, CoverRequest>((
  ref,
  req,
) async {
  final service = ref.read(subsonicServiceProvider);
  return service.getCover(req);
});

final paletteProvider = FutureProvider.family<PaletteGenerator, CoverRequest>((
  ref,
  req,
) async {
  final service = ref.read(subsonicServiceProvider);
  return service.getPalette(req);
});

class CoverRequest {
  final String coverID;
  final int? size;

  CoverRequest(this.coverID, this.size);
  CoverRequest.fromTrack(Track track, this.size) : coverID = track.coverArt;

  @override
  bool operator ==(Object other) =>
      other is CoverRequest && other.coverID == coverID && other.size == size;

  @override
  int get hashCode => Object.hash(coverID, size);
}

class SubsonicService {
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
    return Uri.parse(
      '$_baseUrl/rest/$endpoint',
    ).replace(queryParameters: params);
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

  final HashMap<CoverRequest, ImageProvider> _coverCache = HashMap();
  final HashMap<CoverRequest, Future<PaletteGenerator>> _paletteCache =
      HashMap();

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
}
