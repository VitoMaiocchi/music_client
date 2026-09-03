import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:music_client/util/network_objects.dart';
import 'package:xml/xml.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'playback.dart';
import 'package:palette_generator/palette_generator.dart';

final subsonicServiceProvider = Provider((ref) => SubsonicService());

final starredTracksProvider = FutureProvider<List<Track>>((ref) async {
  return ref.read(subsonicServiceProvider).getStarred();
});

final topTracksProvider = FutureProvider<NetworkList<Track>>((ref) async {
  final (tracks, totalCount) = await ref
      .read(subsonicServiceProvider)
      .getTopTracks(offset: 0, size: 50);
  return NetworkList<Track>(
    itemCount: totalCount,
    pageSize: 50,
    initialPage: tracks,
    fetchPage: (offset, size) => ref
        .read(subsonicServiceProvider)
        .getTopTracks(offset: offset, size: size)
        .then((value) => value.$1),
  );
});

final playlistsProvider = FutureProvider<List<Playlist>>((ref) async {
  return ref.read(subsonicServiceProvider).getPlaylists();
});

final playlistProvider = FutureProvider.family<List<Track>, String>((
  ref,
  id,
) async {
  return ref.read(subsonicServiceProvider).getPlaylist(id);
});

final albumTracksProvider = FutureProvider.family<List<Track>, String>((
  ref,
  id,
) async {
  return ref.read(subsonicServiceProvider).getAlbumTracks(id);
});

final artistProvider = FutureProvider.family<Artist, String>((ref, id) async {
  return ref.read(subsonicServiceProvider).getArtist(id);
});

final albumListProvider = FutureProvider<NetworkList<Album>>((ref) async {
  final (albums, totalCount) = await ref
      .read(subsonicServiceProvider)
      .getAlbumList(offset: 0, size: 50);
  return NetworkList<Album>(
    itemCount: totalCount,
    pageSize: 50,
    initialPage: albums,
    fetchPage: (offset, size) => ref
        .read(subsonicServiceProvider)
        .getAlbumList(offset: offset, size: size)
        .then((value) => value.$1),
  );
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

  // --- Navidrome native API auth (JWT) ---
  // Separate from the Subsonic auth above. Used only for /api/* endpoints
  // that have no Subsonic equivalent (e.g. globally top-rated songs).
  String? _jwtToken;
  Future<String>? _loginFuture;

  Future<String> _login() {
    return _loginFuture ??= _performLogin();
  }

  Future<String> _performLogin() async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': _user, 'password': _password}),
    );

    if (response.statusCode != 200) {
      _loginFuture = null;
      throw Exception('Navidrome login failed: HTTP ${response.statusCode}');
    }

    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final token = json['token'] as String?;
    if (token == null || token.isEmpty) {
      _loginFuture = null;
      throw Exception('Navidrome login response missing token');
    }

    _jwtToken = token;
    return token;
  }

  Future<String> _ensureToken() async {
    final token = _jwtToken;
    if (token != null) return token;
    return _login();
  }

  void _captureRotatedToken(http.Response response) {
    final rotated = response.headers['x-nd-authorization'];
    if (rotated == null || rotated.isEmpty) return;
    _jwtToken = rotated.startsWith('Bearer ')
        ? rotated.substring('Bearer '.length)
        : rotated;
  }

  Future<http.Response> _nativeGet(
    String path,
    Map<String, String> params,
  ) async {
    Future<http.Response> attempt() async {
      final token = await _ensureToken();
      final uri = Uri.parse(
        '$_baseUrl/api/$path',
      ).replace(queryParameters: params);
      return http.get(uri, headers: {'x-nd-authorization': 'Bearer $token'});
    }

    var response = await attempt();

    if (response.statusCode == 401) {
      // Token may be stale/expired: force a fresh login and retry once.
      _jwtToken = null;
      _loginFuture = null;
      response = await attempt();
    }

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} for /api/$path');
    }

    _captureRotatedToken(response);
    return response;
  }

  Future<(List<Track>, int)> getTopTracks({
    required int offset,
    int size = 50,
  }) async {
    final response = await _nativeGet('song', {
      '_sort': 'rating',
      '_order': 'DESC',
      '_start': '$offset',
      '_end': '${offset + size}',
    });

    final totalCount = response.headers['x-total-count'];

    final body = utf8.decode(response.bodyBytes);
    final list = jsonDecode(body) as List<dynamic>;
    return (
      list.map((e) => Track.fromJson(e as Map<String, dynamic>)).toList(),
      int.tryParse(totalCount ?? '0') ?? 0,
    );
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

  Future<List<Track>> getPlaylist(String id) async {
    final response = await http.get(_buildUri('getPlaylist', {'id': id}));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final body = utf8.decode(response.bodyBytes);
    return _parsePlaylistTracks(body);
  }

  List<Track> _parsePlaylistTracks(String xmlBody) {
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
    if (playlist == null) return const <Track>[];

    return playlist.findElements('entry').map(Track.fromXml).toList();
  }

  Future<List<Track>> getAlbumTracks(String id) async {
    final response = await http.get(_buildUri('getAlbum', {'id': id}));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final body = utf8.decode(response.bodyBytes);
    return _parseAlbumTracks(body);
  }

  List<Track> _parseAlbumTracks(String xmlBody) {
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
    if (album == null) return const <Track>[];

    return album.findElements('song').map(Track.fromXml).toList();
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
