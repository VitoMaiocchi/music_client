import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/backend.dart';
import 'package:music_client/playback.dart';
import 'package:music_client/theme.dart';

class Player extends ConsumerWidget {
  static const double _transitionThreshold = 0.1;
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
    final queue = ref.watch(queueProvider);
    final track = queue[0]?.$1;
    final cover = track != null
        ? ref.watch(coverProvider(CoverRequest(track, 1000)))
        : const AsyncValue.data(null);
    final coverImage = cover.maybeWhen(data: (c) => c, orElse: () => null);
    final asyncPalette = track != null
        ? ref.watch(paletteProvider(CoverRequest(track, 1000)))
        : const AsyncValue.data(null);
    final palette = asyncPalette.maybeWhen(data: (c) => c, orElse: () => null);

    Color? accentColor;
    if (palette != null) {
      if (palette.vibrantColor != null) {
        accentColor = palette.vibrantColor!.color;
      } else if (palette.dominantColor != null) {
        accentColor = palette.dominantColor!.color;
      }
    }

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

    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    final height = minSize + (maxSize - minSize) * factor;
    final collapsed = (1 - factor / _transitionThreshold).clamp(0.0, 1.0);
    final expanded = (factor / _transitionThreshold).clamp(0.0, 1.0);

    return Container(
      color: AppColors.background,
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
                        imageProvider: coverImage,
                        track: track,
                        isPlaying: isPlaying,
                        progress: progress,
                        service: service,
                        accentColor: accentColor,
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
                          imageProvider: coverImage,
                          track: track,
                          isPlaying: isPlaying,
                          position: position,
                          duration: duration,
                          progress: progress,
                          service: service,
                          accentColor: accentColor,
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

class _Collapsed extends StatelessWidget {
  final Track? track;
  final ImageProvider? imageProvider;
  final Color? accentColor;
  final bool isPlaying;
  final double progress;
  final PlaybackService service;
  final WidgetRef ref;

  const _Collapsed({
    required this.track,
    required this.imageProvider,
    required this.accentColor,
    required this.isPlaying,
    required this.progress,
    required this.service,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final Color progressColor = accentColor ?? AppColors.progressIndicators;

    final cover = imageProvider != null
        ? Image(image: imageProvider!, width: 48, height: 48, fit: BoxFit.cover)
        : Container(
            width: 48,
            height: 48,
            color: AppColors.progressIndicators,
            child: Icon(Icons.music_note, color: AppColors.textSecondary),
          );

    return Stack(
      children: [
        //BACKGROUND PROGRESS
        LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: [
                Container(
                  color: progressColor,
                  width: constraints.maxWidth * progress,
                  height: constraints.maxHeight,
                ),
                Container(
                  color: AppColors.surface,
                  width: constraints.maxWidth * (1 - progress),
                  height: constraints.maxHeight,
                ),
              ],
            );
          },
        ),
        //COVER + TEXT
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              cover,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        track?.title ?? 'Title',
                        style: AppTextStyles.listTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        track?.artist ?? 'Artist',
                        style: AppTextStyles.listSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 32,
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: () => isPlaying ? service.pause() : service.play(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Expanded extends StatelessWidget {
  final Track? track;
  final ImageProvider? imageProvider;
  final Color? accentColor;
  final bool isPlaying;
  final PlaybackService service;
  final Duration position;
  final Duration duration;
  final double progress;
  final WidgetRef ref;

  const _Expanded({
    required this.imageProvider,
    required this.track,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.progress,
    required this.service,
    required this.ref,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).viewPadding.top;

    final cover = imageProvider != null
        ? Image(image: imageProvider!, fit: BoxFit.cover)
        : Container(
            width: 48,
            height: 48,
            color: AppColors.progressIndicators,
            child: Icon(Icons.music_note, color: AppColors.textSecondary),
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        // BACKGROUND
        if (accentColor != null)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  accentColor!,
                  Color.lerp(accentColor!, AppColors.background, 0.15)!,
                  Color.lerp(accentColor!, AppColors.background, 0.4)!,
                  AppColors.background,
                ],
                stops: [0.0, 0.2, 0.35, 1.0],
              ),
            ),
          )
        else
          Container(color: AppColors.background),
        //CONTENT
        Padding(
          padding: EdgeInsets.only(top: topInset),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(24.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: cover,
                ),
              ),
              // Title + artist
              Text(
                track?.title ?? 'Nothing playing',
                style: AppTextStyles.playerTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                track?.artist ?? '',
                style: AppTextStyles.playerSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),

              // Seek bar
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                  activeTrackColor: accentColor ?? AppColors.textPrimary,
                  inactiveTrackColor: AppColors.progressIndicators,
                  thumbColor: AppColors.textPrimary,
                  overlayColor: AppColors.textPrimary,
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
                    Text(_fmt(position), style: AppTextStyles.listSubtitle),
                    Text(_fmt(duration), style: AppTextStyles.listSubtitle),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Previous | Play/Pause | Next
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 32,
                      icon: Icon(Icons.skip_previous, color: Colors.white),
                      onPressed: () =>
                          ref.read(queueProvider.notifier).previous(),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 32,
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: () =>
                          isPlaying ? service.pause() : service.play(),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 32,
                      icon: Icon(Icons.skip_next, color: Colors.white),
                      onPressed: () => ref.read(queueProvider.notifier).next(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
