import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      //Swipe right
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
