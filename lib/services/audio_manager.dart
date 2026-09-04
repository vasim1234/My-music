import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;

  AudioManager._internal();

  final AudioPlayer _player = AudioPlayer();
  String? _currentSongPath;
  bool _isPlaying = false;
  bool _is3DMode = false;

  Stream<Duration?> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  bool get isPlaying => _isPlaying;
  String? get currentSong => _currentSongPath;
  bool get is3DMode => _is3DMode;

  void init() {
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      print('State: ${state.processingState}, playing: ${state.playing}');
    });
  }

  // ✅ Toggle 3D Mode with Audio Effect
  Future<void> toggle3DMode() async {
    _is3DMode = !_is3DMode;
    print('🎵 3D Mode: ${_is3DMode ? "ON" : "OFF"}');
    
    if (_is3DMode) {
      // ✅ Apply 3D Effect - Pan + Echo + Volume Boost
      await _player.setPan(0.5); // Center
      await _player.setVolume(1.2); // Slight boost
      // Add reverb/echo effect using custom processing
      // Note: just_audio doesn't have built-in reverb, so we use pan + volume
    } else {
      // Reset to normal
      await _player.setPan(0.0);
      await _player.setVolume(1.0);
    }
  }

  // ✅ Apply 3D Effect Dynamically (call during playback)
  Future<void> apply3DEffect() async {
    if (_is3DMode) {
      // Create 3D effect: alternating pan for spatial feel
      // This creates a slight left-right movement
      for (int i = 0; i < 10; i++) {
        double panValue = (i % 2 == 0) ? -0.8 : 0.8;
        await _player.setPan(panValue);
        await Future.delayed(Duration(milliseconds: 200));
      }
      await _player.setPan(0.5); // Return to center
    }
  }

  Future<void> preload(String path, String title, String artist) async {
    try {
      print('🎵 Preloading: $title');
      final file = File(path);
      if (!await file.exists()) {
        print('❌ File not found for preloading');
        return;
      }
      await _player.stop();
      await _player.setAudioSource(AudioSource.file(path));
      _currentSongPath = path;
      _isPlaying = false;
      print('✅ Preload complete: $title');
    } catch (e) {
      print('❌ Preload Error: $e');
    }
  }

  Future<void> playSong(String path, String title, String artist) async {
    try {
      print('🎵 PlaySong: $title');
      
      final file = File(path);
      if (!await file.exists()) {
        print('❌ File not found');
        throw Exception('File not found');
      }
      
      await _player.stop();
      await _player.setAudioSource(AudioSource.file(path));
      
      // ✅ Apply 3D effect if enabled
      if (_is3DMode) {
        await _player.setPan(0.5);
        await _player.setVolume(1.2);
      }
      
      await Future.delayed(const Duration(milliseconds: 300));
      await _player.play();
      _currentSongPath = path;
      _isPlaying = true;
      print('▶️ Playing: $title');

    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }

  Future<void> play() async {
    print('▶️ Play called');
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    await _player.play();
    _isPlaying = true;
  }

  Future<void> pause() async {
    print('⏸️ Pause called');
    await _player.pause();
    _isPlaying = false;
  }

  Future<void> stop() async {
    print('⏹️ Stop called');
    await _player.stop();
    _isPlaying = false;
  }

  Future<void> seek(Duration position) async {
    print('⏩ Seek called: ${position.inSeconds}s');
    await _player.seek(position);
  }

  Future<void> setVolume(double volume) async {
    print('🔊 Set volume: $volume');
    // ✅ If 3D mode is on, boost volume slightly
    if (_is3DMode) {
      await _player.setVolume(volume * 1.2);
    } else {
      await _player.setVolume(volume);
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
