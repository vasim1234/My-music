import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class BackgroundHandler {
  static final BackgroundHandler _instance = BackgroundHandler._internal();
  factory BackgroundHandler() => _instance;
  BackgroundHandler._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  String _currentTitle = 'My Music 3D';
  String _currentArtist = 'Music Player';
  Duration _currentDuration = Duration.zero;

  Future<void> initialize() async {
    await AudioService.init(
      builder: () => AudioPlayerTask(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.music.app.my_music.channel',
        androidNotificationChannelName: 'My Music 3D Player',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
  }

  void updateSong(String title, String artist, Duration duration) {
    _currentTitle = title;
    _currentArtist = artist;
    _currentDuration = duration;
    _updateNotification();
  }

  void setPlaying(bool playing) {
    _isPlaying = playing;
    _updateNotification();
  }

  void _updateNotification() {
    final mediaItem = MediaItem(
      id: 'current_song',
      album: 'My Music 3D',
      title: _currentTitle,
      artist: _currentArtist,
      duration: _currentDuration,
    );
    AudioService.setMediaItem(mediaItem);
    
    final controls = _isPlaying
        ? [
            MediaControl.skipToPrevious,
            MediaControl.pause,
            MediaControl.skipToNext,
          ]
        : [
            MediaControl.skipToPrevious,
            MediaControl.play,
            MediaControl.skipToNext,
          ];
    
    AudioService.setPlaybackState(
      PlaybackState(
        controls: controls,
        playing: _isPlaying,
        systemActions: const {
          MediaAction.seekTo,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.stop,
        },
      ),
    );
  }
}

class AudioPlayerTask extends BackgroundAudioTask {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  Future<void> onStart(Map<String, dynamic>? params) async {
    await _updateState();
  }

  Future<void> _updateState() async {
    final mediaItem = MediaItem(
      id: 'current_song',
      album: 'My Music 3D',
      title: 'My Music Player',
      artist: 'Enjoy Music',
    );
    AudioService.setMediaItem(mediaItem);
    
    final controls = _playing
        ? [
            MediaControl.skipToPrevious,
            MediaControl.pause,
            MediaControl.skipToNext,
          ]
        : [
            MediaControl.skipToPrevious,
            MediaControl.play,
            MediaControl.skipToNext,
          ];
    
    AudioService.setPlaybackState(
      PlaybackState(
        controls: controls,
        playing: _playing,
        systemActions: const {
          MediaAction.seekTo,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.stop,
        },
      ),
    );
  }

  @override
  Future<void> onPlay() async {
    _playing = true;
    await _player.play();
    await _updateState();
  }

  @override
  Future<void> onPause() async {
    _playing = false;
    await _player.pause();
    await _updateState();
  }

  @override
  Future<void> onSkipToNext() async {
    // Handle next
  }

  @override
  Future<void> onSkipToPrevious() async {
    // Handle previous
  }

  @override
  Future<void> onStop() async {
    await _player.stop();
    _playing = false;
    await _updateState();
    await super.onStop();
  }
}
