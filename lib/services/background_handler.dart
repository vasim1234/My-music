import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

// 🔥 GLOBAL AUDIO HANDLER
AudioHandler? audioHandler;

class MyAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;
  
  MyAudioHandler() {
    _init();
  }

  void _init() {
    print('🎵 MyAudioHandler initialized');
    
    // 🔥 DURATION STREAM
    _player.durationStream.listen((duration) {
      if (duration != null) {
        print('⏱️ Duration updated: $duration');
        final currentMedia = mediaItem.value;
        if (currentMedia != null) {
          mediaItem.add(
            currentMedia.copyWith(duration: duration),
          );
        }
      }
    });

    // 🔥 POSITION STREAM
    _player.positionStream.listen((position) {
      // Update playback state with position
      final currentPlaybackState = playbackState.value;
      playbackState.add(
        currentPlaybackState.copyWith(
          position: position,
          processingState: _getProcessingState(_player.processingState),
          playing: _player.playing,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
        ),
      );
    });

    // 🔥 PLAYER STATE STREAM
    _player.playerStateStream.listen((state) {
      print('🎵 Player state: ${state.processingState}, playing: ${state.playing}');
      final currentPlaybackState = playbackState.value;
      playbackState.add(
        currentPlaybackState.copyWith(
          processingState: _getProcessingState(state.processingState),
          playing: state.playing,
        ),
      );
    });

    // 🔥 COMPLETION HANDLER
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        print('🎵 Song completed');
        // Handle song completion
        _onSongComplete();
      }
    });

    _isInitialized = true;
    print('✅ Audio player initialized');
  }

  ProcessingState _getProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return ProcessingState.idle;
      case ProcessingState.loading:
        return ProcessingState.loading;
      case ProcessingState.buffering:
        return ProcessingState.buffering;
      case ProcessingState.ready:
        return ProcessingState.ready;
      case ProcessingState.completed:
        return ProcessingState.completed;
      default:
        return ProcessingState.idle;
    }
  }

  void _onSongComplete() {
    // Handle next song logic
    // This will be called from PlayerScreen
  }

  // 🔥 MAIN PLAY SONG METHOD
  Future<void> playSong(String path, String title, String artist) async {
    try {
      print('🎵 playSong called');
      print('📁 Path: $path');
      print('🎵 Title: $title');
      
      // Check if file exists
      final file = File(path);
      if (!await file.exists()) {
        print('❌ File does not exist: $path');
        throw Exception('File not found: $path');
      }
      
      print('✅ File exists: ${file.path}');
      print('📏 File size: ${await file.length()} bytes');

      // Create URI and load audio
      final uri = Uri.file(path);
      print('📁 Loading audio from URI: $uri');
      
      await _player.setAudioSource(AudioSource.uri(uri));
      print('✅ Audio source set successfully');

      // Get duration
      final duration = _player.duration;
      print('⏱️ Duration: $duration');

      // Update media item
      final item = MediaItem(
        id: path,
        title: title,
        artist: artist,
        duration: duration,
        artUri: Uri.parse('asset:///assets/album_art.png'),
      );
      mediaItem.add(item);
      print('✅ Media item updated');

      // Start playing
      await _player.play();
      print('✅ Play command sent');

      // Update playback state
      playbackState.add(
        playbackState.value.copyWith(
          playing: true,
          processingState: ProcessingState.ready,
          position: Duration.zero,
          bufferedPosition: Duration.zero,
          speed: 1.0,
        ),
      );
      
      print('✅ Song should be playing now');
      
    } catch (e, stacktrace) {
      print('❌ Error in playSong: $e');
      print('📚 Stacktrace: $stacktrace');
      rethrow;
    }
  }

  // 🔥 PLAY/PAUSE
  @override
  Future<void> play() async {
    try {
      await _player.play();
      print('▶️ Play called');
    } catch (e) {
      print('❌ Error in play: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
      print('⏸️ Pause called');
    } catch (e) {
      print('❌ Error in pause: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      print('⏹️ Stop called');
    } catch (e) {
      print('❌ Error in stop: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      print('⏩ Seek to: $position');
    } catch (e) {
      print('❌ Error in seek: $e');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume);
      print('🔊 Volume set to: $volume');
    } catch (e) {
      print('❌ Error in setVolume: $e');
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
    } catch (e) {
      print('❌ Error in setSpeed: $e');
    }
  }

  @override
  Future<void> skipToNext() async {
    // Handle skip to next
    print('⏭️ Skip to next');
  }

  @override
  Future<void> skipToPrevious() async {
    // Handle skip to previous
    print('⏮️ Skip to previous');
  }

  @override
  Future<void> fastForward() async {
    final position = await _player.position;
    await _player.seek(position + const Duration(seconds: 10));
  }

  @override
  Future<void> rewind() async {
    final position = await _player.position;
    await _player.seek(position - const Duration(seconds: 10));
  }

  @override
  Future<void> setRepeatMode(RepeatMode repeatMode) async {
    // Handle repeat mode
  }

  @override
  Future<void> setShuffleMode(ShuffleMode shuffleMode) async {
    // Handle shuffle mode
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    // Handle queue
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    // Handle queue
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    // Handle queue
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    // Handle queue
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    // Handle queue
  }

  @override
  Future<void> moveQueueItem(int fromIndex, int toIndex) async {
    // Handle queue
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    // Handle queue
  }

  @override
  Future<void> setRating(double rating) async {
    // Handle rating
  }

  @override
  Future<void> click([MediaAction? action]) async {
    // Handle click
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    // Handle custom action
  }

  @override
  Future<void> onTaskRemoved() async {
    // Handle task removed
  }

  @override
  Future<void> stopAndDispose() async {
    await _player.dispose();
    await super.stopAndDispose();
  }
}

// 🔥 INITIALIZE AUDIO SERVICE
Future<AudioHandler> initAudioService() async {
  try {
    print('🔊 initAudioService called');
    
    if (audioHandler != null) {
      print('✅ Audio handler already exists');
      return audioHandler!;
    }
    
    print('🔄 Creating new AudioHandler');
    final handler = MyAudioHandler();
    audioHandler = handler;
    print('✅ AudioHandler created successfully');
    
    return handler;
  } catch (e, stacktrace) {
    print('❌ Error initializing audio service: $e');
    print('📚 Stacktrace: $stacktrace');
    rethrow;
  }
}
