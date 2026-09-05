import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/backend/backend.dart';
import 'package:music_client/theme.dart';

Widget _lowres(
  WidgetRef ref,
  double dpr,
  String coverArt,
  Widget fallbackCover,
) {
  final lowResSize = (AppSizes.trackAlbumArt * dpr).ceil();

  final coverLow = ref
      .watch(coverProvider(CoverRequest(coverArt, lowResSize)))
      .maybeWhen(data: (c) => c, orElse: () => null);

  if (coverLow == null) return fallbackCover;

  return Stack(
    fit: StackFit.expand,
    children: [
      Positioned.fill(child: fallbackCover),
      Image(
        key: const ValueKey('lowres'),
        image: coverLow,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSyncLoaded) {
          if (frame == null && !wasSyncLoaded) {
            return fallbackCover;
          }
          return child;
        },
        errorBuilder: (_, _, _) => fallbackCover,
      ),
    ],
  );
}

Widget _blur(Widget child) {
  return ClipRect(
    child: ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: 15,
        sigmaY: 15,
        tileMode: TileMode.mirror,
      ),
      child: child,
    ),
  );
}

class AlbumArtWidget extends ConsumerWidget {
  final String? coverArt;
  final int? size;

  static final _fallbackCover = Container(color: AppColors.surface);

  const AlbumArtWidget({super.key, this.coverArt, this.size});

  Widget _buildAtSize(int size, BuildContext context, WidgetRef ref) {
    if (coverArt == null || coverArt!.isEmpty) {
      return SizedBox(
        width: size.toDouble(),
        height: size.toDouble(),
        child: _fallbackCover,
      );
    }

    if (coverArt == "star") return _StarArt(size: size.toDouble());

    final dpr = MediaQuery.of(context).devicePixelRatio;
    final lowres = _lowres(ref, dpr, coverArt!, _fallbackCover);

    if (size <= AppSizes.trackAlbumArt) {
      return SizedBox(
        width: size.toDouble(),
        height: size.toDouble(),
        child: lowres,
      );
    }

    final blurredLowres = _blur(lowres);

    final targetPx = (size * dpr).ceil();

    final coverHigh = ref
        .watch(coverProvider(CoverRequest(coverArt!, targetPx)))
        .maybeWhen(data: (c) => c, orElse: () => null);

    return SizedBox(
      width: size.toDouble(),
      height: size.toDouble(),
      child: coverHigh != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(child: _fallbackCover),
                Image(
                  image: coverHigh,
                  fit: BoxFit.cover,
                  frameBuilder: (context, child, frame, wasSyncLoaded) {
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 120),
                      layoutBuilder: (current, previous) => Stack(
                        fit: StackFit.expand,
                        children: [...previous, ?current],
                      ),
                      child: frame == null && !wasSyncLoaded
                          ? KeyedSubtree(
                              key: const ValueKey('low'),
                              child: blurredLowres,
                            )
                          : KeyedSubtree(
                              key: const ValueKey('high'),
                              child: child,
                            ),
                    );
                  },
                  errorBuilder: (_, _, _) => blurredLowres,
                ),
              ],
            )
          : blurredLowres,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (size != null) {
      return _buildAtSize(size!, context, ref);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        return _buildAtSize(size.ceil(), context, ref);
      },
    );
  }
}

class AlbumArtBlurred extends ConsumerWidget {
  final String coverArt;
  final double? opacity;
  final bool fade;

  AlbumArtBlurred({
    super.key,
    required this.coverArt,
    this.opacity,
    this.fade = false,
  });

  final _fallbackCover = Container(color: AppColors.background);

  Widget _getArt(BuildContext context, WidgetRef ref) {
    if (coverArt == "star") return _blur(_StarArt());

    final dpr = MediaQuery.of(context).devicePixelRatio;
    final lowres = _lowres(ref, dpr, coverArt, _fallbackCover);

    return _blur(AspectRatio(aspectRatio: 1, child: lowres));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget art = _getArt(context, ref);

    if (opacity != null) {
      art = Opacity(opacity: opacity!, child: art);
    }

    if (fade) {
      art = ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.transparent],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: art,
      );
    }

    return art;
  }
}

class _StarArt extends StatelessWidget {
  final double? size;
  const _StarArt({this.size});

  Widget _star(double side) {
    return Container(
      width: side,
      height: side,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple, Colors.blue],
        ),
      ),
      child: Icon(Icons.star, size: side * 0.6, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (size != null) return _star(size!);

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return _star(constraints.biggest.shortestSide);
        },
      ),
    );
  }
}

Color? getPrimaryColor(String? coverArt, BuildContext context, WidgetRef ref) {
  if (coverArt == null || coverArt.isEmpty) return null;

  final dpr = MediaQuery.of(context).devicePixelRatio;
  final palette = ref
      .watch(
        paletteProvider(
          CoverRequest(coverArt, AppSizes.trackAlbumArt * dpr.ceil()),
        ),
      )
      .maybeWhen(data: (c) => c, orElse: () => null);

  if (palette == null) return null;

  return palette.vibrantColor?.color ??
      palette.dominantColor?.color ??
      palette.lightVibrantColor?.color ??
      palette.darkVibrantColor?.color;
}

Color? getSecondaryColor(
  String? coverArt,
  BuildContext context,
  WidgetRef ref,
) {
  if (coverArt == null || coverArt.isEmpty) return null;

  final dpr = MediaQuery.of(context).devicePixelRatio;
  final palette = ref
      .watch(
        paletteProvider(
          CoverRequest(coverArt, AppSizes.trackAlbumArt * dpr.ceil()),
        ),
      )
      .maybeWhen(data: (c) => c, orElse: () => null);

  if (palette == null) return null;

  return palette.darkMutedColor?.color ??
      palette.mutedColor?.color ??
      palette.lightMutedColor?.color ??
      palette.dominantColor?.color;
}
