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

class AppPageWidget extends ConsumerWidget {
  final AppPage page;

  const AppPageWidget({super.key, required this.page});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (page) {
      case AppPagePlaylists():
        final value = ref.watch(playlistsProvider).value;
        if (value == null) return _LoadingPage();
        return _PlaylistsPage(
          playlists: value,
          onTap: (playlistId) {
            if (playlistId == "star") {
              return ref
                  .read(appNavigationProvider.notifier)
                  .pushPage(page: const AppPageStarredTracks());
            }
            return ref
                .read(appNavigationProvider.notifier)
                .pushPage(page: AppPagePlaylist(playlistId: playlistId));
          },
        );

      case AppPageAlbums():
        final value = ref.watch(albumListProvider).value;
        if (value == null) return _LoadingPage();
        return _AlbumListPage(
          albums: value,
          onTap: (albumId) {
            ref
                .read(appNavigationProvider.notifier)
                .pushPage(page: AppPageAlbum(albumId: albumId));
          },
        );

      case AppPageTracks():
        final value = ref.watch(topTracksProvider).value;
        if (value == null) return _LoadingPage();
        return _TrackListPage(
          trackList: TopTracks(value),
          title: "Top Tracks",
          coverArt: null,
        );

      case AppPageSearch():
        return const _PagePlaceholder('Search');

      case AppPageStarredTracks():
        final value = ref.watch(starredTracksProvider).value;
        if (value == null) return _LoadingPage();
        return _TrackListPage(
          trackList: StarredTracks(value),
          title: "Liked Songs",
          coverArt: "star",
        );

      case AppPageAlbum():
        final albumId = (page as AppPageAlbum).albumId;
        final value = ref.watch(albumTracksProvider(albumId)).value;
        if (value == null) return _LoadingPage();
        return _TrackListPage(
          trackList: AlbumTracks(value.$2, albumId: albumId),
          title: value.$1.name,
          coverArt: value.$1.coverArt,
        );

      case AppPagePlaylist():
        final playlistId = (page as AppPagePlaylist).playlistId;
        final value = ref.watch(playlistProvider(playlistId)).value;
        if (value == null) return _LoadingPage();
        return _TrackListPage(
          trackList: PlaylistTracks(value.$2, playlistId: playlistId),
          title: value.$1.name,
          coverArt: value.$1.coverArt,
        );

      case AppPageArtist():
        final artistId = (page as AppPageArtist).artistId;
        final value = ref.watch(artistProvider(artistId)).value;
        if (value == null) return _LoadingPage();
        return _ArtistPage(
          artist: value,
          onTap: (albumId) {
            ref
                .read(appNavigationProvider.notifier)
                .pushPage(page: AppPageAlbum(albumId: albumId));
          },
        );
    }
  }
}

class _LoadingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.progressIndicators),
      ),
    );
  }
}

class _PagePlaceholder extends StatelessWidget {
  final String title;

  const _PagePlaceholder(this.title);

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Page not implemented: $title'));
  }
}

class _TrackListPage extends StatelessWidget {
  final TrackList trackList;
  final String title;
  final String? coverArt;

  const _TrackListPage({
    required this.trackList,
    required this.title,
    required this.coverArt,
  });

  @override
  Widget build(BuildContext context) {
    return _PageTemplate(
      title: title,
      coverArt: coverArt,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => TrackWidget(tracks: trackList, index: i),
            childCount: trackList.length,
          ),
        ),
      ],
    );
  }
}

class _PlaylistsPage extends StatelessWidget {
  final List<Playlist> playlists;
  final void Function(String playlistId) onTap;

  const _PlaylistsPage({required this.playlists, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _PageTemplate(
      title: "Playlists",
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate((context, i) {
            if (i == 0) {
              // "Starred" playlist
              return ListTile(
                leading: SizedBox(
                  width: AppSizes.playlistAlbumArt.toDouble(),
                  height: AppSizes.playlistAlbumArt.toDouble(),
                  child: AlbumArtWidget(coverArt: "star"),
                ),
                title: const Text('Liked Songs'),
                onTap: () => onTap("star"),
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
              onTap: () => onTap(playlist.id),
            );
          }, childCount: playlists.length + 1),
        ),
      ],
    );
  }
}

class _AlbumListPage extends StatelessWidget {
  final NetworkList<Album> albums;
  final void Function(String albumId) onTap;

  const _AlbumListPage({required this.albums, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _PageTemplate(
      title: "title",
      slivers: [
        SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, i) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: ObjectProviderBuilder<Album>(
                provider: albums[i],
                buildFunction: (context, album) {
                  return Center(
                    child: GestureDetector(
                      onTap: () {
                        if (album == null) return;
                        onTap(album.id);
                      },
                      child: AlbumArtWidget(coverArt: album?.coverArt),
                    ),
                  );
                },
              ),
            ),
            childCount: albums.itemCount,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1.0,
          ),
        ),
      ],
    );
  }
}

class _ArtistPage extends StatelessWidget {
  final Artist artist;
  final void Function(String albumId) onTap;

  const _ArtistPage({required this.artist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _PageTemplate(
      title: artist.name,
      coverArt: artist.coverArt,
      slivers: [
        SliverGrid(
          delegate: SliverChildBuilderDelegate((context, i) {
            final album = artist.albums[i];
            return GestureDetector(
              onTap: () => onTap(album.id),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 120,
                    child: AlbumArtWidget(coverArt: album.coverArt, size: 120),
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
      ],
    );
  }
}

class _PageTemplate extends ConsumerStatefulWidget {
  final String title;
  final String? coverArt;
  final List<Widget> slivers;

  const _PageTemplate({
    required this.title,
    this.coverArt,
    required this.slivers,
  });

  @override
  ConsumerState<_PageTemplate> createState() => _PageWidgetNewState();
}

class _PageWidgetNewState extends ConsumerState<_PageTemplate> {
  static const double _topBarHeight = 56;

  final _scrollController = ScrollController();
  final _titleKey = GlobalKey();
  double _topBarTitleOpacity = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateTopBarTitle);
    // Big title's layout isn't known until after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTopBarTitle());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateTopBarTitle);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateTopBarTitle() {
    final box = _titleKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    final topInset = MediaQuery.of(context).viewPadding.top;
    final topBarBottom = topInset + _topBarHeight;
    final titleBottomY = box.localToGlobal(Offset.zero).dy + box.size.height;

    // Fade in over the last ~32px before the title fully disappears
    // under the bar; fully hidden -> fully visible in the bar.
    const fadeSpan = 32.0;
    final progress = ((topBarBottom - titleBottomY) / fadeSpan).clamp(0.0, 1.0);

    if (progress != _topBarTitleOpacity) {
      setState(() => _topBarTitleOpacity = progress);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).viewPadding.top;
    final canPop = ref.watch(appNavigationProvider).pageStack.length > 1;

    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover art (or nothing, if coverArt == null —
                    // AlbumArtWidget/AlbumArtBlurred handle null internally).
                    if (widget.coverArt != null)
                      Stack(
                        children: [
                          AlbumArtBlurred(
                            coverArt: widget.coverArt!,
                            opacity: 0.25,
                            fade: true,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(72),
                            child: AlbumArtWidget(coverArt: widget.coverArt),
                          ),
                        ],
                      ),

                    // Big title, directly below the cover.
                    Padding(
                      key: _titleKey,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        widget.coverArt == null
                            ? 8 + topInset + _topBarHeight
                            : 8,
                        16,
                        16,
                      ),
                      child: Text(
                        widget.title,
                        style: AppTextStyles.pageTitleBig,
                      ),
                    ),
                  ],
                ),
              ),

              ...widget.slivers,
            ],
          ),

          // Pinned top bar, drawn over the scroll content.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topInset + _topBarHeight,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              padding: EdgeInsets.only(top: topInset),
              color: AppColors.background.withValues(
                alpha: _topBarTitleOpacity,
              ),
              child: Row(
                children: [
                  if (canPop)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: AppColors.textPrimary,
                      onPressed: () =>
                          ref.read(appNavigationProvider.notifier).popPage(),
                    )
                  else
                    const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: _topBarTitleOpacity,
                      duration: const Duration(milliseconds: 100),
                      child: Text(
                        widget.title,
                        style: AppTextStyles.pageTitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
