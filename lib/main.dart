import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_client/mobile_ui/home_screen.dart';
import 'package:music_client/util.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await dotenv.load(fileName: "credentials.env");
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define maximal Album Art size to load.
    AlbumArtProvider.highResSize = MediaQuery.of(context).size.width.ceil();

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
        home: Scaffold(body: HomeScreenMobile()),
      ),
    );
  }
}
