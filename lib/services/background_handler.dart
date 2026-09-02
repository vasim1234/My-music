import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

AudioHandler? audioHandler;

class MyAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlayerReady = false;
  String? _currentSongPath;
  
  // Streams
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  
  bool get isPlaying => _player.playing;
  bool get isReady => _isPlayerReady;
  String? get currentSong => _currentSongPath;
  
  MyAudioHandler() {
    _init();
  }

  void _init() {
    // 1. DURATION STREAM
    _player.durationStream.listen((duration) {
      if (duration != null) {
        final current = mediaItem.value;
        if (current != null) {
          mediaItem.add(current.copyWith(duration: duration));
        }
      }
    });

    // 2. POSITION STREAM (Fixes 00:00 Seekbar issue)
    _player.positionStream.listen((position) {
      playbackState.add(
        playbackState.value.copyWith(
          updatePosition: position,
          bufferedPosition: _player.bufferedPosition,
        ),
      );
    });

    // 3. PLAYER STATE STREAM
    _player.playerStateStream.listen((state) {
      final isPlaying = state.playing;
      final processingState = _getAudioProcessingState(state.processingState);
      
      playbackState.add(
        playbackState.value.copyWith(
          playing: isPlaying,
          processingState: processingState,
          controls: [
            MediaControl.skipToPrevious,
            if (isPlaying) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
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
          final current = mediaItem.value;
          if (current != null) {
            mediaItem.add(current.copyWith(duration: duration));
          }
        }
      }
    });

    // 4. COMPLETION HANDLER
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _onSongComplete();
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

  void _onSongComplete() {}

  // PLAY SONG METHOD
  Future<void> playSong(String path, String title, String artist) async {
    try {
      await _player.stop();
      _isPlayerReady = false;
      
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('File not found: $path');
      }

      await _player.setAudioSource(AudioSource.uri(Uri.file(path)));

      int attempts = 0;
      Duration? duration;
      while (duration == null && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        duration = _player.duration;
        attempts++;
      }
      
      final item = MediaItem(
        id: path,
        title: title,
        artist: artist,
        duration: duration,
        artUri: _getArtUri(path),
      );
      mediaItem.add(item);

      await _player.play();
      
      _currentSongPath = path;
      _isPlayerReady = true;
      
      playbackState.add(
        playbackState.value.copyWith(
          playing: true,
          processingState: AudioProcessingState.ready,
          updatePosition: Duration.zero,
        ),
      );
      
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

  Future<void> resetPlayer() async {
    await _player.stop();
    _isPlayerReady = false;
    _currentSongPath = null;
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
        updatePosition: Duration.zero,
      ),
    );
  }

  @override 
  Future<void> play() async {
    if (!_isPlayerReady) return;
    await _player.play();
  }
  
  @override 
  Future<void> pause() async {
    await _player.pause();
  }
  
  @override 
  Future<void> stop() async {
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
      await _player.seek(p);
      playbackState.add(
        playbackState.value.copyWith(
          updatePosition: p,
        ),
      );
    }
  }
  
  @override 
  Future<void> setVolume(double v) async => await _player.setVolume(v);
  
  @override 
  Future<void> setSpeed(double s) async => await _player.setSpeed(s);
  
  @override Future<void> skipToNext() async {}
  @override Future<void> skipToPrevious() async {}
  @override Future<void> fastForward() async {
    if (_isPlayerReady) {
      final pos = _player.position;
      await seek(pos + const Duration(seconds: 10));
    }
  }
  @override Future<void> rewind() async {
    if (_isPlayerReady) {
      final pos = _player.position;
      await seek(pos - const Duration(seconds: 10));
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
