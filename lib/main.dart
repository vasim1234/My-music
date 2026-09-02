import 'package:flutter/material.dart';
import 'package:my_music/services/background_handler.dart';
import 'screens/player_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('🚀 Starting app...');
    // 🔥 IMPORTANT: Await karo initialization
    await initAudioService();
    print('✅ Audio service initialized successfully');
  } catch (e, stacktrace) {
    print('❌ Failed to initialize audio service: $e');
    print('📚 Stacktrace: $stacktrace');
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
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF4ECDC4),
          surface: Color(0xFF16161E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const PlayerScreen(),
    );
  }
}
