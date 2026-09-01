import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

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
    
    // Listen to player state
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
      debugPrint('🎵 playSong called: $title');
      debugPrint('📁 Path: $path');
      
      // Stop current song if playing
      await _player.stop();
      debugPrint('⏹️ Stopped previous song');
      
      // Set new audio source
      await _player.setAudioSource(AudioSource.file(path));
      _currentSongPath = path;
      debugPrint('📁 Audio source set');
      
      // Update notification
      mediaItem.add(
        MediaItem(
          id: path,
          album: 'My Music 3D',
          title: title,
          artist: artist,
        ),
      );
      debugPrint('📱 Notification updated');
      
      // Apply volume
      await _player.setVolume(_currentVolume);
      
      // ===== PLAY =====
      await _player.play();
      _isPlaying = true;
      debugPrint('▶️ Playing started');
      
    } catch (e) {
      debugPrint('❌ Play song error: $e');
    }
  }

  @override
  Future<void> play() async {
    debugPrint('▶️ play() called');
    await _player.play();
    _isPlaying = true;
  }

  @override
  Future<void> pause() async {
    debugPrint('⏸️ pause() called');
    await _player.pause();
    _isPlaying = false;
  }

  @override
  Future<void> stop() async {
    debugPrint('⏹️ stop() called');
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
