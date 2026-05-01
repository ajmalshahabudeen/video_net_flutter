import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'screens/scanner_screen.dart';
import 'state/app_state.dart';
import 'theme/brutalist_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  runApp(const VideoNetApp());
}

class VideoNetApp extends StatelessWidget {
  const VideoNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'VideoNet',
        debugShowCheckedModeBanner: false,
        theme: BrutalistTheme.theme,
        home: const ScannerScreen(),
      ),
    );
  }
}
