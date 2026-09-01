import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';  // ← ADD THIS

// Global instance
late final AudioHandler audioHandler;

Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.music.app.my_music.channel',
      androidNotificationChannelName: 'My Music 3D Player',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  String? _currentSongPath;
  double _currentVolume = 1.0;
  bool _isPlaying = false;

  MyAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
    });
  }

  // ===== SET VOLUME =====
  Future<void> setVolume(double volume) async {
    _currentVolume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_currentVolume);
  }

  // ===== PLAY SONG =====
  Future<void> playSong(String path, String title, String artist) async {
    try {
      print('🎵 playSong called: $title');
      
      // Stop current song if playing
      await _player.stop();
      
      // Set new audio source
      await _player.setAudioSource(AudioSource.file(path));
      _currentSongPath = path;
      
      // Update notification
      mediaItem.add(
        MediaItem(
          id: path,
          album: 'My Music 3D',
          title: title,
          artist: artist,
        ),
      );
      
      // Apply volume
      await _player.setVolume(_currentVolume);
      
      // PLAY
      await _player.play();
      _isPlaying = true;
      print('▶️ Playing started');
      
    } catch (e) {
      print('❌ Play song error: $e');
    }
  }

  @override
  Future<void> play() async {
    print('▶️ play() called');
    await _player.play();
    _isPlaying = true;
  }

  @override
  Future<void> pause() async {
    print('⏸️ pause() called');
    await _player.pause();
    _isPlaying = false;
  }

  @override
  Future<void> stop() async {
    print('⏹️ stop() called');
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
