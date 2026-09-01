import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';

// ===== FIX: Nullable audioHandler =====
AudioHandler? audioHandler;

Future<AudioHandler> initAudioService() async {
  print('🔊 initAudioService called');
  final handler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.music.app.my_music.channel',
      androidNotificationChannelName: 'My Music 3D Player',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
  audioHandler = handler;
  print('✅ audioHandler initialized');
  return handler;
}

class MyAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  String? _currentSongPath;
  double _currentVolume = 1.0;
  bool _isPlaying = false;

  MyAudioHandler() {
    print('🎵 MyAudioHandler created');
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
    });
  }

  Future<void> setVolume(double volume) async {
    _currentVolume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_currentVolume);
  }

  Future<void> playSong(String path, String title, String artist) async {
    print('🎵 playSong called: $title');
    
    try {
      final file = File(path);
      if (!file.existsSync()) {
        print('❌ File does NOT exist: $path');
        return;
      }
      
      await _player.stop();
      
      final uri = Uri.file(path);
      await _player.setAudioSource(AudioSource.uri(uri));
      _currentSongPath = path;
      
      mediaItem.add(
        MediaItem(
          id: path,
          album: 'My Music 3D',
          title: title,
          artist: artist,
          duration: _player.duration,
        ),
      );
      
      await _player.setVolume(_currentVolume);
      await _player.play();
      _isPlaying = true;
      print('▶️ Playing started');
      
    } catch (e) {
      print('❌ Play song error: $e');
    }
  }

  @override
  Future<void> play() async {
    await _player.play();
    _isPlaying = true;
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        _player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _getProcessingState(_player.processingState),
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: 0,
    );
  }

  AudioProcessingState _getProcessingState(ProcessingState state) {
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
}
