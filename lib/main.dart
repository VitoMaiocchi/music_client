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
      home: const StarredScreen(),
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
