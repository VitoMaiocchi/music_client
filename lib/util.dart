import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/backend.dart';
import 'package:music_client/playback.dart';
import 'package:music_client/theme.dart';
import 'package:palette_generator/palette_generator.dart';

class SwipeableTile extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipe;
  final double threshold;
  final double maxDrag;
  final Color color;

  const SwipeableTile({
    super.key,
    required this.child,
    required this.onSwipe,
    this.threshold = 40,
    this.maxDrag = 80,
    this.color = Colors.orange,
  });

  @override
  State<SwipeableTile> createState() => _SwipeableTileState();
}

class _SwipeableTileState extends State<SwipeableTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      upperBound: widget.maxDrag,
      lowerBound: 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final oldT = _controller.value > widget.threshold;
    _controller.value += details.delta.dx;
    final newT = _controller.value > widget.threshold;
    if (oldT != newT) HapticFeedback.lightImpact();
  }

  void _onDragEnd(DragEndDetails details) {
    if (_controller.value > widget.threshold) {
      debugPrint('swiped right');
      widget.onSwipe();
    }

    _controller.animateTo(0, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        return Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(width: _controller.value, color: widget.color),
              ),
            ),
            Transform.translate(
              offset: Offset(_controller.value, 0),
              child: GestureDetector(
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                child: widget.child,
              ),
            ),
          ],
        );
      },
    );
  }
}

class AlbumArtProvider extends ConsumerStatefulWidget {
  static const lowResSize = AppSizes.miniAlbumArt;
  static int highResSize = 1000;

  final Track? track;
  final bool highRes;
  final Widget Function(BuildContext, Color?, Color?, Widget) builder;

  const AlbumArtProvider({
    super.key,
    required this.track,
    required this.builder,
    this.highRes = false,
  });

  @override
  ConsumerState<AlbumArtProvider> createState() => _AlbumArtProviderState();
}

class _AlbumArtProviderState extends ConsumerState<AlbumArtProvider> {
  bool _highResLoaded = false;

  final fallbackCover = Container(color: AppColors.surface);

  (Color?, Color?) _extractColors(PaletteGenerator cover) {
    Color primary;
    if (cover.vibrantColor != null) {
      primary = cover.vibrantColor!.color;
    } else if (cover.dominantColor != null) {
      primary = cover.dominantColor!.color;
    } else if (cover.lightVibrantColor != null) {
      primary = cover.lightVibrantColor!.color;
    } else if (cover.darkVibrantColor != null) {
      primary = cover.darkVibrantColor!.color;
    } else {
      primary = AppColors.textPrimary;
    }
    Color secondary;
    if (cover.darkMutedColor != null) {
      secondary = cover.darkMutedColor!.color;
    } else if (cover.mutedColor != null) {
      secondary = cover.mutedColor!.color;
    } else if (cover.lightMutedColor != null) {
      secondary = cover.lightMutedColor!.color;
    } else if (cover.dominantColor != null) {
      secondary = cover.dominantColor!.color;
    } else {
      secondary = AppColors.progressIndicators;
    }

    return (primary, secondary);
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final coverLow = widget.track != null
        ? ref
              .watch(
                coverProvider(
                  CoverRequest(
                    widget.track!,
                    AlbumArtProvider.lowResSize * dpr.ceil(),
                  ),
                ),
              )
              .maybeWhen(data: (c) => c, orElse: () => null)
        : null;
    final paletteLow = widget.track != null
        ? ref
              .watch(
                paletteProvider(
                  CoverRequest(
                    widget.track!,
                    AlbumArtProvider.lowResSize * dpr.ceil(),
                  ),
                ),
              )
              .maybeWhen(data: (c) => c, orElse: () => null)
        : null;

    //LOWRES
    if (!widget.highRes) {
      final colors = paletteLow != null
          ? _extractColors(paletteLow)
          : (null, null);
      return widget.builder(
        context,
        colors.$1,
        colors.$2,
        AspectRatio(
          aspectRatio: 1,
          child: coverLow != null
              ? Image(
                  image: coverLow,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallbackCover,
                  loadingBuilder: (context, child, loadingProgress) =>
                      loadingProgress == null ? child : fallbackCover,
                )
              : fallbackCover,
        ),
      );
    }

    //PLACEHOLDER
    return widget.builder(
      context,
      null,
      null,
      coverLow != null
          ? Image(image: coverLow, fit: BoxFit.cover)
          : fallbackCover,
    );
  }
}
