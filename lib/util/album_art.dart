import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/backend/backend.dart';
import 'package:music_client/theme.dart';

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

    final dpr = MediaQuery.of(context).devicePixelRatio;
    final lowResSize = (AppSizes.trackAlbumArt * dpr).ceil();

    final coverLow = ref
        .watch(coverProvider(CoverRequest(coverArt!, lowResSize)))
        .maybeWhen(data: (c) => c, orElse: () => null);

    final lowres = coverLow != null
        ? Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: _fallbackCover),
              Image(
                key: const ValueKey('lowres'),
                image: coverLow,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSyncLoaded) {
                  if (frame == null && !wasSyncLoaded) {
                    return _fallbackCover;
                  }
                  return child;
                },
                errorBuilder: (_, _, _) => _fallbackCover,
              ),
            ],
          )
        : _fallbackCover;

    if (size <= AppSizes.trackAlbumArt) {
      return SizedBox(
        width: size.toDouble(),
        height: size.toDouble(),
        child: lowres,
      );
    }

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

class StarArt extends StatelessWidget {
  const StarArt({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest.shortestSide;
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.purple, Colors.blue],
              ),
            ),
            child: Icon(Icons.star, size: size * 0.6, color: Colors.white),
          );
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
