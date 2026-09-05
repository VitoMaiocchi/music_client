// NOTE: THIS IS ALL UGLY PLACE HOLDER UI IT WILL BE REPLACED

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/backend/backend.dart';
import 'package:music_client/backend/types.dart';
import 'package:music_client/playback/tracklist.dart';
import 'package:music_client/theme.dart';
import 'package:music_client/util/album_art.dart';
import 'package:music_client/backend/network_objects.dart';
import 'package:music_client/util/track_item.dart';

import 'ui_state.dart';

class _PageWidget extends ConsumerWidget {
  final String title;
  final Widget child;
  final Color? backgroundColorGradient;

  const _PageWidget({
    required this.title,
    required this.child,
    this.backgroundColorGradient,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInset = MediaQuery.of(context).viewPadding.top;

    return Stack(
      fit: StackFit.expand,
      children: [
        // BACKGROUND
        if (backgroundColorGradient != null)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [backgroundColorGradient!, AppColors.background],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          )
        else
          Container(color: AppColors.background),
        //CONTENT
        Padding(
          padding: EdgeInsets.only(top: topInset),
          child: Column(
            children: [
              Row(
                children: [
                  if (ref.watch(appNavigationProvider).pageStack.length > 1)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () =>
                          ref.read(appNavigationProvider.notifier).popPage(),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(title, style: AppTextStyles.pageTitle),
                  ),
                ],
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ],
    );
  }
}

Widget buildPage(AppPage page) {
  switch (page) {
    case AppPagePlaylists():
      return const _PlaylistsPage();
    case AppPageAlbums():
      return const _AlbumListPage();
    case AppPageTracks():
      return const _TopTracksPage();
    case AppPageSearch():
      return const _PagePlaceholder('Search');
    case AppPageStarredTracks():
      return const _StarredTracksPage();
    case AppPageAlbum():
      return _AlbumPage(page.albumId);
    case AppPagePlaylist():
      return _PlaylistPage(page.playlistId);
    case AppPageArtist():
      return _ArtistPage(page.artistId);
  }
}

class _PagePlaceholder extends StatelessWidget {
  final String title;

  const _PagePlaceholder(this.title);

  @override
  Widget build(BuildContext context) {
    return _PageWidget(
      title: title,
      child: const Center(child: Text('Page not implemented')),
    );
  }
}

class _TopTracksPage extends ConsumerWidget {
  const _TopTracksPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(topTracksProvider);
    return _PageWidget(
      title: 'Top Tracks',
      child: tracks.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.progressIndicators),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tracks) => ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: tracks.itemCount,
          itemBuilder: (context, i) {
            return TrackWidget(tracks: TopTracks(tracks), index: i);
          },
        ),
      ),
    );
  }
}

class _StarredTracksPage extends ConsumerWidget {
  const _StarredTracksPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(starredTracksProvider);

    return _PageWidget(
      title: 'Favorites',
      child: tracks.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.progressIndicators),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tracks) => ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: tracks.length,
          itemBuilder: (context, i) {
            return TrackWidget(tracks: StarredTracks(tracks), index: i);
          },
        ),
      ),
    );
  }
}

class _CoverArtTrackList extends StatelessWidget {
  final List<Track> tracks;
  final String coverArt;

  const _CoverArtTrackList({required this.tracks, required this.coverArt});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          expandedHeight: 330,
          toolbarHeight: 0,
          pinned: false,
          floating: false,
          flexibleSpace: Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: AlbumArtWidget(coverArt: coverArt, size: 322),
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, i) {
            return TrackWidget(tracks: StarredTracks(tracks), index: i);
          }, childCount: tracks.length),
        ),
      ],
    );
  }
}

class _PlaylistPage extends ConsumerWidget {
  final String playlistId;
  const _PlaylistPage(this.playlistId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(playlistProvider(playlistId)).value;

    if (value == null) {
      return _PageWidget(
        title: "loading ...",
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.progressIndicators),
        ),
      );
    }

    final playlist = value.$1;
    final tracks = value.$2;

    return _PageWidget(
      backgroundColorGradient: getPrimaryColor(playlist.coverArt, context, ref),
      title: playlist.name,
      child: _CoverArtTrackList(tracks: tracks, coverArt: playlist.coverArt),
    );
  }
}

class _AlbumPage extends ConsumerWidget {
  final String albumId;
  const _AlbumPage(this.albumId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(albumTracksProvider(albumId)).value;

    if (value == null) {
      return _PageWidget(
        title: "loading ...",
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.progressIndicators),
        ),
      );
    }

    final album = value.$1;
    final tracks = value.$2;

    return _PageWidget(
      backgroundColorGradient: getPrimaryColor(album.coverArt, context, ref),
      title: album.name,
      child: _CoverArtTrackList(tracks: tracks, coverArt: album.coverArt),
    );
  }
}

class _PlaylistsPage extends ConsumerWidget {
  const _PlaylistsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);

    return _PageWidget(
      title: 'Playlists',
      child: playlists.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.progressIndicators),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (playlists) => ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: playlists.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              // "Starred" playlist
              return ListTile(
                leading: SizedBox(
                  width: AppSizes.playlistAlbumArt.toDouble(),
                  height: AppSizes.playlistAlbumArt.toDouble(),
                  child: StarArt(),
                ),
                title: const Text('Liked Songs'),
                onTap: () {
                  ref
                      .read(appNavigationProvider.notifier)
                      .pushPage(page: const AppPageStarredTracks());
                },
              );
            }
            final playlist = playlists[i - 1];
            return ListTile(
              leading: AlbumArtWidget(
                coverArt: playlist.coverArt,
                size: AppSizes.playlistAlbumArt,
              ),
              title: Text(playlist.name),
              subtitle: Text('${playlist.songCount} songs'),
              onTap: () {
                ref
                    .read(appNavigationProvider.notifier)
                    .pushPage(page: AppPagePlaylist(playlistId: playlist.id));
              },
            );
          },
        ),
      ),
    );
  }
}

class _AlbumListPage extends ConsumerWidget {
  const _AlbumListPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(albumListProvider);
    return _PageWidget(
      title: 'Albums',
      child: albums.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.progressIndicators),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (albums) => GridView.builder(
          itemCount: albums.itemCount,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: ObjectProviderBuilder<Album>(
              provider: albums[i],
              buildFunction: (context, album) {
                return Center(
                  child: GestureDetector(
                    onTap: () {
                      if (album == null) return;
                      ref
                          .read(appNavigationProvider.notifier)
                          .pushPage(page: AppPageAlbum(albumId: album.id));
                    },
                    child: AlbumArtWidget(coverArt: album?.coverArt),
                  ),
                );
              },
            ),
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1.0,
          ),
        ),
      ),
    );
  }
}

class _ArtistPage extends ConsumerWidget {
  final String artistId;
  const _ArtistPage(this.artistId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(artistProvider(artistId));

    if (value.isLoading) {
      return _PageWidget(
        title: '...',
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.progressIndicators),
        ),
      );
    }

    if (value.hasError) {
      return _PageWidget(
        title: 'Error',
        child: Center(child: Text('Error: ${value.error}')),
      );
    }

    final artist = value.value!;

    return _PageWidget(
      backgroundColorGradient: getPrimaryColor(artist.coverArt, context, ref),
      title: artist.name,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            expandedHeight: 300,
            toolbarHeight: 0,
            pinned: false,
            floating: false,
            flexibleSpace: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: AlbumArtWidget(coverArt: artist.coverArt, size: 292),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(8.0),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, i) {
                final album = artist.albums[i];
                return GestureDetector(
                  onTap: () {
                    ref
                        .read(appNavigationProvider.notifier)
                        .pushPage(page: AppPageAlbum(albumId: album.id));
                  },
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 120,
                        child: AlbumArtWidget(
                          coverArt: album.coverArt,
                          size: 120,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        album.name,
                        style: AppTextStyles.listTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }, childCount: artist.albums.length),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
