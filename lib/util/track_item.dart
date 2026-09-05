import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/backend/types.dart';
import 'package:music_client/mobile_ui/ui_state.dart';
import 'package:music_client/playback/tracklist.dart';
import 'package:music_client/theme.dart';
import 'package:music_client/util/album_art.dart';
import 'package:music_client/backend/network_objects.dart';
import 'package:music_client/util/swipable_tile.dart';

import '../playback/queue.dart';

class ListItem extends StatelessWidget {
  final int artSize;
  final double boderRadius;
  final String? title;
  final String? subtitle;
  final String? coverArt;
  final Widget? trailing;
  final void Function()? onTap;

  const ListItem({
    super.key,
    this.title,
    this.subtitle,
    this.coverArt,
    this.trailing,
    required this.artSize,
    required this.boderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadiusGeometry.circular(boderRadius),
            child: AlbumArtWidget(coverArt: coverArt, size: artSize),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? '',
                    style: AppTextStyles.listTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle ?? '',
                    style: AppTextStyles.listSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );

    if (onTap == null) return content;
    //InkWell so tap work everywhere
    return InkWell(onTap: onTap, child: content);
  }
}

class _TrackListTemplate extends ConsumerWidget {
  final TrackProvider? trackProvider;
  final void Function()? onTap;
  final void Function()? onSwipe;
  final Widget? trailing;

  const _TrackListTemplate({
    required this.trackProvider,
    this.onTap,
    this.onSwipe,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ObjectProviderBuilder(
      provider: trackProvider,
      buildFunction: (context, track) {
        final content = ListItem(
          boderRadius: AppSizes.trackArtCorner,
          artSize: AppSizes.trackAlbumArt,
          title: track?.title,
          subtitle: track?.artist,
          coverArt: track?.coverArt,
          trailing: trailing,
          onTap: onTap,
        );

        if (onSwipe == null) {
          return content;
        }

        return SwipeableTile(
          onSwipe: onSwipe!,
          color:
              getPrimaryColor(track?.coverArt, context, ref) ??
              AppColors.accentFallback,
          child: content,
        );
      },
    );
  }
}

class TrackWidget extends ConsumerWidget {
  final TrackList tracks;
  final int index;

  const TrackWidget({super.key, required this.tracks, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = tracks[index];

    return _TrackListTemplate(
      trackProvider: provider,
      onTap: () => {
        ref.read(queueProvider.notifier).setSource(tracks, index),
        ref
            .read(appNavigationProvider.notifier)
            .setPlayerState(PlayerState.expanded),
      },
      onSwipe: () {
        ref.read(queueProvider.notifier).add(provider);
      },
    );
  }
}

class QueueCurrentTrackTile extends StatelessWidget {
  final TrackProvider? trackProvider;

  const QueueCurrentTrackTile({super.key, required this.trackProvider});

  @override
  Widget build(BuildContext context) {
    return _TrackListTemplate(
      trackProvider: trackProvider,
      trailing: const Icon(Icons.volume_up, color: Colors.white54, size: 18),
    );
  }
}

class QueueTrackTile extends StatelessWidget {
  final TrackProvider? trackProvider;
  final int listIndex;
  final ValueNotifier<bool> isReordering;

  const QueueTrackTile({
    super.key,
    required this.trackProvider,
    required this.listIndex,
    required this.isReordering,
  });

  @override
  Widget build(BuildContext context) {
    return _TrackListTemplate(
      trackProvider: trackProvider,
      trailing: SizedBox(
        width: 40,
        child: Listener(
          onPointerDown: (_) {
            isReordering.value = true;
            HapticFeedback.mediumImpact();
          },
          onPointerUp: (_) {
            isReordering.value = false;
            HapticFeedback.lightImpact();
          },
          onPointerCancel: (_) {
            isReordering.value = false;
            HapticFeedback.lightImpact();
          },
          child: ReorderableDragStartListener(
            index: listIndex,
            child: const Center(
              child: Icon(Icons.drag_handle, color: Colors.white38),
            ),
          ),
        ),
      ),
    );
  }
}
