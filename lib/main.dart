import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music_client/music_providers.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "credentials.env");
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Client',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        textTheme: GoogleFonts.notoSansTextTheme(),
      ),
      home: Scaffold(body: PlayerSheet()),
    );
  }
}

Container getPlayerContent({
  required double minSize,
  required double maxSize,
  required double factor,
}) {
  return Container(
    height: minSize + (maxSize - minSize) * factor,
    color: Colors.red,
    child: const Center(child: Text("Player UI")),
  );
}

Container getQueueContent({required double maxSize, required double factor}) {
  return Container(
    height: maxSize * factor,
    color: Colors.blue,
    child: const Center(child: Text("Queue UI")),
  );
}

Container getNavigationContent({
  required double maxSize,
  required double factor,
}) {
  return Container(
    height: maxSize * factor,
    color: Colors.green,
    child: const Center(child: Text("Navigation UI")),
  );
}

class PlayerSheet extends StatefulWidget {
  final Duration snapDuration;
  final double miniPlayerHeight;
  final double navigationHeight;
  final Widget background;

  const PlayerSheet({
    super.key,
    this.snapDuration = const Duration(milliseconds: 160),
    this.miniPlayerHeight = 60,
    this.navigationHeight = 80,
    this.background = const StarredScreen(),
  });

  @override
  State<PlayerSheet> createState() => _PlayerSheetState();
}

class _PlayerSheetState extends State<PlayerSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

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
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;

    double miniPlayerGrowth =
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
          child: getPlayerContent(
            minSize: widget.miniPlayerHeight,
            maxSize: screenHeight,
            factor: factor.clamp(0.0, 1.0),
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
                getNavigationContent(
                  maxSize: widget.navigationHeight,
                  factor: (1 - factor).clamp(0.0, 1.0),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Offstage(
                offstage: factor <= 1,
                child: getQueueContent(
                  maxSize: screenHeight,
                  factor: (factor - 1).clamp(0.0, 1.0),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SwipeableTile extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final double threshold;
  final double maxDrag;

  const SwipeableTile({
    super.key,
    required this.child,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    this.threshold = 40,
    this.maxDrag = 80,
  });

  @override
  State<SwipeableTile> createState() => _SwipeableTileState();
}

class _SwipeableTileState extends State<SwipeableTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragOffset = 0;
  bool _overThreshold = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _triggerFeedback() async {
    await HapticFeedback.lightImpact();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dx;
      _dragOffset = _dragOffset.clamp(-widget.maxDrag, widget.maxDrag);
    });

    final isOver = _dragOffset.abs() >= widget.threshold;
    if (isOver != _overThreshold) {
      _overThreshold = isOver;
      _triggerFeedback();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragOffset < -widget.threshold) {
      debugPrint('swiped left');
      widget.onSwipeLeft();
    } else if (_dragOffset > widget.threshold) {
      debugPrint('swiped right');
      widget.onSwipeRight();
    }

    _overThreshold = false;
    final start = _dragOffset;
    _controller.reset();

    final animation = Tween<double>(
      begin: start,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    animation.addListener(() => setState(() => _dragOffset = animation.value));

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Row(
            children: [
              if (_dragOffset > 0)
                Container(width: _dragOffset, color: Colors.orange),
              const Spacer(),
              if (_dragOffset < 0)
                Container(width: -_dragOffset, color: Colors.orange),
            ],
          ),
        ),
        Transform.translate(
          offset: Offset(_dragOffset, 0),
          child: GestureDetector(
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class StarredScreen extends ConsumerWidget {
  const StarredScreen({super.key});

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
