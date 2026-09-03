import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/mobile_ui/home_screen.dart';
import 'package:music_client/mobile_ui/ui_state.dart';
import 'package:music_client/playback/playback.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await dotenv.load(fileName: "credentials.env");

  playbackService = await initPlaybackService();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark, // iOS: white icons
        statusBarIconBrightness: Brightness.light, // Android: white icons
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced:
            false, // prevents Android dark scrim
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: MaterialApp(
        title: 'Music Client',
        home: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;

            final state = ref.read(appNavigationProvider);
            final navigation = ref.read(appNavigationProvider.notifier);

            if (state.playerState == PlayerState.queue) {
              navigation.setPlayerState(PlayerState.expanded);
              return;
            }

            if (state.playerState == PlayerState.expanded) {
              navigation.setPlayerState(PlayerState.collapsed);
              return;
            }

            if (state.pageStack.length > 1) {
              navigation.popPage();
              return;
            }
          },
          child: const Scaffold(body: HomeScreenMobile()),
        ),
      ),
    );
  }
}
