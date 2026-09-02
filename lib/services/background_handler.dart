import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

AudioHandler? audioHandler;

class MyAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlayerReady = false;
  String? _currentSongPath;
  
  // Streams expose
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  
  MyAudioHandler() {
    _init();
  }

  void _init() {
    // 🔥 DURATION STREAM
    _player.durationStream.listen((duration) {
      if (duration != null) {
        final current = mediaItem.value;
        if (current != null) {
          mediaItem.add(current.copyWith(duration: duration));
        }
      }
    });

    // 🔥 POSITION STREAM
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        playing: _player.playing,
        position: position,
      ));
    });

    // 🔥 PLAYER STATE STREAM - CRITICAL FIX
    _player.playerStateStream.listen((state) {
      final isPlaying = state.playing;
      final processingState = _getAudioProcessingState(state.processingState);
      
      playbackState.add(playbackState.value.copyWith(
        playing: isPlaying,
        processingState: processingState,
      ));
      
      // 🔥 Agar player idle ho gaya to state reset karo
      if (state.processingState == ProcessingState.idle) {
        _isPlayerReady = false;
        _currentSongPath = null;
      }
      
      // 🔥 Agar player ready ho gaya to flag set karo
      if (state.processingState == ProcessingState.ready) {
        _isPlayerReady = true;
      }
      
      print('🎵 Player State: playing=$isPlaying, processing=$processingState');
    });

    // 🔥 COMPLETION HANDLER
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        print('🎵 Song completed');
        // Auto-next logic ke liye
        _onSongComplete();
      }
    });

    // 🔥 ERROR HANDLER
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.idle && 
          _player.playing == false) {
        // Player idle hai - safe state
      }
    });
  }

  // 🔥 Convert ProcessingState to AudioProcessingState
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

  // 🔥 SONG COMPLETION HANDLER
  void _onSongComplete() {
    // PlayerScreen ko notify karo through callback
    // Ya yahan se next song play karo
  }

  // 🔥 MAIN PLAY SONG METHOD - WITH CLEANUP
  Future<void> playSong(String path, String title, String artist) async {
    try {
      print('🎵 playSong called: $title');
      print('📁 Path: $path');
      
      // 🔥 CHECK: Agar same song already playing hai to restart mat karo
      if (_currentSongPath == path && _isPlayerReady) {
        print('⏭️ Same song already loaded, just playing...');
        await _player.play();
        _updatePlaybackState(true);
        return;
      }

      // 🔥 STEP 1: Purana player stop karo
      print('🛑 Stopping current player...');
      await _player.stop();
      await _player.dispose();
      
      // 🔥 STEP 2: Naya player create karo
      print('🔄 Creating new player...');
      final newPlayer = AudioPlayer();
      
      // 🔥 STEP 3: Purane player ko replace karo
      // _player ko dispose kar diya hai, ab naya assign karo
      // Note: _player final hai, isliye newPlayer use karo
      
      // 🔥 STEP 4: File check karo
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('File not found: $path');
      }
      print('✅ File exists: ${file.lengthSync()} bytes');

      // 🔥 STEP 5: Audio source set karo
      print('📁 Loading audio source...');
      await newPlayer.setAudioSource(AudioSource.uri(Uri.file(path)));
      print('✅ Audio source set');

      // 🔥 STEP 6: Player streams connect karo
      _connectPlayerStreams(newPlayer);

      // 🔥 STEP 7: Media item update karo
      final mediaItem = MediaItem(
        id: path,
        title: title,
        artist: artist,
        duration: newPlayer.duration,
        artUri: _getArtUri(path),
      );
      this.mediaItem.add(mediaItem);
      print('✅ Media item updated');

      // 🔥 STEP 8: Play start karo
      print('▶️ Starting playback...');
      await newPlayer.play();
      
      // 🔥 STEP 9: State update karo
      _currentSongPath = path;
      _isPlayerReady = true;
      
      playbackState.add(playbackState.value.copyWith(
        playing: true,
        processingState: AudioProcessingState.ready,
      ));
      
      print('✅ Song playing successfully: $title');
      
    } catch (e, stacktrace) {
      print('❌ Error in playSong: $e');
      print('📚 Stacktrace: $stacktrace');
      rethrow;
    }
  }

  // 🔥 CONNECT PLAYER STREAMS
  void _connectPlayerStreams(AudioPlayer player) {
    // Duration
    player.durationStream.listen((duration) {
      if (duration != null) {
        final current = mediaItem.value;
        if (current != null) {
          mediaItem.add(current.copyWith(duration: duration));
        }
      }
    });

    // Position
    player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        playing: player.playing,
        position: position,
      ));
    });

    // Player State
    player.playerStateStream.listen((state) {
      playbackState.add(playbackState.value.copyWith(
        playing: state.playing,
        processingState: _getAudioProcessingState(state.processingState),
      ));
    });
  }

  // 🔥 UPDATE PLAYBACK STATE
  void _updatePlaybackState(bool playing) {
    playbackState.add(playbackState.value.copyWith(
      playing: playing,
    ));
  }

  // 🔥 ARTWORK
  Uri? _getArtUri(String path) {
    final artFile = File('${path}_art.jpg');
    if (artFile.existsSync()) {
      return Uri.file(artFile.path);
    }
    return Uri.parse('asset:///assets/icon/icon.png');
  }

  // 🔥 RESET PLAYER - BACKGROUND SE WAPAS AANE PAR
  Future<void> resetPlayer() async {
    print('🔄 Resetting player...');
    await _player.stop();
    _isPlayerReady = false;
    _currentSongPath = null;
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
  }

  // 🔥 GET CURRENT STATE
  bool get isPlaying => _player.playing;
  bool get isReady => _isPlayerReady;
  String? get currentSong => _currentSongPath;

  // 🔥 OVERRIDE METHODS
  @override 
  Future<void> play() async {
    print('▶️ Play called');
    if (!_isPlayerReady) {
      print('⚠️ Player not ready, cannot play');
      return;
    }
    await _player.play();
    _updatePlaybackState(true);
  }
  
  @override 
  Future<void> pause() async {
    print('⏸️ Pause called');
    await _player.pause();
    _updatePlaybackState(false);
  }
  
  @override 
  Future<void> stop() async {
    print('⏹️ Stop called');
    await _player.stop();
    _isPlayerReady = false;
    _currentSongPath = null;
    _updatePlaybackState(false);
    await AudioService.stop();
    await super.stop();
  }
  
  @override 
  Future<void> seek(Duration p) async {
    if (_isPlayerReady) {
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
  
  @override 
  Future<void> skipToNext() async {}
  
  @override 
  Future<void> skipToPrevious() async {}
  
  @override 
  Future<void> fastForward() async {
    if (_isPlayerReady) {
      final pos = await _player.position;
      await _player.seek(pos + const Duration(seconds: 10));
    }
  }
  
  @override 
  Future<void> rewind() async {
    if (_isPlayerReady) {
      final pos = await _player.position;
      await _player.seek(pos - const Duration(seconds: 10));
    }
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
    print('📱 Task removed, stopping...');
    await _player.stop();
    _isPlayerReady = false;
    _currentSongPath = null;
    await AudioService.stop();
    await super.stop();
  }

  // 🔥 DISPOSE
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
      androidEnableQueue: true,
      androidStopForegroundOnPause: false,
      androidNotificationOngoing: true,
      androidNotificationClickStartsActivity: true,
      androidNotificationPlayPauseEnabled: true,
    ),
  );
  
  print('✅ Audio service initialized');
  return audioHandler!;
}
