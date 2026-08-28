import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PlayerState { collapsed, expanded, queue }

class AppNavigationState {
  final PlayerState playerState;

  AppNavigationState({required this.playerState});
}

class AppNavigation extends Notifier<AppNavigationState> {
  @override
  AppNavigationState build() =>
      AppNavigationState(playerState: PlayerState.collapsed);

  void setPlayerState(PlayerState newState) {
    state = AppNavigationState(playerState: newState);
  }
}

final appNavigationProvider =
    NotifierProvider<AppNavigation, AppNavigationState>(AppNavigation.new);
