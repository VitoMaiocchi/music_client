import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/backend.dart';
import 'package:music_client/playback.dart';
import 'package:music_client/theme.dart';

// Named record used as a flat item descriptor for the ReorderableListView.
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
    final items = <_ListItem>[];

    // Now Playing
    items.add((
      key: const ValueKey('h:now_playing'),
      relative: null,
      section: 'Now Playing',
      isCurrent: false,
    ));
    items.add((
      key: ValueKey('t:current:${queue[0]?.$2}'),
      relative: null,
      section: null,
      isCurrent: true,
    ));

    // Next Up  (user queue)
    if (uqCount > 0) {
      items.add((
        key: const ValueKey('h:next_up'),
        relative: null,
        section: 'Next Up',
        isCurrent: false,
      ));
      for (var i = 1; i <= uqCount; i++) {
        final t = queue[i];
        if (t != null) {
          items.add((
            key: ValueKey('t:${t.$2}'),
            relative: i,
            section: null,
            isCurrent: false,
          ));
        }
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
        final t = queue[i];
        if (t != null) {
          items.add((
            key: ValueKey('t:${t.$2}'),
            relative: i,
            section: null,
            isCurrent: false,
          ));
        }
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
              return _CurrentTrackTile(key: item.key, track: queue[0]?.$1);
            }

            final track = queue[item.relative!]?.$1;
            if (track == null) return SizedBox.shrink(key: item.key);

            return _QueueTrackTile(
              key: item.key,
              track: track,
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
  final Track? track;

  const _CurrentTrackTile({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white10,
      child: ListTile(
        leading: _CoverArt(
          track: track ?? Track(id: '', title: '', artist: '', coverArt: ''),
        ),
        title: Text(
          track?.title ?? '—',
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
        trailing: const Icon(Icons.volume_up, color: Colors.white54, size: 18),
      ),
    );
  }
}

class _QueueTrackTile extends StatelessWidget {
  final Track track;
  final int listIndex;
  final ValueNotifier<bool> isReordering;

  const _QueueTrackTile({
    super.key,
    required this.track,
    required this.listIndex,
    required this.isReordering,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _CoverArt(track: track),
      title: Text(
        track.title,
        style: const TextStyle(color: Colors.white),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        track.artist,
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
  }
}

class _CoverArt extends StatelessWidget {
  final Track track;

  const _CoverArt({required this.track});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: ColoredBox(
        color: Colors.white12,
        child: SizedBox(
          width: AppSizes.miniAlbumArtD,
          height: AppSizes.miniAlbumArtD,
          child: Consumer(
            builder: (context, ref, _) {
              final cover = ref.watch(
                coverProvider(
                  CoverRequest(track, (AppSizes.miniAlbumArt * dpr).ceil()),
                ),
              );

              return cover.when(
                loading: () => const SizedBox(
                  width: AppSizes.miniAlbumArtD,
                  height: AppSizes.miniAlbumArtD,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, _) => const Icon(Icons.music_note),
                data: (img) => Image(
                  image: img,
                  width: AppSizes.miniAlbumArtD,
                  height: AppSizes.miniAlbumArtD,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
