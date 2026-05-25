import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/backend.dart';
import 'package:music_client/playback.dart';
import 'package:palette_generator/palette_generator.dart'; // adjust import to your package

// Helper class to hold all dynamic colors for the player UI.
class _PlayerColors {
  final Color background;
  final Color surface; // used for collapsed background, placeholder
  final Color primary; // accent color (progress, play button)
  final Color onPrimary; // icon/text on primary
  final Color text; // main text (title)
  final Color secondaryText; // artist, time labels
  final Color progressBackground;
  final Color progressValue;
  final Color sliderActive;
  final Color sliderInactive;
  final Color playButtonBg;
  final Color playButtonIcon;
  final Color placeholderBg;
  final Color placeholderIcon;

  _PlayerColors({
    required this.background,
    required this.surface,
    required this.primary,
    required this.onPrimary,
    required this.text,
    required this.secondaryText,
    required this.progressBackground,
    required this.progressValue,
    required this.sliderActive,
    required this.sliderInactive,
    required this.playButtonBg,
    required this.playButtonIcon,
    required this.placeholderBg,
    required this.placeholderIcon,
  });

  // Default dark theme (matches original hardcoded colours)
  factory _PlayerColors.defaultDark() {
    return _PlayerColors(
      background: const Color(0xFF111111),
      surface: const Color(0xFF111111),
      primary: const Color(0xFFE8E0D0),
      onPrimary: const Color(0xFF111111),
      text: const Color(0xFFE8E0D0),
      secondaryText: const Color(0xFF888880),
      progressBackground: const Color(0xFF2A2A2A),
      progressValue: const Color(0xFFE8E0D0),
      sliderActive: const Color(0xFFE8E0D0),
      sliderInactive: const Color(0xFF2A2A2A),
      playButtonBg: const Color(0xFFE8E0D0),
      playButtonIcon: const Color(0xFF111111),
      placeholderBg: const Color(0xFF2A2A2A),
      placeholderIcon: const Color(0xFF555550),
    );
  }

  // Build from PaletteGenerator
  factory _PlayerColors.fromPalette(PaletteGenerator palette) {
    // Get the most suitable colors, with fallbacks to the default dark palette
    final defaultColors = _PlayerColors.defaultDark();

    // Dominant color is a good candidate for background/surface
    final dominant = palette.dominantColor?.color ?? defaultColors.background;

    // Vibrant color works well for accents (progress, play button)
    final vibrant = palette.vibrantColor?.color ?? defaultColors.primary;

    // Muted color can be used for subtle surfaces
    final muted = palette.mutedColor?.color ?? defaultColors.progressBackground;

    // Compute contrasting text colors (simple luminance check)
    Color onVibrant = defaultColors.onPrimary;
    if (vibrant.computeLuminance() > 0.5) {
      onVibrant = Colors.black;
    } else {
      onVibrant = Colors.white;
    }

    // For text, use dominant color with enough contrast – but often we want light text on dark bg
    // So we keep light text and dark background from dominant, or fallback to default.
    final isDominantDark = dominant.computeLuminance() < 0.5;
    final textColor = isDominantDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDominantDark ? Colors.white70 : Colors.black54;

    return _PlayerColors(
      background: dominant,
      surface: dominant,
      primary: vibrant,
      onPrimary: onVibrant,
      text: textColor,
      secondaryText: secondaryTextColor,
      progressBackground: muted,
      progressValue: vibrant,
      sliderActive: vibrant,
      sliderInactive: muted,
      playButtonBg: vibrant,
      playButtonIcon: onVibrant,
      placeholderBg: muted,
      placeholderIcon: isDominantDark ? Colors.white38 : Colors.black38,
    );
  }
}

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
    final coverArtId = track?.id ?? '';
    final paletteAsync = ref.watch(coverPaletteProvider(coverArtId));

    // Resolve palette and convert to _PlayerColors
    final playerColors = paletteAsync.when(
      data: (palette) => _PlayerColors.fromPalette(palette),
      loading: () => _PlayerColors.defaultDark(),
      error: (_, __) => _PlayerColors.defaultDark(),
    );

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
        .maybeWhen(data: (value) => value.playing, orElse: () => false);
    final service = ref.read(playbackServiceProvider);

    final height = minSize + (maxSize - minSize) * factor;
    final collapsed = (1 - factor * 5).clamp(0.0, 1.0);
    final expanded = ((factor - 0.2) * 5).clamp(0.0, 1.0);
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Container(
      color: playerColors.background,
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
                        colors: playerColors,
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
                          paletteAsync: paletteAsync,
                          track: track,
                          isPlaying: isPlaying,
                          position: position,
                          duration: duration,
                          progress: progress,
                          service: service,
                          colors: playerColors,
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
  final _PlayerColors colors;
  final WidgetRef ref;

  const _Collapsed({
    required this.track,
    required this.isPlaying,
    required this.progress,
    required this.service,
    required this.colors,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: 2,
          backgroundColor: colors.progressBackground,
          valueColor: AlwaysStoppedAnimation(colors.progressValue),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _Cover(track: track, size: 40, colors: colors, ref: ref),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track?.title ?? 'Nothing playing',
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                      Text(
                        track?.artist ?? '',
                        style: TextStyle(
                          color: colors.secondaryText,
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
                  colors: colors,
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
  final _PlayerColors colors;
  final AsyncValue<PaletteGenerator>? paletteAsync; // used only for debug
  final WidgetRef ref;

  const _Expanded({
    required this.track,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.progress,
    required this.service,
    required this.colors,
    this.paletteAsync,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
      child: Column(
        children: [
          // Cover with optional debug overlay
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  children: [
                    _Cover(
                      track: track,
                      size: 300,
                      colors: colors,
                      ref: ref,
                      rounded: 12,
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _PaletteDebugOverlay(paletteAsync: paletteAsync!),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Title + artist
          Text(
            track?.title ?? 'Nothing playing',
            style: TextStyle(
              color: colors.text,
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
            style: TextStyle(color: colors.secondaryText, fontSize: 15),
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
              activeTrackColor: colors.sliderActive,
              inactiveTrackColor: colors.sliderInactive,
              thumbColor: colors.sliderActive,
              overlayColor: colors.sliderActive.withOpacity(0.2),
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
                  style: TextStyle(color: colors.secondaryText, fontSize: 12),
                ),
                Text(
                  _fmt(duration),
                  style: TextStyle(color: colors.secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Play / pause
          _PlayPauseButton(
            isPlaying: isPlaying,
            service: service,
            size: 56,
            colors: colors,
          ),
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
  final _PlayerColors colors;
  final WidgetRef ref;
  final double rounded;

  const _Cover({
    required this.track,
    required this.size,
    required this.colors,
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
      error: (_, __) => _placeholder(rounded),
    );
  }

  Widget _placeholder(double r) => ClipRRect(
    borderRadius: BorderRadius.circular(r),
    child: Container(
      color: colors.placeholderBg,
      child: Icon(Icons.music_note, color: colors.placeholderIcon),
    ),
  );
}

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final PlaybackService service;
  final double size;
  final _PlayerColors colors;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.service,
    required this.size,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isPlaying ? service.pause : service.resume,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.playButtonBg,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: colors.playButtonIcon,
          size: size * 0.55,
        ),
      ),
    );
  }
}

class _PaletteDebugOverlay extends StatelessWidget {
  final AsyncValue<PaletteGenerator> paletteAsync;

  const _PaletteDebugOverlay({required this.paletteAsync});

  @override
  Widget build(BuildContext context) {
    return paletteAsync.when(
      data: (palette) {
        // Collect all available colors from PaletteGenerator
        final colors = <String, Color?>{
          'dominant': palette.dominantColor?.color,
          'vibrant': palette.vibrantColor?.color,
          'darkVibrant': palette.darkVibrantColor?.color,
          'lightVibrant': palette.lightVibrantColor?.color,
          'muted': palette.mutedColor?.color,
          'darkMuted': palette.darkMutedColor?.color,
          'lightMuted': palette.lightMutedColor?.color,
        };

        // Filter out nulls
        final entries = colors.entries.where((e) => e.value != null).toList();

        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: entries.map((entry) {
              final color = entry.value!;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white30),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    entry.key,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
      loading: () => Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Loading palette…',
          style: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
