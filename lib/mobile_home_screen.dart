import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/backend.dart';
import 'package:music_client/playback.dart';
import 'package:music_client/util.dart';

//PLACEHOLDER
class Player extends ConsumerWidget {
  final double minSize;
  final double maxSize;
  final double factor;

  const Player({
    super.key,
    required this.minSize,
    required this.maxSize,
    required this.factor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    final position = ref
        .watch(positionProvider)
        .maybeWhen(data: (value) => value, orElse: () => Duration.zero);
    final duration = ref
        .watch(durationProvider)
        .maybeWhen(
          data: (value) => value ?? Duration.zero,
          orElse: () => Duration.zero,
        );
    final isPlaying = ref
        .watch(playerStateProvider)
        .maybeWhen(
          data: (value) => value?.playing ?? false,
          orElse: () => false,
        );
    final service = ref.read(playbackServiceProvider);

    final height = minSize + (maxSize - minSize) * factor;
    final collapsed = (1 - factor * 5).clamp(0.0, 1.0);
    final expanded = ((factor - 0.2) * 5).clamp(0.0, 1.0);
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0; // ignore: unnecessary_null_in_if_null_operators

    return Container(
      color: const Color(0xFF111111),
      child: ClipRect(
        child: SizedBox(
          height: height,
          child: Align(
            alignment: Alignment.topCenter,
            child: Stack(
              children: [
                if (collapsed > 0)
                  Opacity(
                    opacity: collapsed,
                    child: SizedBox(
                      height: minSize,
                      child: _Collapsed(
                        track: track,
                        isPlaying: isPlaying,
                        progress: progress,
                        service: service,
                        ref: ref,
                      ),
                    ),
                  ),
                if (expanded > 0)
                  Opacity(
                    opacity: expanded,
                    child: OverflowBox(
                      maxHeight: maxSize,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: maxSize,
                        child: _Expanded(
                          track: track,
                          isPlaying: isPlaying,
                          position: position,
                          duration: duration,
                          progress: progress,
                          service: service,
                          ref: ref,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Collapsed ─────────────────────────────────────────────────────────────────

class _Collapsed extends StatelessWidget {
  final Track? track;
  final bool isPlaying;
  final double progress;
  final PlaybackService service;
  final WidgetRef ref;

  const _Collapsed({
    required this.track,
    required this.isPlaying,
    required this.progress,
    required this.service,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // thin progress line at the very top
        LinearProgressIndicator(
          value: progress,
          minHeight: 2,
          backgroundColor: const Color(0xFF2A2A2A),
          valueColor: const AlwaysStoppedAnimation(Color(0xFFE8E0D0)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _Cover(track: track, size: 40, ref: ref),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track?.title ?? 'Nothing playing',
                        style: const TextStyle(
                          color: Color(0xFFE8E0D0),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                      Text(
                        track?.artist ?? '',
                        style: const TextStyle(
                          color: Color(0xFF888880),
                          fontSize: 12,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                _PlayPauseButton(
                  isPlaying: isPlaying,
                  service: service,
                  size: 32,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Expanded ──────────────────────────────────────────────────────────────────

class _Expanded extends StatelessWidget {
  final Track? track;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double progress;
  final PlaybackService service;
  final WidgetRef ref;

  const _Expanded({
    required this.track,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.progress,
    required this.service,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
      child: Column(
        children: [
          // Cover
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: _Cover(track: track, size: 300, ref: ref, rounded: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Title + artist
          Text(
            track?.title ?? 'Nothing playing',
            style: const TextStyle(
              color: Color(0xFFE8E0D0),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            track?.artist ?? '',
            style: const TextStyle(color: Color(0xFF888880), fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),

          // Seek bar
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: const Color(0xFFE8E0D0),
              inactiveTrackColor: const Color(0xFF2A2A2A),
              thumbColor: const Color(0xFFE8E0D0),
              overlayColor: const Color(0x22E8E0D0),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (v) {
                final ms = (v * duration.inMilliseconds).toInt();
                service.player.seek(Duration(milliseconds: ms));
              },
            ),
          ),

          // Time labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _fmt(position),
                  style: const TextStyle(
                    color: Color(0xFF888880),
                    fontSize: 12,
                  ),
                ),
                Text(
                  _fmt(duration),
                  style: const TextStyle(
                    color: Color(0xFF888880),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Play / pause
          _PlayPauseButton(isPlaying: isPlaying, service: service, size: 56),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Cover extends ConsumerWidget {
  final Track? track;
  final int size;
  final WidgetRef ref;
  final double rounded;

  const _Cover({
    required this.track,
    required this.size,
    required this.ref,
    this.rounded = 6,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (track == null) {
      return _placeholder(rounded);
    }
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cover = ref.watch(
      coverProvider(CoverRequest(track!, size * dpr.ceil())),
    );
    return cover.when(
      data: (img) => ClipRRect(
        borderRadius: BorderRadius.circular(rounded),
        child: Image(image: img, fit: BoxFit.cover),
      ),
      loading: () => _placeholder(rounded),
      error: (_, _) => _placeholder(rounded),
    );
  }

  Widget _placeholder(double r) => ClipRRect(
    borderRadius: BorderRadius.circular(r),
    child: Container(
      color: const Color(0xFF2A2A2A),
      child: const Icon(Icons.music_note, color: Color(0xFF555550)),
    ),
  );
}

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final PlaybackService service;
  final double size;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.service,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isPlaying ? service.pause : service.resume,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFFE8E0D0),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: const Color(0xFF111111),
          size: size * 0.55,
        ),
      ),
    );
  }
}

class Queue extends StatefulWidget {
  final double maxSize;
  final double factor;
  final ScrollController scrollController;
  final bool scrollable;
  final ValueNotifier<bool> isReordering;

  const Queue({
    super.key,
    required this.maxSize,
    required this.factor,
    required this.scrollController,
    required this.scrollable,
    required this.isReordering,
  });

  @override
  State<Queue> createState() => _QueueState();
}

class _QueueState extends State<Queue> {
  late List<int> items;

  @override
  void initState() {
    super.initState();
    items = List.generate(30, (i) => i + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.maxSize * widget.factor,
      color: Colors.blue,
      child: ReorderableListView.builder(
        scrollController: widget.scrollController,
        physics: widget.scrollable
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        onReorderStart: (_) => widget.isReordering.value = true,
        onReorderEnd: (_) => widget.isReordering.value = false,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            widget.isReordering.value = false;
            if (newIndex > oldIndex) newIndex--;
            final item = items.removeAt(oldIndex);
            items.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final value = items[index];

          return ListTile(
            key: ValueKey(value),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                '$value',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Container(height: 14, width: 120, color: Colors.white24),
            subtitle: Container(height: 11, width: 80, color: Colors.white12),
            trailing: Listener(
              onPointerDown: (_) => widget.isReordering.value = true,
              onPointerUp: (_) => widget.isReordering.value = false,
              onPointerCancel: (_) => widget.isReordering.value = false,
              child: ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: const Icon(Icons.drag_handle, color: Colors.white38),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class NavigationBar extends StatelessWidget {
  final double maxSize;
  final double factor;

  const NavigationBar({super.key, required this.maxSize, required this.factor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: maxSize * factor,
      color: Colors.green,
      child: const Center(child: Text("Navigation UI")),
    );
  }
}

class HomeScreenMobile extends StatefulWidget {
  final Duration snapDuration;
  final double miniPlayerHeight;
  final double navigationHeight;
  final Widget background;

  const HomeScreenMobile({
    super.key,
    this.snapDuration = const Duration(milliseconds: 160),
    this.miniPlayerHeight = 60,
    this.navigationHeight = 80,
    this.background = const CurrentPage(),
  });

  @override
  State<HomeScreenMobile> createState() => _HomeScreenMobileState();
}

class _HomeScreenMobileState extends State<HomeScreenMobile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _queueScrollController = ScrollController();
  late VelocityTracker _queueVelocityTracker;
  final _isReordering = ValueNotifier(false);

  bool get _queueAtTop =>
      !_queueScrollController.hasClients ||
      _queueScrollController.position.pixels <= 0;
  bool _draggingQueue = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.snapDuration,
      value: 0,
      lowerBound: 0,
      upperBound: 2,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _queueScrollController.dispose();
    _isReordering.dispose(); // ← clean up
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final miniPlayerGrowth =
        screenHeight - widget.miniPlayerHeight - widget.navigationHeight;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final factor = _controller.value;

        final player = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (d) {
            _controller.value -= d.delta.dy / miniPlayerGrowth;
          },
          onVerticalDragEnd: (d) {
            if (d.primaryVelocity != null && d.primaryVelocity! < -500) {
              _controller.animateTo(factor.ceil().toDouble());
            } else if (d.primaryVelocity != null && d.primaryVelocity! > 500) {
              _controller.animateTo(factor.floor().toDouble());
            } else {
              _controller.animateTo(factor.round().toDouble());
            }
          },
          child: Player(
            minSize: widget.miniPlayerHeight,
            maxSize: screenHeight,
            factor: factor.clamp(0.0, 1.0),
          ),
        );

        final queue = Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            _queueVelocityTracker = VelocityTracker.withKind(e.kind);
            _draggingQueue = false;
          },
          onPointerMove: (e) {
            if (_isReordering.value) return;
            _queueVelocityTracker.addPosition(e.timeStamp, e.position);
            // latch on first qualifying move
            if (!_draggingQueue && _queueAtTop && e.delta.dy > 0) {
              _draggingQueue = true;
            }
            // once latched, own the entire gesture (both directions)
            if (_draggingQueue) {
              _controller.value -= e.delta.dy / miniPlayerGrowth;
            }
          },
          onPointerUp: (_) {
            if (_draggingQueue) {
              final v = _queueVelocityTracker.getVelocity().pixelsPerSecond.dy;
              if (v > 500) {
                _controller.animateTo(factor.floor().toDouble());
              } else if (v < -500) {
                _controller.animateTo(factor.ceil().toDouble());
              } else {
                _controller.animateTo(factor.round().toDouble());
              }
            }
            _draggingQueue = false;
          },
          child: Queue(
            scrollController: _queueScrollController,
            scrollable:
                factor >= 2, // ← disable scroll while dragging into position
            maxSize: screenHeight,
            factor: (factor - 1).clamp(0.0, 1.0),
            isReordering: _isReordering,
          ),
        );

        return Stack(
          children: [
            Offstage(
              offstage: factor >= 1,
              child: SizedBox(
                height:
                    screenHeight -
                    widget.navigationHeight -
                    widget.miniPlayerHeight,
                child: widget.background,
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                player,
                NavigationBar(
                  maxSize: widget.navigationHeight,
                  factor: (1 - factor).clamp(0.0, 1.0),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Offstage(offstage: factor <= 1, child: queue),
            ),
          ],
        );
      },
    );
  }
}

class CurrentPage extends ConsumerWidget {
  const CurrentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(starredTracksProvider);
    final dpr = MediaQuery.of(context).devicePixelRatio;

    return Scaffold(
      // <-- needed, otherwise no background/structure
      appBar: AppBar(title: const Text('Starred')),
      body: tracks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tracks) => ListView.builder(
          itemCount: tracks.length,
          itemBuilder: (context, i) {
            final track = tracks[i];

            return SwipeableTile(
              onSwipeLeft: () => debugPrint('left triggered on ${track.title}'),
              onSwipeRight: () =>
                  debugPrint('right triggered on ${track.title}'),
              child: Consumer(
                builder: (context, ref, _) {
                  final cover = ref.watch(
                    coverProvider(CoverRequest(track, (40 * dpr).ceil())),
                  );

                  return ListTile(
                    onTap: () {
                      ref.read(playbackServiceProvider).play(track);
                    },
                    leading: cover.when(
                      loading: () => const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (_, _) => const Icon(Icons.music_note),
                      data: (img) => Image(
                        image: img,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(track.title),
                    subtitle: Text(track.artist),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
