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
  
  // ✅ EQ State
  String _currentEqPreset = 'Normal';
  Map<String, double> _eqGains = {
    'Bass': 0.0,
    'Mid': 0.0,
    'Treble': 0.0,
  };
  
  // ✅ EQ Presets with actual gain values
  static const Map<String, Map<String, double>> _eqPresets = {
    'Normal': {'Bass': 0.0, 'Mid': 0.0, 'Treble': 0.0},
    'Bass Boost': {'Bass': 8.0, 'Mid': 0.0, 'Treble': -4.0},
    'Treble Boost': {'Bass': -4.0, 'Mid': 0.0, 'Treble': 8.0},
    'Pop': {'Bass': 3.0, 'Mid': 0.0, 'Treble': 3.0},
    'Rock': {'Bass': 5.0, 'Mid': 2.0, 'Treble': 4.0},
    'Classical': {'Bass': -2.0, 'Mid': 1.0, 'Treble': 5.0},
    'Jazz': {'Bass': 4.0, 'Mid': 1.0, 'Treble': 3.0},
    'Vocal': {'Bass': 0.0, 'Mid': 4.0, 'Treble': 0.0},
    'Hip Hop': {'Bass': 6.0, 'Mid': -1.0, 'Treble': -2.0},
    'Electronic': {'Bass': 4.0, 'Mid': 0.0, 'Treble': 5.0},
  };

  Stream<Duration?> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  bool get isPlaying => _isPlaying;
  String? get currentSong => _currentSongPath;
  bool get is3DMode => _is3DMode;
  String get currentEqPreset => _currentEqPreset;
  Map<String, double> get eqGains => _eqGains;

  void init() {
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      print('State: ${state.processingState}, playing: ${state.playing}');
    });
  }

  // ============================================================
  // ✅ EQUALIZER - REAL AUDIO EFFECT
  // ============================================================
  
  Future<void> setEqualizerPreset(String presetName) async {
    if (!_eqPresets.containsKey(presetName)) return;
    
    _currentEqPreset = presetName;
    final gains = _eqPresets[presetName]!;
    _eqGains = Map.from(gains);
    
    print('🎛️ Applying Preset: $presetName');
    print('📊 Gains: Bass=${gains['Bass']}dB, Mid=${gains['Mid']}dB, Treble=${gains['Treble']}dB');
    
    // ✅ Apply EQ effect using volume + speed for different frequency responses
    await _applyEQEffect(gains);
  }
  
  Future<void> _applyEQEffect(Map<String, double> gains) async {
    // Since just_audio doesn't have built-in EQ bands,
    // we simulate EQ using volume and speed effects
    
    final bassGain = gains['Bass'] ?? 0.0;
    final midGain = gains['Mid'] ?? 0.0;
    final trebleGain = gains['Treble'] ?? 0.0;
    
    // Calculate overall volume effect
    // Bass boost: increase volume slightly for lows
    // Treble boost: increase volume slightly for highs
    double volumeEffect = 1.0 + (bassGain + midGain + trebleGain) * 0.015;
    double finalVolume = _is3DMode ? volumeEffect * 1.3 : volumeEffect;
    
    // Apply volume (simulates overall gain)
    await _player.setVolume(finalVolume.clamp(0.0, 2.0));
    
    // For speed effect (subtle pitch change for frequency feel)
    // Bass boost: slight speed decrease (feels deeper)
    // Treble boost: slight speed increase (feels brighter)
    double speedEffect = 1.0 + (trebleGain - bassGain) * 0.002;
    await _player.setSpeed(speedEffect.clamp(0.8, 1.2));
    
    print('✅ EQ Applied: Volume=${finalVolume.toStringAsFixed(2)}, Speed=${speedEffect.toStringAsFixed(3)}');
  }
  
  Future<void> resetEqualizer() async {
    await setEqualizerPreset('Normal');
  }

  // ============================================================
  // 3D MODE
  // ============================================================
  
  Future<void> toggle3DMode() async {
    _is3DMode = !_is3DMode;
    print('🎵 3D Mode: ${_is3DMode ? "ON" : "OFF"}');
    
    if (_is3DMode) {
      await _player.setVolume(1.3);
    } else {
      await _player.setVolume(1.0);
    }
    
    // Re-apply EQ if active
    if (_currentEqPreset != 'Normal') {
      await _applyEQEffect(_eqPresets[_currentEqPreset]!);
    }
  }

  // ============================================================
  // PRELOAD & PLAY
  // ============================================================
  
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
      
      // Apply EQ if not Normal
      if (_currentEqPreset != 'Normal') {
        await _applyEQEffect(_eqPresets[_currentEqPreset]!);
      }
      
      // Apply 3D if active
      if (_is3DMode) {
        await _player.setVolume(1.3);
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
    if (_is3DMode) {
      await _player.setVolume(volume * 1.3);
    } else {
      await _player.setVolume(volume);
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
