import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui_state.dart';

class NavigationBar extends ConsumerWidget {
  final double maxSize;
  final double factor;

  const NavigationBar({super.key, required this.maxSize, required this.factor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              ref
                  .read(appNavigationProvider.notifier)
                  .pushPage(page: AppPagePlaylists(), newStack: true);
            },
          ),
          IconButton(
            icon: Icon(Icons.album),
            color: Colors.white,
            onPressed: () {
              ref
                  .read(appNavigationProvider.notifier)
                  .pushPage(page: AppPageAlbums(), newStack: true);
            },
          ),
          IconButton(
            icon: Icon(Icons.music_note),
            color: Colors.white,
            onPressed: () {
              ref //THIS IS ONLY TEMPORARY SHOULD BE APP PAGE TRACKS
                  .read(appNavigationProvider.notifier)
                  .pushPage(page: AppPageStarredTracks(), newStack: true);
            },
          ),
          IconButton(
            icon: Icon(Icons.search),
            color: Colors.white,
            onPressed: () {
              ref
                  .read(appNavigationProvider.notifier)
                  .pushPage(page: AppPageSearch(), newStack: true);
            },
          ),
        ],
      ),
    );
  }
}
