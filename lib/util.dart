import 'dart:ui';

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

class AlbumArtProvider extends ConsumerWidget {
  static const lowResSizeUnscaled = AppSizes.miniAlbumArt;

  final Track? track;
  final bool highRes;
  final Widget Function(BuildContext, Color?, Color?, Widget) builder;

  const AlbumArtProvider({
    super.key,
    required this.track,
    required this.builder,
    this.highRes = false,
  });

  static final _fallbackCover = Container(color: AppColors.surface);

  (Color?, Color?) _extractColors(PaletteGenerator cover) {
    Color primary =
        cover.vibrantColor?.color ??
        cover.dominantColor?.color ??
        cover.lightVibrantColor?.color ??
        cover.darkVibrantColor?.color ??
        AppColors.textPrimary;

    Color secondary =
        cover.darkMutedColor?.color ??
        cover.mutedColor?.color ??
        cover.lightMutedColor?.color ??
        cover.dominantColor?.color ??
        AppColors.progressIndicators;

    return (primary, secondary);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final lowResSize = (lowResSizeUnscaled * dpr).ceil();
    final highResSize = (MediaQuery.of(context).size.width * dpr).ceil();

    final coverLow = track != null
        ? ref
              .watch(coverProvider(CoverRequest(track!, lowResSize)))
              .maybeWhen(data: (c) => c, orElse: () => null)
        : null;

    final paletteLow = track != null
        ? ref
              .watch(paletteProvider(CoverRequest(track!, lowResSize)))
              .maybeWhen(data: (c) => c, orElse: () => null)
        : null;

    final colors = paletteLow != null
        ? _extractColors(paletteLow)
        : (null, null);

    final lowres = coverLow != null
        ? Image(
            key: const ValueKey('lowres'),
            image: coverLow,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _fallbackCover,
          )
        : _fallbackCover;

    if (!highRes) {
      return builder(
        context,
        colors.$1,
        colors.$2,
        AspectRatio(aspectRatio: 1, child: lowres),
      );
    }

    final coverHigh = track != null
        ? ref
              .watch(coverProvider(CoverRequest(track!, highResSize)))
              .maybeWhen(data: (c) => c, orElse: () => null)
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        final showHighRes = size * dpr > lowResSize * 1.2;
        final targetPx = (size * dpr).ceil();

        if (!showHighRes || coverHigh == null) {
          return builder(
            context,
            colors.$1,
            colors.$2,
            AspectRatio(aspectRatio: 1, child: lowres),
          );
        }

        final boundedHighRes = ResizeImage(
          coverHigh,
          width: targetPx,
          height: targetPx,
        );

        final blurredLowres = ClipRect(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: 15,
              sigmaY: 15,
              tileMode: TileMode.mirror,
            ),
            child: lowres,
          ),
        );

        return builder(
          context,
          colors.$1,
          colors.$2,
          AspectRatio(
            aspectRatio: 1,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              child: Image(
                key: ValueKey(coverHigh),
                image: boundedHighRes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSyncLoaded) {
                  if (wasSyncLoaded || frame != null) return child;
                  return blurredLowres;
                },
                errorBuilder: (_, _, _) => blurredLowres,
              ),
            ),
          ),
        );
      },
    );
  }
}
