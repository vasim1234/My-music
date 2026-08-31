import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class MusicPlayerTask extends BackgroundAudioTask {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  String _currentTitle = 'My Music 3D';
  String _currentArtist = 'Music Player';
  Duration _currentDuration = Duration.zero;
  String _currentImage = '';

  @override
  Future<void> onStart(Map<String, dynamic>? params) async {
    await _setupAudioSession();
    await _updateMediaItem();
  }

  Future<void> _setupAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration.music());
    } catch (e) {
      print('Audio session error: $e');
    }
  }

  Future<void> _updateMediaItem() async {
    final mediaItem = MediaItem(
      id: 'current_song',
      album: 'My Music 3D',
      title: _currentTitle,
      artist: _currentArtist,
      duration: _currentDuration,
      artUri: Uri.tryParse(_currentImage),
    );
    AudioService.setMediaItem(mediaItem);
    await _updatePlaybackState();
  }

  Future<void> _updatePlaybackState() async {
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
    await _updatePlaybackState();
  }

  @override
  Future<void> onPause() async {
    _playing = false;
    await _player.pause();
    await _updatePlaybackState();
  }

  @override
  Future<void> onSkipToNext() async {
    // Will be handled by main app
    _currentTitle = 'Next Song';
    await _updateMediaItem();
  }

  @override
  Future<void> onSkipToPrevious() async {
    _currentTitle = 'Previous Song';
    await _updateMediaItem();
  }

  @override
  Future<void> onStop() async {
    await _player.stop();
    _playing = false;
    await _updatePlaybackState();
    await super.onStop();
  }

  @override
  Future<void> onSeekTo(Duration position) async {
    await _player.seek(position);
  }

  // ===== Update from Main App =====
  void updateSong(String title, String artist, Duration duration, {String? image}) {
    _currentTitle = title;
    _currentArtist = artist;
    _currentDuration = duration;
    if (image != null) {
      _currentImage = image;
    }
    _updateMediaItem();
  }

  void setPlaying(bool playing) {
    _playing = playing;
    _updatePlaybackState();
  }

  void setUrl(String url) {
    // For playing from URL
  }
}

// ============================================================
// HELPER FUNCTION TO INITIALIZE SERVICE
// ============================================================
Future<void> initAudioService() async {
  await AudioService.init(
    builder: () => MusicPlayerTask(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.music.app.my_music',
      androidNotificationChannelName: 'My Music 3D',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
}

// ============================================================
// HELPER FUNCTION TO UPDATE SONG INFO
// ============================================================
void updateBackgroundSong(String title, String artist, Duration duration, {String? image}) {
  try {
    final task = AudioService.currentTask;
    if (task != null && task is MusicPlayerTask) {
      task.updateSong(title, artist, duration, image: image);
    }
  } catch (e) {
    print('Error updating background song: $e');
  }
}

void setBackgroundPlaying(bool playing) {
  try {
    final task = AudioService.currentTask;
    if (task != null && task is MusicPlayerTask) {
      task.setPlaying(playing);
    }
  } catch (e) {
    print('Error setting background playing: $e');
  }
}
