import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/mobile_ui/ui_state.dart';
import 'package:music_client/playback/tracklist.dart';
import 'package:music_client/theme.dart';
import 'package:music_client/util/album_art.dart';
import 'package:music_client/backend/network_objects.dart';
import 'package:music_client/util/swipable_tile.dart';

import '../playback/queue.dart';

class TrackWidget extends ConsumerWidget {
  final TrackList tracks;
  final int index;
  static const int _size = AppSizes.trackAlbumArt;

  const TrackWidget({super.key, required this.tracks, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = tracks[index];

    return ObjectProviderBuilder(
      provider: provider,
      buildFunction: (context, track) {
        return SwipeableTile(
          onSwipe: () => {
            if (track != null) ref.read(queueProvider.notifier).add(track),
          },
          color:
              getPrimaryColor(track?.coverArt, context, ref) ??
              AppColors.accentFallback,
          child: InkWell(
            onTap: () => {
              ref.read(queueProvider.notifier).setSource(tracks, index),
              ref
                  .read(appNavigationProvider.notifier)
                  .setPlayerState(PlayerState.expanded),
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: _size.toDouble(),
                    height: _size.toDouble(),
                    child: AlbumArtWidget(
                      coverArt: track?.coverArt,
                      size: _size,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track?.title ?? '',
                            style: AppTextStyles.listTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            track?.artist ?? '',
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
