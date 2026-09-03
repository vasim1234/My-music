import 'package:flutter/material.dart';
import 'package:my_music/services/background_handler.dart';
import 'screens/player_screen.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔥 REQUEST ALL PERMISSIONS
  await _requestPermissions();
  
  try {
    print('🚀 Initializing audio service...');
    await initAudioService();
    print('✅ Audio service initialized');
  } catch (e) {
    print('❌ Audio service error: $e');
  }

  runApp(const MyMusicApp());
}

// 🔥 PERMISSION FUNCTION
Future<void> _requestPermissions() async {
  // For Android 11+
  if (await Permission.manageExternalStorage.request().isGranted) {
    print('✅ Manage storage permission granted');
  } else {
    print('⚠️ Manage storage permission denied');
  }
  
  // For Android 10 and below
  if (await Permission.storage.request().isGranted) {
    print('✅ Storage permission granted');
  } else {
    print('⚠️ Storage permission denied');
  }
  
  if (await Permission.audio.request().isGranted) {
    print('✅ Audio permission granted');
  } else {
    print('⚠️ Audio permission denied');
  }
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
