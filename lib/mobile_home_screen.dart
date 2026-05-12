import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/music_providers.dart';
import 'package:music_client/util.dart';

class Player extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      height: minSize + (maxSize - minSize) * factor,
      color: Colors.red,
      child: const Center(child: Text("Player UI")),
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

    return Scaffold(
      // <-- needed, otherwise no background/structure
      appBar: AppBar(title: const Text('Starred')),
      body: tracks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tracks) => ListView.builder(
          itemCount: tracks.length,
          itemBuilder: (context, i) => SwipeableTile(
            onSwipeLeft: () =>
                debugPrint('left triggered on ${tracks[i].title}'),
            onSwipeRight: () =>
                debugPrint('right triggered on ${tracks[i].title}'),
            child: ListTile(
              title: Text(tracks[i].title),
              subtitle: Text(tracks[i].artist),
            ),
          ),
        ),
      ),
    );
  }
}
