import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';

AudioHandler? audioHandler;

class MyAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlayerReady = false;
  String? _currentSongPath;
  
  // Callback for next song
  VoidCallback? onSongComplete;
  
  // Streams expose
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  
  bool get isPlaying => _player.playing;
  bool get isReady => _isPlayerReady;
  String? get currentSong => _currentSongPath;
  
  MyAudioHandler() {
    _init();
  }

  void _init() {
    // 🔥 DURATION STREAM
    _player.durationStream.listen((duration) {
      print('⏱️ [Native] Duration received: $duration');
      if (duration != null) {
        final current = mediaItem.value;
        if (current != null) {
          mediaItem.add(current.copyWith(duration: duration));
        }
      }
    });

    // 🔥 POSITION STREAM
    _player.positionStream.listen((position) {
      print('📍 [Native] Position: $position');
    });

    // 🔥 PLAYER STATE STREAM
    _player.playerStateStream.listen((state) {
      print('🎵 [Native] State: ${state.processingState}, playing: ${state.playing}');
      final isPlaying = state.playing;
      final processingState = _getAudioProcessingState(state.processingState);
      
      playbackState.add(
        playbackState.value.copyWith(
          playing: isPlaying,
          processingState: processingState,
        ),
      );
      
      if (state.processingState == ProcessingState.idle) {
        _isPlayerReady = false;
        _currentSongPath = null;
      }
      
      if (state.processingState == ProcessingState.ready ||
          state.processingState == ProcessingState.completed) {
        _isPlayerReady = true;
      }
      
      if (state.processingState == ProcessingState.ready) {
        final duration = _player.duration;
        if (duration != null && duration > Duration.zero) {
          print('⏱️ [Native] Duration ready: $duration');
          final current = mediaItem.value;
          if (current != null) {
            mediaItem.add(current.copyWith(duration: duration));
          }
        }
      }
    });

    // 🔥 COMPLETION HANDLER - AUTO-NEXT
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        print('🎵 Song completed - Triggering auto-next');
        _onSongComplete();
      }
    });

    // 🔥 ERROR HANDLER
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.idle && 
          state.playing == false) {
        print('⚠️ Player is idle');
      }
    });
  }

  AudioProcessingState _getAudioProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      default:
        return AudioProcessingState.idle;
    }
  }

  void _onSongComplete() {
    if (onSongComplete != null) {
      onSongComplete!();
    }
  }

  // 🔥 MAIN PLAY SONG METHOD - SIMPLIFIED
  Future<void> playSong(String path, String title, String artist) async {
    try {
      print('🎵 playSong called: $title');
      print('📁 Path: $path');
      
      // 🔥 STOP OLD PLAYER
      await _player.stop();
      _isPlayerReady = false;
      
      // 🔥 CHECK FILE - CRITICAL
      final file = File(path);
      if (!await file.exists()) {
        print('❌ File not found: $path');
        throw Exception('File not found: $path');
      }
      print('✅ File exists: ${file.lengthSync()} bytes');

      // 🔥 SET AUDIO SOURCE - CRITICAL
      print('📁 Loading audio source...');
      try {
        await _player.setAudioSource(AudioSource.uri(Uri.file(path)));
        print('✅ Audio source set successfully');
      } catch (e) {
        print('❌ Error setting audio source: $e');
        rethrow;
      }

      // 🔥 WAIT FOR DURATION - CRITICAL
      print('⏳ Waiting for duration...');
      int attempts = 0;
      Duration? duration;
      while (duration == null && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        duration = _player.duration;
        attempts++;
        print('⏳ Attempt $attempts: Duration = $duration');
      }
      
      print('⏱️ Duration loaded: $duration');

      // 🔥 START PLAYING - CRITICAL
      print('▶️ Starting playback...');
      await _player.play();
      
      _currentSongPath = path;
      _isPlayerReady = true;
      
      // 🔥 UPDATE UI
      final mediaItem = MediaItem(
        id: path,
        title: title,
        artist: artist,
        duration: duration,
        artUri: _getArtUri(path),
      );
      this.mediaItem.add(mediaItem);
      
      playbackState.add(
        playbackState.value.copyWith(
          playing: true,
          processingState: AudioProcessingState.ready,
        ),
      );
      
      print('✅ Song playing successfully: $title');
      print('✅ Duration: $duration');
      print('✅ Position: ${_player.position}');
      
    } catch (e, stacktrace) {
      print('❌ Error in playSong: $e');
      print('📚 Stacktrace: $stacktrace');
      rethrow;
    }
  }

  Uri? _getArtUri(String path) {
    final artFile = File('${path}_art.jpg');
    if (artFile.existsSync()) {
      return Uri.file(artFile.path);
    }
    return Uri.parse('asset:///assets/icon/icon.png');
  }

  // 🔥 RESET PLAYER
  Future<void> resetPlayer() async {
    print('🔄 Resetting player...');
    await _player.stop();
    _isPlayerReady = false;
    _currentSongPath = null;
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ),
    );
  }

  // 🔥 OVERRIDE METHODS
  @override 
  Future<void> play() async {
    print('▶️ Play called');
    if (!_isPlayerReady) {
      print('⚠️ Player not ready, cannot play');
      return;
    }
    await _player.play();
    playbackState.add(playbackState.value.copyWith(playing: true));
  }
  
  @override 
  Future<void> pause() async {
    print('⏸️ Pause called');
    await _player.pause();
    playbackState.add(playbackState.value.copyWith(playing: false));
  }
  
  @override 
  Future<void> stop() async {
    print('⏹️ Stop called');
    await _player.stop();
    _isPlayerReady = false;
    _currentSongPath = null;
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ),
    );
    await AudioService.stop();
    await super.stop();
  }
  
  @override 
  Future<void> seek(Duration p) async {
    if (_isPlayerReady) {
      print('⏩ Seeking to: $p');
      await _player.seek(p);
    }
  }
  
  @override 
  Future<void> setVolume(double v) async {
    await _player.setVolume(v);
  }
  
  @override 
  Future<void> setSpeed(double s) async {
    await _player.setSpeed(s);
  }
  
  @override Future<void> skipToNext() async {}
  @override Future<void> skipToPrevious() async {}
  @override Future<void> fastForward() async {
    if (_isPlayerReady) {
      final pos = await _player.position;
      await _player.seek(pos + const Duration(seconds: 10));
    }
  }
  @override Future<void> rewind() async {
    if (_isPlayerReady) {
      final pos = await _player.position;
      await _player.seek(pos - const Duration(seconds: 10));
    }
  }
  @override Future<void> setRepeatMode(AudioServiceRepeatMode r) async {}
  @override Future<void> setShuffleMode(AudioServiceShuffleMode s) async {}
  @override Future<void> addQueueItem(MediaItem i) async {}
  @override Future<void> addQueueItems(List<MediaItem> i) async {}
  @override Future<void> insertQueueItem(int i, MediaItem m) async {}
  @override Future<void> updateQueue(List<MediaItem> q) async {}
  @override Future<void> removeQueueItem(MediaItem m) async {}
  @override Future<void> moveQueueItem(int f, int t) async {}
  @override Future<void> skipToQueueItem(int i) async {}
  @override Future<void> click([MediaButton b = MediaButton.media]) async {}
  @override Future<void> setRating(Rating r, [Map<String, dynamic>? e]) async {}
  @override Future<void> customAction(String n, [Map<String, dynamic>? e]) async {}
  
  @override
  Future<void> onTaskRemoved() async {
    print('📱 Task removed, stopping...');
    await _player.stop();
    _isPlayerReady = false;
    _currentSongPath = null;
    await AudioService.stop();
    await super.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}

// 🔥 INIT AUDIO SERVICE
Future<AudioHandler> initAudioService() async {
  if (audioHandler != null) {
    print('✅ Audio handler already exists');
    return audioHandler!;
  }
  
  print('🔊 Initializing audio service with notification...');
  
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.music.app.my_music.channel',
      androidNotificationChannelName: 'My Music Player',
      androidNotificationIcon: 'drawable/ic_notification',
      androidShowNotificationBadge: true,
      androidStopForegroundOnPause: true,
      androidNotificationOngoing: false,
      androidNotificationClickStartsActivity: true,
    ),
  );
  
  print('✅ Audio service initialized');
  return audioHandler!;
}
