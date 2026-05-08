import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music_client/music_providers.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

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
      home: Scaffold(
        body: Stack(
          children: [
            // Main content
            const StarredScreen(),

            SnapDragSheet(
              child: Container(
                color: Colors.red,
                child: const Center(child: Text("Player UI")),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SnapDragSheet extends StatefulWidget {
  final Widget child;
  final double collapsedFactor;
  final Duration snapDuration;

  const SnapDragSheet({
    super.key,
    required this.child,
    this.collapsedFactor = 0.12,
    this.snapDuration = const Duration(milliseconds: 160),
  });

  @override
  State<SnapDragSheet> createState() => _SnapDragSheetState();
}

class _SnapDragSheetState extends State<SnapDragSheet> {
  double _dragOffset = 0.0;
  late double _screenHeight;

  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    _screenHeight = MediaQuery.of(context).size.height;

    final minH = _screenHeight * widget.collapsedFactor;
    final maxH = _screenHeight;

    double currentHeight = (_screenHeight - _dragOffset).clamp(minH, maxH);

    return Stack(
      children: [
        AnimatedPositioned(
          duration: _isDragging ? Duration.zero : widget.snapDuration,
          curve: Curves.easeOut,
          left: 0,
          right: 0,
          bottom: 0,
          height: currentHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,

            onVerticalDragStart: (_) {
              setState(() => _isDragging = true);
            },

            onVerticalDragUpdate: (d) {
              setState(() {
                _dragOffset += d.delta.dy;
                _dragOffset = _dragOffset.clamp(0.0, _screenHeight - minH);
              });
            },

            onVerticalDragEnd: (d) {
              setState(() {
                _isDragging = false;

                // velocity-based snap
                if (d.primaryVelocity != null && d.primaryVelocity! < -500) {
                  // fast swipe up → fullscreen
                  _dragOffset = 0;
                } else if (d.primaryVelocity != null &&
                    d.primaryVelocity! > 500) {
                  // fast swipe down → collapsed
                  _dragOffset = _screenHeight - minH;
                } else {
                  // position-based snap
                  final mid = (_screenHeight - minH) / 2;
                  if (_dragOffset < mid) {
                    _dragOffset = 0;
                  } else {
                    _dragOffset = _screenHeight - minH;
                  }
                }
              });
            },

            child: widget.child,
          ),
        ),
      ],
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
  late AudioPlayer _audioPlayer;
  double _dragOffset = 0;
  bool _overThreshold = false;

  static bool get _isDesktop =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    if (_isDesktop) {
      _audioPlayer = AudioPlayer();
      // drop a short click wav in assets/sounds/click.wav
      _audioPlayer.setAsset('assets/sounds/click.wav');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_isDesktop) _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _triggerFeedback() async {
    if (_isDesktop) {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    } else {
      await HapticFeedback.lightImpact();
    }
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
