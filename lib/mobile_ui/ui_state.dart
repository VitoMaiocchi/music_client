import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PlayerState { collapsed, expanded, queue }

@immutable
sealed class AppPage {
  const AppPage();
}

@immutable
class AppPagePlaylists extends AppPage {
  const AppPagePlaylists();
}

@immutable
class AppPageAlbums extends AppPage {
  const AppPageAlbums();
}

@immutable
class AppPageTracks extends AppPage {
  const AppPageTracks();
}

@immutable
class AppPageSearch extends AppPage {
  const AppPageSearch();
}

@immutable
class AppPageAlbum extends AppPage {
  final String albumId;

  const AppPageAlbum({required this.albumId});
}

@immutable
class AppPagePlaylist extends AppPage {
  final String playlistId;

  const AppPagePlaylist({required this.playlistId});
}

@immutable
class AppPageArtist extends AppPage {
  final String artistId;

  const AppPageArtist({required this.artistId});
}

@immutable
class AppPageStarredTracks extends AppPage {
  const AppPageStarredTracks();
}

@immutable
class AppNavigationState {
  final PlayerState playerState;
  final List<AppPage> pageStack;

  const AppNavigationState({
    required this.playerState,
    required this.pageStack,
  });

  AppNavigationState copyWith({
    PlayerState? playerState,
    List<AppPage>? pageStack,
  }) {
    return AppNavigationState(
      playerState: playerState ?? this.playerState,
      pageStack: pageStack ?? this.pageStack,
    );
  }
}

class AppNavigation extends Notifier<AppNavigationState> {
  @override
  AppNavigationState build() => AppNavigationState(
    playerState: PlayerState.collapsed,
    pageStack: const [AppPagePlaylists()],
  );

  void setPlayerState(PlayerState newState) {
    state = state.copyWith(playerState: newState);
  }

  void pushPage({required AppPage page, bool newStack = false}) {
    if (newStack) {
      state = state.copyWith(pageStack: [page]);
      return;
    }
    final last = state.pageStack.isNotEmpty ? state.pageStack.last : null;
    if (last != null && _samePage(last, page)) return;

    state = state.copyWith(pageStack: [...state.pageStack, page]);
  }

  void popPage() {
    if (state.pageStack.length <= 1) {
      return;
    }

    state = state.copyWith(
      pageStack: state.pageStack.sublist(0, state.pageStack.length - 1),
    );
  }

  bool _samePage(AppPage a, AppPage b) {
    if (a.runtimeType != b.runtimeType) return false;
    if (a is AppPageAlbum && b is AppPageAlbum) return a.albumId == b.albumId;
    if (a is AppPagePlaylist && b is AppPagePlaylist) {
      return a.playlistId == b.playlistId;
    }
    if (a is AppPageArtist && b is AppPageArtist) {
      return a.artistId == b.artistId;
    }
    return true;
  }
}

final appNavigationProvider =
    NotifierProvider<AppNavigation, AppNavigationState>(AppNavigation.new);
