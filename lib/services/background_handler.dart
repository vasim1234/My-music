import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';

AudioHandler? audioHandler;

class MyAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  String? _currentSongPath;
  bool _isLoading = false;
  
  // Streams
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  
  bool get isPlaying => _player.playing;
  bool get isReady => _player.playing;
  String? get currentSong => _currentSongPath;
  
  MyAudioHandler() {
    _init();
  }

  void _init() {
    _player.durationStream.listen((duration) {
      print('⏱️ Duration: $duration');
      if (duration != null) {
        final current = mediaItem.value;
        if (current != null) {
          mediaItem.add(current.copyWith(duration: duration));
        }
      }
    });

    _player.positionStream.listen((position) {
      print('📍 Position: ${position.inSeconds}s');
    });

    _player.playerStateStream.listen((state) {
      print('🎵 State: ${state.processingState}, playing: ${state.playing}');
      
      playbackState.add(
        playbackState.value.copyWith(
          playing: state.playing,
          processingState: _getAudioProcessingState(state.processingState),
        ),
      );
      
      if (state.processingState == ProcessingState.ready) {
        final duration = _player.duration;
        if (duration != null && duration > Duration.zero) {
          print('✅ Duration ready: $duration');
          final current = mediaItem.value;
          if (current != null) {
            mediaItem.add(current.copyWith(duration: duration));
          }
        }
        _isLoading = false;
      }
      
      if (state.processingState == ProcessingState.completed) {
        print('🎵 Song completed');
        _isLoading = false;
      }
      
      if (state.processingState == ProcessingState.idle) {
        _currentSongPath = null;
        _isLoading = false;
      }
    });
  }

  AudioProcessingState _getAudioProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle: return AudioProcessingState.idle;
      case ProcessingState.loading: return AudioProcessingState.loading;
      case ProcessingState.buffering: return AudioProcessingState.buffering;
      case ProcessingState.ready: return AudioProcessingState.ready;
      case ProcessingState.completed: return AudioProcessingState.completed;
      default: return AudioProcessingState.idle;
    }
  }

  // 🔥 MAIN PLAY SONG - FIXED
  Future<void> playSong(String path, String title, String artist) async {
    try {
      if (_isLoading) {
        print('⏳ Already loading, waiting...');
        await Future.delayed(const Duration(milliseconds: 300));
        if (_isLoading) return;
      }
      
      _isLoading = true;
      print('🎵 playSong: $title');
      print('📁 Path: $path');
      
      // 🔥 STOP OLD PLAYER COMPLETELY
      await _player.stop();
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 🔥 CHECK FILE
      final file = File(path);
      if (!await file.exists()) {
        _isLoading = false;
        throw Exception('File not found');
      }
      print('✅ File exists: ${file.lengthSync()} bytes');

      // 🔥 LOAD NEW AUDIO
      await _player.setAudioSource(AudioSource.uri(Uri.file(path)));
      print('✅ Audio source set');

      // 🔥 WAIT FOR LOADING
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 🔥 GET DURATION
      final duration = _player.duration;
      print('⏱️ Duration: $duration');

      // 🔥 UPDATE MEDIA ITEM
      mediaItem.add(MediaItem(
        id: path,
        title: title,
        artist: artist,
        duration: duration,
      ));
      print('✅ Media item updated');

      // 🔥 PLAY
      await _player.play();
      _currentSongPath = path;
      print('▶️ Play command sent');
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (_player.playing) {
        print('✅ Song is playing!');
      } else {
        print('⚠️ Song not playing, retry...');
        await _player.play();
      }
      
      _isLoading = false;
      
    } catch (e) {
      _isLoading = false;
      print('❌ Error: $e');
      rethrow;
    }
  }

  @override Future<void> play() async {
    print('▶️ Play called');
    await _player.play();
    playbackState.add(playbackState.value.copyWith(playing: true));
  }
  
  @override Future<void> pause() async {
    print('⏸️ Pause called');
    await _player.pause();
    playbackState.add(playbackState.value.copyWith(playing: false));
  }
  
  @override Future<void> stop() async {
    print('⏹️ Stop called');
    await _player.stop();
    _currentSongPath = null;
    _isLoading = false;
    playbackState.add(playbackState.value.copyWith(playing: false));
    await super.stop();
  }
  
  @override Future<void> seek(Duration p) async {
    if (_player.playing || _player.processingState == ProcessingState.ready) {
      await _player.seek(p);
    }
  }
  
  @override Future<void> setVolume(double v) async => _player.setVolume(v);
  @override Future<void> setSpeed(double s) async => _player.setSpeed(s);
  
  @override Future<void> skipToNext() async {}
  @override Future<void> skipToPrevious() async {}
  @override Future<void> fastForward() async {}
  @override Future<void> rewind() async {}
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
  @override Future<void> onTaskRemoved() async { await stop(); }
}

Future<AudioHandler> initAudioService() async {
  if (audioHandler != null) return audioHandler!;
  
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
  
  return audioHandler!;
}
