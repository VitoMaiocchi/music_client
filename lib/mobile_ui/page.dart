import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/backend.dart';
import 'package:music_client/playback.dart';
import 'package:music_client/theme.dart';
import 'package:music_client/util.dart';

class AppPage extends StatelessWidget {
  final String title;
  final Widget child;
  final Color backgroundColor;
  final Color? backgroundColorGradient;
  final VoidCallback? onBack;

  const AppPage({
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

class TrackWidget extends ConsumerWidget {
  final TrackList tracks;
  final int index;
  static const int _size = AppSizes.miniAlbumArt;

  const TrackWidget({super.key, required this.tracks, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = tracks.tracks[index];

    return AlbumArtProvider(
      track: track,
      highRes: false,
      builder: (context, color1, color2, cover) {
        return SwipeableTile(
          onSwipe: () => ref.read(queueProvider.notifier).add(track),
          color: color1 ?? AppColors.accentFallback,
          child: InkWell(
            onTap: () =>
                ref.read(queueProvider.notifier).setSource(tracks, index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: _size.toDouble(),
                    height: _size.toDouble(),
                    child: cover,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: AppTextStyles.listTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            track.artist,
                            style: AppTextStyles.listSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class StarredTracksPage extends ConsumerWidget {
  const StarredTracksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(starredTracksProvider);

    return AppPage(
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
