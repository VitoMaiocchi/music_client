import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_client/backend/navidrome.dart';
import 'package:music_client/backend/subsonic.dart';
import 'package:music_client/backend/types.dart';
import 'package:music_client/backend/network_objects.dart';
import 'package:palette_generator/palette_generator.dart';

final starredTracksProvider = FutureProvider<List<Track>>((ref) async {
  return getStarred();
});

final topTracksProvider = FutureProvider<NetworkList<Track>>((ref) async {
  final (tracks, totalCount) = await getTopTracks(offset: 0, size: 50);
  return NetworkList<Track>(
    itemCount: totalCount,
    pageSize: 50,
    initialPage: tracks,
    fetchPage: (offset, size) =>
        getTopTracks(offset: offset, size: size).then((value) => value.$1),
  );
});

final playlistsProvider = FutureProvider<List<Playlist>>((ref) async {
  return getPlaylists();
});

final playlistProvider = FutureProvider.family<(Playlist, List<Track>), String>(
  (ref, id) async {
    return getPlaylist(id);
  },
);

final albumTracksProvider = FutureProvider.family<(Album, List<Track>), String>(
  (ref, id) async {
    return getAlbumTracks(id);
  },
);

final artistProvider = FutureProvider.family<Artist, String>((ref, id) async {
  return getArtist(id);
});

final albumListProvider = FutureProvider<NetworkList<Album>>((ref) async {
  final (albums, totalCount) = await getAlbumList(offset: 0, size: 50);
  return NetworkList<Album>(
    itemCount: totalCount,
    pageSize: 50,
    initialPage: albums,
    fetchPage: (offset, size) =>
        getAlbumList(offset: offset, size: size).then((value) => value.$1),
  );
});

final audioSourceProvider = FutureProvider.family<AudioSource, Track>((
  ref,
  track,
) async {
  return getAudioSource(track.id);
});

final coverProvider = FutureProvider.family<ImageProvider, CoverRequest>((
  ref,
  req,
) async {
  return getCover(req);
});

final paletteProvider = FutureProvider.family<PaletteGenerator, CoverRequest>((
  ref,
  req,
) async {
  return getPalette(req);
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
