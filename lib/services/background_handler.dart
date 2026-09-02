import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

AudioHandler? audioHandler;

class MyAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  
  // 🔥 STREAMS KO EXPOSE KARO
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

    // Position
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        playing: _player.playing,
      ));
    });

    // Player State - 🔥 FIX: Proper mapping taaki state sync rahe
    _player.playerStateStream.listen((state) {
      final playing = state.playing;
      playbackState.add(playbackState.value.copyWith(
        playing: playing,
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[state.processingState] ?? AudioProcessingState.idle,
      ));
    });
  }

  Future<void> playSong(String path, String title, String artist) async {
    try {
      // 🔥 Naya gaana chalane se pehle purana stop karo taaki overlap na ho
      await _player.stop();
      
      final file = File(path);
      if (!await file.exists()) throw Exception('File not found: $path');
      
      await _player.setAudioSource(AudioSource.uri(Uri.file(path)));
      await _player.play();
      
      mediaItem.add(MediaItem(
        id: path,
        title: title,
        artist: artist,
        duration: _player.duration,
      ));
      
      playbackState.add(playbackState.value.copyWith(
        playing: true,
        processingState: AudioProcessingState.ready,
      ));
    } catch (e) {
      rethrow;
    }
  }

  @override Future<void> play() async => _player.play();
  @override Future<void> pause() async => _player.pause();
  @override Future<void> stop() async => _player.stop();
  @override Future<void> seek(Duration p) async => _player.seek(p);
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
  audioHandler = MyAudioHandler();
  return audioHandler!;
}
