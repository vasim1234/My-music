import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:equalizer_flutter/equalizer_flutter.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;

  AudioManager._internal();

  final AudioPlayer _player = AudioPlayer();
  String? _currentSongPath;
  bool _isPlaying = false;
  bool _is3DMode = false;
  
  // EQ State
  String _currentEqPreset = 'Normal';
  Map<String, double> _eqGains = {
    'Bass': 0.0,
    'Mid': 0.0,
    'Treble': 0.0,
  };
  
  static const Map<String, Map<String, int>> _eqPresets = {
    'Normal': {'Bass': 0, 'Mid': 0, 'Treble': 0},
    'Bass Boost': {'Bass': 800, 'Mid': 0, 'Treble': -400},
    'Treble Boost': {'Bass': -400, 'Mid': 0, 'Treble': 800},
    'Pop': {'Bass': 300, 'Mid': 0, 'Treble': 300},
    'Rock': {'Bass': 500, 'Mid': 200, 'Treble': 400},
    'Classical': {'Bass': -200, 'Mid': 100, 'Treble': 500},
    'Jazz': {'Bass': 400, 'Mid': 100, 'Treble': 300},
    'Vocal': {'Bass': 0, 'Mid': 400, 'Treble': 0},
    'Hip Hop': {'Bass': 600, 'Mid': -100, 'Treble': -200},
    'Electronic': {'Bass': 400, 'Mid': 0, 'Treble': 500},
  };

  static const int _bassBand = 0;
  static const int _midBand = 1;
  static const int _trebleBand = 2;

  Stream<Duration?> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  bool get isPlaying => _isPlaying;
  String? get currentSong => _currentSongPath;
  bool get is3DMode => _is3DMode;
  String get currentEqPreset => _currentEqPreset;
  Map<String, double> get eqGains => _eqGains;

  bool _isEqualizerInitialized = false;
  int? _currentSessionId;

  // ============================================================
  // INIT
  // ============================================================
  
  void init() {
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      print('State: ${state.processingState}, playing: ${state.playing}');
    });

    // ✅ FIX: Connect Equalizer with Session ID
    _player.androidAudioSessionIdStream.listen((sessionId) async {
      if (sessionId != null && sessionId != 0) {
        _currentSessionId = sessionId;
        print('🎛️ Audio Session ID: $sessionId');
        
        try {
          await EqualizerFlutter.init(sessionId);
          await EqualizerFlutter.setEnabled(true);
          _isEqualizerInitialized = true;
          print('✅ Equalizer connected!');
          
          // Apply current preset
          await _applyRealEqualizerPreset(_currentEqPreset);
        } catch (e) {
          print('❌ Equalizer error: $e');
          _isEqualizerInitialized = false;
        }
      }
    });
  }

  // ============================================================
  // EQUALIZER METHODS
  // ============================================================
  
  Future<void> setEqualizerPreset(String presetName) async {
    if (!_eqPresets.containsKey(presetName)) {
      print('⚠️ Unknown preset: $presetName');
      return;
    }
    
    _currentEqPreset = presetName;
    final gains = _eqPresets[presetName]!;
    _eqGains = {
      'Bass': (gains['Bass'] ?? 0) / 100.0,
      'Mid': (gains['Mid'] ?? 0) / 100.0,
      'Treble': (gains['Treble'] ?? 0) / 100.0,
    };
    
    print('🎛️ Applying Preset: $presetName');
    await _applyRealEqualizerPreset(presetName);
  }
  
  Future<void> _applyRealEqualizerPreset(String presetName) async {
    if (!_isEqualizerInitialized) {
      print('⚠️ Equalizer not initialized, trying to reconnect...');
      await _reconnectEqualizer();
      if (!_isEqualizerInitialized) {
        await _simulateEQ(_eqPresets[presetName]!);
        return;
      }
    }
    
    try {
      final gains = _eqPresets[presetName]!;
      
      await EqualizerFlutter.setBandLevel(_bassBand, gains['Bass']!);
      await EqualizerFlutter.setBandLevel(_midBand, gains['Mid']!);
      await EqualizerFlutter.setBandLevel(_trebleBand, gains['Treble']!);
      
      print('✅ EQ Applied: $presetName');
    } catch (e) {
      print('❌ EQ Error: $e');
      await _simulateEQ(_eqPresets[presetName]!);
    }
  }

  Future<void> _reconnectEqualizer() async {
    try {
      if (_currentSessionId != null && _currentSessionId != 0) {
        await EqualizerFlutter.init(_currentSessionId!);
        await EqualizerFlutter.setEnabled(true);
        _isEqualizerInitialized = true;
        print('✅ Equalizer reconnected!');
      }
    } catch (e) {
      print('❌ Reconnect failed: $e');
      _isEqualizerInitialized = false;
    }
  }

  Future<void> _simulateEQ(Map<String, int> gains) async {
    final bassGain = gains['Bass'] ?? 0;
    final midGain = gains['Mid'] ?? 0;
    final trebleGain = gains['Treble'] ?? 0;
    
    double volumeEffect = 1.0 + (bassGain + midGain + trebleGain) * 0.00015;
    double finalVolume = _is3DMode ? volumeEffect * 1.3 : volumeEffect;
    await _player.setVolume(finalVolume.clamp(0.0, 2.0));
  }

  Future<void> updateBand(int bandId, int level) async {
    if (!_isEqualizerInitialized) {
      await _reconnectEqualizer();
      if (!_isEqualizerInitialized) return;
    }
    
    try {
      await EqualizerFlutter.setBandLevel(bandId, level);
      _currentEqPreset = 'Custom';
      _eqGains = {
        'Bass': (bandId == 0) ? level / 100.0 : _eqGains['Bass']!,
        'Mid': (bandId == 1) ? level / 100.0 : _eqGains['Mid']!,
        'Treble': (bandId == 2) ? level / 100.0 : _eqGains['Treble']!,
      };
      print('✅ Band $bandId set to $level');
    } catch (e) {
      print('❌ Band error: $e');
    }
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
  }

  // ============================================================
  // PLAYBACK METHODS
  // ============================================================
  
  Future<void> preload(String path, String title, String artist) async {
    try {
      print('🎵 Preloading: $title');
      final file = File(path);
      if (!await file.exists()) {
        print('❌ File not found');
        return;
      }
      await _player.stop();
      await _player.setAudioSource(AudioSource.file(path));
      _currentSongPath = path;
      _isPlaying = false;
      print('✅ Preload complete');
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
      
      // ✅ Reconnect equalizer after new song
      await _reconnectEqualizer();
      
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
