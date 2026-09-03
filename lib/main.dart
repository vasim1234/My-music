import 'package:flutter/material.dart';
import 'package:my_music/services/background_handler.dart';
import 'screens/player_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('🚀 Initializing audio service...');
    await initAudioService();
    print('✅ Audio service initialized');
  } catch (e) {
    print('❌ Audio service error: $e');
  }

  runApp(const MyMusicApp());
}

class MyMusicApp extends StatelessWidget {
  const MyMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Music 3D',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        primaryColor: const Color(0xFF6C63FF),
      ),
      home: const PlayerScreen(),
    );
  }
}
