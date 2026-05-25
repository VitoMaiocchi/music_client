import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/backend.dart';
import 'package:music_client/playback.dart';

//PLACEHOLDER
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
        : 0.0; // ignore: unnecessary_null_in_if_null_operators

    return Container(
      color: const Color(0xFF111111),
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
                          track: track,
                          isPlaying: isPlaying,
                          position: position,
                          duration: duration,
                          progress: progress,
                          service: service,
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
  final WidgetRef ref;

  const _Collapsed({
    required this.track,
    required this.isPlaying,
    required this.progress,
    required this.service,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // thin progress line at the very top
        LinearProgressIndicator(
          value: progress,
          minHeight: 2,
          backgroundColor: const Color(0xFF2A2A2A),
          valueColor: const AlwaysStoppedAnimation(Color(0xFFE8E0D0)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _Cover(track: track, size: 40, ref: ref),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track?.title ?? 'Nothing playing',
                        style: const TextStyle(
                          color: Color(0xFFE8E0D0),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                      Text(
                        track?.artist ?? '',
                        style: const TextStyle(
                          color: Color(0xFF888880),
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
  final WidgetRef ref;

  const _Expanded({
    required this.track,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.progress,
    required this.service,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
      child: Column(
        children: [
          // Cover
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: _Cover(track: track, size: 300, ref: ref, rounded: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Title + artist
          Text(
            track?.title ?? 'Nothing playing',
            style: const TextStyle(
              color: Color(0xFFE8E0D0),
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
            style: const TextStyle(color: Color(0xFF888880), fontSize: 15),
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
              activeTrackColor: const Color(0xFFE8E0D0),
              inactiveTrackColor: const Color(0xFF2A2A2A),
              thumbColor: const Color(0xFFE8E0D0),
              overlayColor: const Color(0x22E8E0D0),
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
                  style: const TextStyle(
                    color: Color(0xFF888880),
                    fontSize: 12,
                  ),
                ),
                Text(
                  _fmt(duration),
                  style: const TextStyle(
                    color: Color(0xFF888880),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Play / pause
          _PlayPauseButton(isPlaying: isPlaying, service: service, size: 56),
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
  final WidgetRef ref;
  final double rounded;

  const _Cover({
    required this.track,
    required this.size,
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
      error: (_, _) => _placeholder(rounded),
    );
  }

  Widget _placeholder(double r) => ClipRRect(
    borderRadius: BorderRadius.circular(r),
    child: Container(
      color: const Color(0xFF2A2A2A),
      child: const Icon(Icons.music_note, color: Color(0xFF555550)),
    ),
  );
}

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final PlaybackService service;
  final double size;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.service,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isPlaying ? service.pause : service.resume,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFFE8E0D0),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: const Color(0xFF111111),
          size: size * 0.55,
        ),
      ),
    );
  }
}
