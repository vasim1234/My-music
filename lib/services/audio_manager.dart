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

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  
  bool get isPlaying => _isPlaying;
  String? get currentSong => _currentSongPath;

  void init() {
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      print('🎵 State: ${state.processingState}, playing: ${state.playing}');
    });
  }

  Future<void> playSong(String path, String title, String artist) async {
    try {
      print('🎵 playSong: $title');
      print('📁 Path: $path');
      
      final file = File(path);
      if (!await file.exists()) {
        print('❌ File not found');
        throw Exception('File not found');
      }
      print('✅ File exists: ${file.lengthSync()} bytes');

      await _player.stop();
      await _player.setAudioSource(AudioSource.uri(Uri.file(path)));
      print('✅ Audio source set');

      await Future.delayed(const Duration(milliseconds: 300));
      final duration = _player.duration;
      print('⏱️ Duration: $duration');

      await _player.play();
      _currentSongPath = path;
      _isPlaying = true;
      print('✅ Playing: $title');
      
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
    _currentSongPath = null;
    _isPlaying = false;
  }

  Future<void> seek(Duration p) async => _player.seek(p);
  Future<void> setVolume(double v) async => _player.setVolume(v);
  Future<void> dispose() async => _player.dispose();
}
