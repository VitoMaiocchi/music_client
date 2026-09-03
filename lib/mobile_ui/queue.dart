import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/backend/types.dart';
import 'package:music_client/playback.dart';
import 'package:music_client/theme.dart';
import 'package:music_client/util/album_art.dart';
import 'package:music_client/backend/network_objects.dart';

typedef _ListItem = ({
  Key key,
  int? relative, // 1-based relative to current; null for non-track rows
  String? section, // non-null → this row is a section header
  bool isCurrent, // true → currently-playing track row
});

class QueueWidget extends ConsumerWidget {
  final double maxSize;
  final double factor;
  final ScrollController scrollController;
  final bool scrollable;
  final ValueNotifier<bool> isReordering;

  const QueueWidget({
    super.key,
    required this.maxSize,
    required this.factor,
    required this.scrollController,
    required this.scrollable,
    required this.isReordering,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueProvider);
    final (_, queueSize, relUserQueueEnd) = queue.size();

    // relUserQueueEnd == relative index of the first autoplay track.
    final uqCount = relUserQueueEnd - 1;
    final apCount = (queueSize - relUserQueueEnd).clamp(0, queueSize);

    // ── Build the flat item list ───────────────────────────────────────────────
    // Keys use getKeyAtPosition, which is a pure metadata lookup — safe to call
    // for every index without forcing a network fetch. Track data itself is
    // only ever pulled via queue[i] inside itemBuilder, which Flutter only
    // invokes for items near the viewport.
    final items = <_ListItem>[];

    // Now Playing
    items.add((
      key: const ValueKey('h:now_playing'),
      relative: null,
      section: 'Now Playing',
      isCurrent: false,
    ));
    items.add((
      key: ValueKey(queueSize > 0 ? 't:${queue.getKeyAtPosition(0)}' : null),
      relative: null,
      section: null,
      isCurrent: true,
    ));

    // Next Up (user queue)
    if (uqCount > 0) {
      items.add((
        key: const ValueKey('h:next_up'),
        relative: null,
        section: 'Next Up',
        isCurrent: false,
      ));
      for (var i = 1; i <= uqCount; i++) {
        items.add((
          key: ValueKey('t:${queue.getKeyAtPosition(i)}'),
          relative: i,
          section: null,
          isCurrent: false,
        ));
      }
    }

    // Autoplay
    if (apCount > 0) {
      items.add((
        key: const ValueKey('h:autoplay'),
        relative: null,
        section: 'Autoplay',
        isCurrent: false,
      ));
      for (var i = relUserQueueEnd; i < queueSize; i++) {
        items.add((
          key: ValueKey('t:${queue.getKeyAtPosition(i)}'),
          relative: i,
          section: null,
          isCurrent: false,
        ));
      }
    }

    // ── Widget ────────────────────────────────────────────────────────────────
    return Container(
      color: AppColors.background,
      child: SizedBox(
        height: maxSize * factor,
        child: ReorderableListView.builder(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          scrollController: scrollController,
          buildDefaultDragHandles:
              false, // only explicit drag handles can initiate
          physics: scrollable
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          onReorderStart: (_) => isReordering.value = true,
          onReorderEnd: (_) => isReordering.value = false,
          onReorder: (oldListIndex, newListIndex) {
            isReordering.value = false;
            if (newListIndex > oldListIndex) newListIndex--;

            final oldRel = items[oldListIndex].relative;
            final newRel = items[newListIndex].relative;

            // Dropping on a header or the current-track row → no-op.
            if (oldRel == null || newRel == null) return;

            ref.read(queueProvider.notifier).reorder(oldRel, newRel);
          },
          itemBuilder: (context, index) {
            final item = items[index];

            if (item.section != null) {
              return _SectionHeader(
                key: item.key,
                title: item.section!,
                isAutoplay: item.section == 'Autoplay',
              );
            }

            if (item.isCurrent) {
              final (track, _) = queueSize > 0 ? queue[0] : (null, '');
              return _CurrentTrackTile(key: item.key, trackProvider: track);
            }

            // Lazy: only pulled for items Flutter actually builds
            // (visible range + cacheExtent). Track may be null while
            // still loading — the tile handles that with a placeholder.
            final (track, _) = queue[item.relative!];

            return _QueueTrackTile(
              key: item.key,
              trackProvider: track,
              listIndex: index,
              isReordering: isReordering,
            );
          },
          proxyDecorator: (child, index, animation) =>
              Material(color: AppColors.elevated, child: child),
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isAutoplay;

  const _SectionHeader({
    super.key,
    required this.title,
    this.isAutoplay = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          if (isAutoplay) ...[
            const SizedBox(width: 6),
            const Icon(Icons.all_inclusive, size: 13, color: Colors.white38),
          ],
        ],
      ),
    );
  }
}

class _CurrentTrackTile extends StatelessWidget {
  final TrackProvider? trackProvider;

  const _CurrentTrackTile({super.key, required this.trackProvider});

  @override
  Widget build(BuildContext context) {
    return ObjectProviderBuilder(
      provider: trackProvider,
      buildFunction: (context, track) {
        return ListTile(
          leading: AlbumArtWidget(
            coverArt: track?.coverArt,
            size: AppSizes.trackAlbumArt,
          ),
          title: Text(
            track?.title ?? 'loading title...',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            track?.artist ?? '',
            style: const TextStyle(color: Colors.white70),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(
            Icons.volume_up,
            color: Colors.white54,
            size: 18,
          ),
        );
      },
    );
  }
}

class _QueueTrackTile extends StatelessWidget {
  final TrackProvider? trackProvider;
  final int listIndex;
  final ValueNotifier<bool> isReordering;

  const _QueueTrackTile({
    super.key,
    required this.trackProvider,
    required this.listIndex,
    required this.isReordering,
  });

  @override
  Widget build(BuildContext context) {
    return ObjectProviderBuilder(
      provider: trackProvider,
      buildFunction: (context, track) {
        return ListTile(
          leading: AlbumArtWidget(
            coverArt: track?.coverArt,
            size: AppSizes.trackAlbumArt,
          ),
          title: Text(
            track?.title ?? 'loading title...',
            style: const TextStyle(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            track?.artist ?? '',
            style: const TextStyle(color: Colors.white70),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
      },
    );
  }
}
