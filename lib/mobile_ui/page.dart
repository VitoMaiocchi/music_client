import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/backend.dart';
import 'package:music_client/playback.dart';
import 'package:music_client/theme.dart';
import 'package:music_client/util.dart';

import 'ui_state.dart';

class _PageWidget extends StatelessWidget {
  final String title;
  final Widget child;
  final Color backgroundColor;
  final Color? backgroundColorGradient;
  final VoidCallback? onBack;

  const _PageWidget({
    super.key,
    required this.title,
    required this.child,
    this.backgroundColor = Colors.black,
    this.backgroundColorGradient,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).viewPadding.top;

    return Stack(
      fit: StackFit.expand,
      children: [
        // BACKGROUND
        if (backgroundColorGradient != null)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [backgroundColor, backgroundColorGradient!],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          )
        else
          Container(color: backgroundColor),
        //CONTENT
        Padding(
          padding: EdgeInsets.only(top: topInset),
          child: Column(
            children: [
              Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: onBack,
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
      return const _PagePlaceholder('Albums');
    case AppPageTracks():
      return const _PagePlaceholder('Tracks');
    case AppPageSearch():
      return const _PagePlaceholder('Search');
    case AppPageStarredTracks():
      return const _StarredTracksPage();
    case AppPageAlbum():
      return const _PagePlaceholder('Album');
    case AppPagePlaylist():
      return const _PagePlaceholder('Playlist');
    case AppPageArtist():
      return const _PagePlaceholder('Artist');
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
            return TrackWidget(tracks: TrackList(tracks), index: i);
          },
        ),
      ),
    );
  }
}

class _PlaylistsPage extends ConsumerWidget {
  const _PlaylistsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final dpr = MediaQuery.of(context).devicePixelRatio;

    return _PageWidget(
      title: 'Playlists',
      child: playlists.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.progressIndicators),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (playlists) => ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: playlists.length,
          itemBuilder: (context, i) {
            final playlist = playlists[i];
            final cover = ref.watch(
              coverProvider(
                CoverRequest.fromID(
                  playlist.coverArt,
                  (AppSizes.smallAlbumArt * dpr).ceil(),
                ),
              ),
            );
            return ListTile(
              leading: cover.when(
                loading: () => const SizedBox(
                  width: AppSizes.smallAlbumArtD,
                  height: AppSizes.smallAlbumArtD,
                  child: CircularProgressIndicator(
                    color: AppColors.progressIndicators,
                  ),
                ),
                error: (_, _) => const Icon(Icons.playlist_play),
                data: (imageProvider) => Image(
                  image: imageProvider,
                  width: AppSizes.smallAlbumArtD,
                  height: AppSizes.smallAlbumArtD,
                  errorBuilder: (_, _, _) => const Icon(Icons.playlist_play),
                ),
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
