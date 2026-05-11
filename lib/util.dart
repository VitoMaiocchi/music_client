import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  double _dragOffset = 0;
  bool _overThreshold = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _triggerFeedback() async {
    await HapticFeedback.lightImpact();
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
