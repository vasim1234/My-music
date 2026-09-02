import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

AudioHandler? audioHandler;

class MyAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  
  // Streams expose
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  
  MyAudioHandler() {
    _init();
  }

  void _init() {
    // Duration
    _player.durationStream.listen((duration) {
      if (duration != null) {
        final current = mediaItem.value;
        if (current != null) {
          mediaItem.add(current.copyWith(duration: duration));
        }
      }
    });

    // Position - 🔥 FIXED
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        playing: _player.playing,
        position: position,  // ✅ position
      ));
    });

    // Player State
    _player.playerStateStream.listen((state) {
      playbackState.add(playbackState.value.copyWith(
        playing: state.playing,
        processingState: AudioProcessingState.ready,
      ));
    });
  }

  Future<void> playSong(String path, String title, String artist) async {
    try {
      final file = File(path);
      if (!await file.exists()) throw Exception('File not found: $path');
      
      await _player.setAudioSource(AudioSource.uri(Uri.file(path)));
      await _player.play();
      
      mediaItem.add(MediaItem(
        id: path,
        title: title,
        artist: artist,
        duration: _player.duration,
        artUri: _getArtUri(path),
      ));
      
      playbackState.add(playbackState.value.copyWith(
        playing: true,
        processingState: AudioProcessingState.ready,
      ));
      
    } catch (e) {
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

  @override 
  Future<void> play() async {
    await _player.play();
    playbackState.add(playbackState.value.copyWith(playing: true));
  }
  
  @override 
  Future<void> pause() async {
    await _player.pause();
    playbackState.add(playbackState.value.copyWith(playing: false));
  }
  
  @override 
  Future<void> stop() async {
    await _player.stop();
    await AudioService.stop();
    await super.stop();
  }
  
  @override 
  Future<void> seek(Duration p) async {
    await _player.seek(p);
  }
  
  @override 
  Future<void> setVolume(double v) async {
    await _player.setVolume(v);
  }
  
  @override 
  Future<void> setSpeed(double s) async {
    await _player.setSpeed(s);
  }
  
  @override 
  Future<void> skipToNext() async {}
  
  @override 
  Future<void> skipToPrevious() async {}
  
  @override 
  Future<void> fastForward() async {
    final pos = await _player.position;
    await _player.seek(pos + const Duration(seconds: 10));
  }
  
  @override 
  Future<void> rewind() async {
    final pos = await _player.position;
    await _player.seek(pos - const Duration(seconds: 10));
  }
  
  @override 
  Future<void> setRepeatMode(AudioServiceRepeatMode r) async {}
  
  @override 
  Future<void> setShuffleMode(AudioServiceShuffleMode s) async {}
  
  @override 
  Future<void> addQueueItem(MediaItem i) async {}
  
  @override 
  Future<void> addQueueItems(List<MediaItem> i) async {}
  
  @override 
  Future<void> insertQueueItem(int i, MediaItem m) async {}
  
  @override 
  Future<void> updateQueue(List<MediaItem> q) async {}
  
  @override 
  Future<void> removeQueueItem(MediaItem m) async {}
  
  @override 
  Future<void> moveQueueItem(int f, int t) async {}
  
  @override 
  Future<void> skipToQueueItem(int i) async {}
  
  @override 
  Future<void> click([MediaButton b = MediaButton.media]) async {}
  
  @override 
  Future<void> setRating(Rating r, [Map<String, dynamic>? e]) async {}
  
  @override 
  Future<void> customAction(String n, [Map<String, dynamic>? e]) async {}
  
  @override
  Future<void> onTaskRemoved() async {
    await _player.stop();
    await AudioService.stop();
    await super.stop();
  }
}

// Init Audio Service with Notification
Future<AudioHandler> initAudioService() async {
  if (audioHandler != null) return audioHandler!;
  
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.music.app.my_music.channel',
      androidNotificationChannelName: 'My Music Player',
      androidNotificationIcon: 'drawable/ic_notification',
      androidShowNotificationBadge: true,
      androidEnableQueue: true,
      androidStopForegroundOnPause: false,
      androidNotificationOngoing: true,
      androidNotificationClickStartsActivity: true,
      androidNotificationPlayPauseEnabled: true,
    ),
  );
  
  return audioHandler!;
}
