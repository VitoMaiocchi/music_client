import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide NavigationBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/mobile_ui/player.dart';
import 'package:music_client/mobile_ui/queue.dart';

import 'page.dart';
import 'ui_state.dart';
import 'navigation_bar.dart';

class HomeScreenMobile extends ConsumerStatefulWidget {
  final Duration snapDuration;
  final double miniPlayerHeight;
  final double navigationHeight;
  const HomeScreenMobile({
    super.key,
    this.snapDuration = const Duration(milliseconds: 160),
    this.miniPlayerHeight = 60,
    this.navigationHeight = 80,
  });

  @override
  ConsumerState<HomeScreenMobile> createState() => _HomeScreenMobileState();
}

class _HomeScreenMobileState extends ConsumerState<HomeScreenMobile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final _queueScrollController = ScrollController();
  late VelocityTracker _queueVelocityTracker;
  final _isReordering = ValueNotifier(false);

  bool _draggingQueue = false;

  bool get _queueAtTop =>
      !_queueScrollController.hasClients ||
      _queueScrollController.position.pixels <= 0;

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

    _controller.addStatusListener(_onAnimationStatus);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed &&
        status != AnimationStatus.dismissed) {
      return;
    }

    final value = _controller.value;

    PlayerState? newState;

    if ((value - 0).abs() < 0.001) {
      newState = PlayerState.collapsed;
    } else if ((value - 1).abs() < 0.001) {
      newState = PlayerState.expanded;
    } else if ((value - 2).abs() < 0.001) {
      newState = PlayerState.queue;
    }

    if (newState == null) return;

    final currentState = ref.read(appNavigationProvider).playerState;

    if (currentState != newState) {
      ref.read(appNavigationProvider.notifier).setPlayerState(newState);
    }
  }

  double _stateToValue(PlayerState state) {
    return switch (state) {
      PlayerState.collapsed => 0,
      PlayerState.expanded => 1,
      PlayerState.queue => 2,
    };
  }

  void _animateTo(PlayerState state) {
    final target = _stateToValue(state);

    if ((_controller.value - target).abs() < 0.001) {
      return;
    }

    _controller.animateTo(
      target,
      duration: widget.snapDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _snapFromVelocity(double velocity) {
    final factor = _controller.value;

    late double target;

    if (velocity < -500) {
      target = factor.ceilToDouble();
    } else if (velocity > 500) {
      target = factor.floorToDouble();
    } else {
      target = factor.roundToDouble();
    }

    target = target.clamp(0.0, 2.0);

    _controller.animateTo(
      target,
      duration: widget.snapDuration,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for navigation changes made from anywhere else in the app.
    ref.listen<AppNavigationState>(appNavigationProvider, (previous, next) {
      final current = previous?.playerState;

      if (current == next.playerState) return;

      _animateTo(next.playerState);
    });

    final currentPage = ref.watch(
      appNavigationProvider.select((state) => state.pageStack.last),
    );

    final screenHeight = MediaQuery.of(context).size.height;

    final miniPlayerGrowth =
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
            _snapFromVelocity(d.primaryVelocity ?? 0);
          },
          child: Player(
            minSize: widget.miniPlayerHeight,
            maxSize: screenHeight,
            factor: factor.clamp(0.0, 1.0),
          ),
        );

        final queue = Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            _queueVelocityTracker = VelocityTracker.withKind(e.kind);
            _draggingQueue = false;
          },
          onPointerMove: (e) {
            if (_isReordering.value) return;

            _queueVelocityTracker.addPosition(e.timeStamp, e.position);

            if (!_draggingQueue && _queueAtTop && e.delta.dy > 0) {
              _draggingQueue = true;
            }

            if (_draggingQueue) {
              _controller.value -= e.delta.dy / miniPlayerGrowth;
            }
          },
          onPointerUp: (_) {
            if (_draggingQueue) {
              final velocity = _queueVelocityTracker
                  .getVelocity()
                  .pixelsPerSecond
                  .dy;

              _snapFromVelocity(velocity);
            }

            _draggingQueue = false;
          },
          onPointerCancel: (_) {
            _draggingQueue = false;
          },
          child: QueueWidget(
            scrollController: _queueScrollController,
            scrollable: factor >= 2,
            maxSize: screenHeight,
            factor: (factor - 1).clamp(0.0, 1.0),
            isReordering: _isReordering,
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
                child: buildPage(currentPage),
              ),
            ),

            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                player,
                NavigationBar(
                  maxSize: widget.navigationHeight,
                  factor: (1 - factor).clamp(0.0, 1.0),
                ),
              ],
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: Offstage(offstage: factor <= 1, child: queue),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _queueScrollController.dispose();
    _isReordering.dispose();
    super.dispose();
  }
}
