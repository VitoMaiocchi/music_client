import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NavigationBar extends StatelessWidget {
  final double maxSize;
  final double factor;

  const NavigationBar({super.key, required this.maxSize, required this.factor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: maxSize * factor,
      color: Colors.black,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(Icons.queue_music),
            color: Colors.white,
            onPressed: () {
              HapticFeedback.lightImpact();
            },
          ),
          IconButton(
            icon: Icon(Icons.album),
            color: Colors.white,
            onPressed: () {
              HapticFeedback.lightImpact();
            },
          ),
          IconButton(
            icon: Icon(Icons.music_note),
            color: Colors.white,
            onPressed: () {
              HapticFeedback.lightImpact();
            },
          ),
          IconButton(
            icon: Icon(Icons.search),
            color: Colors.white,
            onPressed: () {
              HapticFeedback.lightImpact();
            },
          ),
        ],
      ),
    );
  }
}
