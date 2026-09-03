import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';

AudioHandler? audioHandler;

class MyAudioHandler extends BaseAudioHandler {
  // 🔥 PUBLIC PLAYER - Direct access for UI
  final AudioPlayer player = AudioPlayer();
  String? _currentSongPath;
  
  Stream<Duration> get positionStream => player.positionStream;
  Stream<Duration?> get durationStream => player.durationStream;
  
  bool get isPlaying => player.playing;
  bool get isReady => player.playing;
  String? get currentSong => _currentSongPath;
  
  MyAudioHandler() {
    _init();
  }

  void _init() {
    player.durationStream.listen((duration) {
      print('⏱️ Duration: $duration');
      if (duration != null) {
        final current = mediaItem.value;
        if (current != null) {
          mediaItem.add(current.copyWith(duration: duration));
        }
      }
    });

    player.positionStream.listen((position) {
      print('📍 Position: ${position.inSeconds}s');
    });

    player.playerStateStream.listen((state) {
      print('🎵 State: ${state.processingState}, playing: ${state.playing}');
      
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            state.playing ? MediaControl.pause : MediaControl.play,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          playing: state.playing,
          processingState: _getAudioProcessingState(state.processingState),
        ),
      );
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

  // 🔥 DIRECT PLAY - SIMPLE AND WORKING
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

      // 🔥 Stop old
      await player.stop();
      
      // 🔥 Load
      await player.setAudioSource(AudioSource.uri(Uri.file(path)));
      print('✅ Audio source set');

      await Future.delayed(const Duration(milliseconds: 300));
      final duration = player.duration;
      print('⏱️ Duration: $duration');

      // 🔥 Update media item for notification
      mediaItem.add(MediaItem(
        id: path,
        title: title,
        artist: artist,
        duration: duration,
      ));

      // 🔥 Play
      await player.play();
      _currentSongPath = path;
      print('✅ Playing: $title');
      
    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }

  @override 
  Future<void> play() async {
    print('▶️ Play called');
    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero);
    }
    await player.play();
    playbackState.add(playbackState.value.copyWith(playing: true));
  }
  
  @override 
  Future<void> pause() async {
    print('⏸️ Pause called');
    await player.pause();
    playbackState.add(playbackState.value.copyWith(playing: false));
  }
  
  @override 
  Future<void> stop() async {
    print('⏹️ Stop called');
    await player.stop();
    _currentSongPath = null;
    playbackState.add(playbackState.value.copyWith(playing: false));
    await super.stop();
  }
  
  @override 
  Future<void> seek(Duration p) async => player.seek(p);
  
  @override 
  Future<void> setVolume(double v) async => player.setVolume(v);
  
  @override 
  Future<void> setSpeed(double s) async => player.setSpeed(s);
  
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
