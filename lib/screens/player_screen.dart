import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/album_art.dart';
import '../services/audio_manager.dart';

// ============================================================
// CONSTANTS
// ============================================================
class AppConstants {
  static const int maxRecentSongs = 50;
  static const int maxSongNameLength = 35;
  
  static const Color bgColor = Color(0xFF0A0A0F);
  static const Color cardColor = Color(0xFF16161E);
  static const Color accentColor = Color(0xFF6C63FF);
  static const Color textSecondary = Color(0xFF8888AA);
  static const Color errorColor = Color(0xFFFF6B6B);
  static const Color warningColor = Color(0xFFFF9F43);
  
  static const List<Color> primaryGradient = [
    Color(0xFF6C63FF),
    Color(0xFF3F3D9E),
  ];
  
  static const List<Color> secondaryGradient = [
    Color(0xFF4ECDC4),
    Color(0xFF2C7A78),
  ];
  
  static const List<List<Color>> albumGradients = [
    [Color(0xFF6C63FF), Color(0xFF3F3D9E)],
    [Color(0xFFFF6B6B), Color(0xFFC0392B)],
    [Color(0xFF4ECDC4), Color(0xFF2C7A78)],
    [Color(0xFFFF9F43), Color(0xFFE17055)],
    [Color(0xFFA29BFE), Color(0xFF6C5CE7)],
    [Color(0xFFFD79A8), Color(0xFFE84393)],
    [Color(0xFF00B894), Color(0xFF00A86B)],
    [Color(0xFFFDCB6E), Color(0xFFF39C12)],
    [Color(0xFF74B9FF), Color(0xFF2980B9)],
    [Color(0xFFFD7272), Color(0xFFB33939)],
    [Color(0xFF55E6C1), Color(0xFF1ABC9C)],
    [Color(0xFFFFC312), Color(0xFFF9A825)],
  ];
  
  static const Map<String, List<double>> eqPresets = {
    'Normal': [0, 0, 0],
    'Bass Boost': [8, 0, -4],
    'Treble Boost': [-4, 0, 8],
    'Pop': [3, 0, 3],
    'Rock': [5, 2, 4],
    'Classical': [-2, 1, 5],
    'Jazz': [4, 1, 3],
    'Vocal': [0, 4, 0],
    'Hip Hop': [6, -1, -2],
    'Electronic': [4, 0, 5],
  };
  
  static const List<String> bandLabels = ['Bass', 'Mid', 'Treble'];
  static const List<int> sleepTimerOptions = [5, 10, 15, 20, 30, 45, 60];
}

// ============================================================
// HELPERS
// ============================================================
class AppHelpers {
  static String cleanSongName(String fileName) {
    String name = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    name = name.replaceAll(RegExp(r'\(\w*_\d+K\)', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\(\d+K\)', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\(MP3_\d+K\)', caseSensitive: false), '');
    name = name.trim();
    if (name.length > AppConstants.maxSongNameLength) {
      name = '${name.substring(0, AppConstants.maxSongNameLength)}...';
    }
    return name;
  }
  
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
  
  static List<Color> getSongGradient(int index) {
    return AppConstants.albumGradients[index % AppConstants.albumGradients.length];
  }
}

// ============================================================
// SONG MODEL
// ============================================================
class Song {
  final String path;
  final String name;
  final String artist;
  bool isFavorite;
  DateTime? lastPlayed;

  Song({
    required this.path,
    required this.name,
    this.artist = 'Unknown Artist',
    this.isFavorite = false,
    this.lastPlayed,
  });

  String get displayName => AppHelpers.cleanSongName(name);
  String get firstLetter => displayName.substring(0, 1).toUpperCase();
  bool get exists => File(path).existsSync();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song && runtimeType == other.runtimeType && path == other.path;

  @override
  int get hashCode => path.hashCode;

  Song copyWith({
    String? path,
    String? name,
    String? artist,
    bool? isFavorite,
    DateTime? lastPlayed,
  }) {
    return Song(
      path: path ?? this.path,
      name: name ?? this.name,
      artist: artist ?? this.artist,
      isFavorite: isFavorite ?? this.isFavorite,
      lastPlayed: lastPlayed ?? this.lastPlayed,
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'artist': artist,
    'isFavorite': isFavorite,
    'lastPlayed': lastPlayed?.toIso8601String(),
  };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
    path: json['path'],
    name: json['name'],
    artist: json['artist'] ?? 'Unknown Artist',
    isFavorite: json['isFavorite'] ?? false,
    lastPlayed: json['lastPlayed'] != null 
        ? DateTime.parse(json['lastPlayed']) 
        : null,
  );
}

// ============================================================
// AUDIO MANAGER EXTENDED - COMPLETE
// ============================================================
enum PlaybackStatus { stopped, playing, paused }

class AudioManagerExtended extends ChangeNotifier {
  final AudioManager _audioManager = AudioManager();
  
  // ============================================================
  // VARIABLES
  // ============================================================
  PlaybackStatus _status = PlaybackStatus.stopped;
  Song? _currentSong;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  bool _isShuffle = false;
  int _repeatMode = 0;
  
  List<Song> _queue = [];
  int _currentIndex = 0;
  List<Song> _recent = [];
  List<Song> _favorites = [];
  Map<String, List<Song>> _playlists = {};
  
  StreamSubscription<Duration?>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  bool _isCompleting = false;
  
  // ============================================================
  // GETTERS
  // ============================================================
  PlaybackStatus get status => _status;
  Song? get currentSong => _currentSong;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  bool get isPlaying => _status == PlaybackStatus.playing;
  bool get isPaused => _status == PlaybackStatus.paused;
  bool get isStopped => _status == PlaybackStatus.stopped;
  bool get isShuffle => _isShuffle;
  int get repeatMode => _repeatMode;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  List<Song> get recent => _recent;
  List<Song> get favorites => _favorites;
  Map<String, List<Song>> get playlists => _playlists;

  // ============================================================
  // CONSTRUCTOR & INIT
  // ============================================================
  AudioManagerExtended() {
    _init();
  }

  Future<void> _init() async {
    _audioManager.init();
    _setupStreams();
    _loadSavedData();
  }

  // ============================================================
  // STREAMS & COMPLETION
  // ============================================================
  void _setupStreams() {
    _positionSubscription = _audioManager.positionStream.listen((position) {
      if (position != null) {
        _position = position;
        notifyListeners();
        _checkSongCompletion();
      }
    });

    _durationSubscription = _audioManager.durationStream.listen((duration) {
      if (duration != null) {
        _duration = duration;
        notifyListeners();
      }
    });
  }

  void _checkSongCompletion() {
    if (_status == PlaybackStatus.playing && 
        _duration.inSeconds > 0 && 
        _position.inSeconds >= _duration.inSeconds - 1 &&
        !_isCompleting) {
      
      _isCompleting = true;
      _onSongComplete();
      
      Future.delayed(const Duration(milliseconds: 500), () {
        _isCompleting = false;
      });
    }
  }

  void _onSongComplete() {
    if (_repeatMode == 1) {
      _playCurrent();
    } else if (_repeatMode == 2 || _isShuffle) {
      _playNext();
    } else {
      if (_currentIndex < _queue.length - 1) {
        _playNext();
      } else {
        _status = PlaybackStatus.stopped;
        _currentSong = null;
        notifyListeners();
        _saveData();
      }
    }
  }

  Future<void> _playCurrent() async {
    if (_queue.isEmpty || _currentIndex >= _queue.length) return;
    
    final song = _queue[_currentIndex];
    if (!song.exists) {
      _queue.remove(song);
      if (_currentIndex >= _queue.length) {
        _currentIndex = _queue.isNotEmpty ? _queue.length - 1 : 0;
      }
      notifyListeners();
      _saveData();
      return;
    }

    try {
      _currentSong = song;
      await _audioManager.playSong(song.path, song.displayName, song.artist);
      _status = PlaybackStatus.playing;
      
      _recent.remove(song);
      _recent.insert(0, song);
      if (_recent.length > AppConstants.maxRecentSongs) _recent.removeLast();
      
      _queue[_currentIndex] = song.copyWith(lastPlayed: DateTime.now());
      
      _isCompleting = false;
      notifyListeners();
      _saveData();
    } catch (e) {
      _status = PlaybackStatus.stopped;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _playNext() async {
    if (_queue.isEmpty) return;
    
    await _audioManager.stop();
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (_isShuffle && _queue.length > 1) {
      int newIndex;
      do {
        newIndex = DateTime.now().millisecondsSinceEpoch % _queue.length;
      } while (newIndex == _currentIndex && _queue.length > 1);
      _currentIndex = newIndex;
    } else {
      _currentIndex = (_currentIndex + 1) % _queue.length;
    }
    
    _isCompleting = false;
    await _playCurrent();
  }

  // ============================================================
  // QUEUE PERSISTENCE
  // ============================================================
  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> queuePaths = _queue.map((s) => s.path).toList();
      await prefs.setStringList('queue', queuePaths);
      await prefs.setInt('currentIndex', _currentIndex);
    } catch (e) {
      print('❌ Error saving queue: $e');
    }
  }

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      List<String>? queuePaths = prefs.getStringList('queue');
      if (queuePaths != null && queuePaths.isNotEmpty) {
        _queue = queuePaths
            .where((path) => File(path).existsSync())
            .map((path) => Song(path: path, name: path.split('/').last))
            .toList();
        
        _currentIndex = prefs.getInt('currentIndex') ?? 0;
        if (_currentIndex >= _queue.length) {
          _currentIndex = _queue.isNotEmpty ? _queue.length - 1 : 0;
        }
        
        if (_queue.isNotEmpty && _currentIndex < _queue.length) {
          _currentSong = _queue[_currentIndex];
        }
      }
    } catch (e) {
      print('❌ Error loading queue: $e');
    }
  }

  // ============================================================
  // SAVE/LOAD DATA
  // ============================================================
  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await _loadQueue();
      
      List<String>? recentPaths = prefs.getStringList('recent');
      if (recentPaths != null && recentPaths.isNotEmpty) {
        _recent = recentPaths
            .where((path) => File(path).existsSync())
            .map((path) => Song(path: path, name: path.split('/').last))
            .toList();
      }
      
      _isShuffle = prefs.getBool('isShuffle') ?? false;
      _repeatMode = prefs.getInt('repeatMode') ?? 0;
      _volume = prefs.getDouble('volume') ?? 1.0;
      
      String? playlistsJson = prefs.getString('playlists');
      if (playlistsJson != null) {
        Map<String, dynamic> decoded = jsonDecode(playlistsJson);
        decoded.forEach((key, value) {
          List<String> paths = List<String>.from(value);
          _playlists[key] = paths
              .where((path) => File(path).existsSync())
              .map((path) => Song(path: path, name: path.split('/').last))
              .toList();
        });
      }
      
      notifyListeners();
    } catch (e) {
      print('❌ Error loading data: $e');
    }
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await _saveQueue();
      
      List<String> recentPaths = _recent.map((s) => s.path).toList();
      await prefs.setStringList('recent', recentPaths);
      
      await prefs.setBool('isShuffle', _isShuffle);
      await prefs.setInt('repeatMode', _repeatMode);
      await prefs.setDouble('volume', _volume);
      
      Map<String, List<String>> playlistMap = {};
      _playlists.forEach((key, value) {
        playlistMap[key] = value.map((s) => s.path).toList();
      });
      await prefs.setString('playlists', jsonEncode(playlistMap));
      
    } catch (e) {
      print('❌ Error saving data: $e');
    }
  }

  // ============================================================
  // PUBLIC METHODS - PLAYLIST
  // ============================================================
  
  void createPlaylist(String name) {
    if (name.trim().isNotEmpty && !_playlists.containsKey(name)) {
      _playlists[name.trim()] = [];
      _saveData();
      notifyListeners();
      print('✅ Playlist created: $name');
    }
  }

  void deletePlaylist(String name) {
    _playlists.remove(name);
    _saveData();
    notifyListeners();
    print('✅ Playlist deleted: $name');
  }

  void addToPlaylist(String name, Song song) {
    if (!_playlists.containsKey(name)) {
      _playlists[name] = [];
    }
    if (!_playlists[name]!.contains(song)) {
      _playlists[name]!.add(song);
      _saveData();
      notifyListeners();
      print('✅ Added "${song.displayName}" to playlist: $name');
    }
  }

  void addSongsToPlaylist(String name, List<Song> songs) {
    if (!_playlists.containsKey(name)) {
      _playlists[name] = [];
    }
    final currentSongs = _playlists[name]!;
    for (var song in songs) {
      if (!currentSongs.contains(song)) {
        currentSongs.add(song);
      }
    }
    _saveData();
    notifyListeners();
    print('✅ Added ${songs.length} songs to playlist: $name');
  }

  void removeFromPlaylist(String name, Song song) {
    if (_playlists.containsKey(name)) {
      _playlists[name]!.remove(song);
      if (_playlists[name]!.isEmpty) {
        _playlists.remove(name);
      }
      _saveData();
      notifyListeners();
      print('✅ Removed "${song.displayName}" from playlist: $name');
    }
  }

  // ============================================================
  // PUBLIC METHODS - PLAYBACK
  // ============================================================
  
  Future<void> playSong(Song song, {List<Song>? queue}) async {
    if (queue != null && queue.isNotEmpty) {
      _queue = List.from(queue);
      _currentIndex = _queue.indexOf(song);
      if (_currentIndex == -1) {
        _queue.add(song);
        _currentIndex = _queue.length - 1;
      }
    } else {
      int index = _queue.indexOf(song);
      if (index != -1) {
        _currentIndex = index;
      } else {
        _queue.add(song);
        _currentIndex = _queue.length - 1;
      }
    }
    await _playCurrent();
    _saveData();
  }

  Future<void> playNext() async => _playNext();

  Future<void> playPrevious() async {
    if (_queue.isEmpty) return;
    
    await _audioManager.stop();
    await Future.delayed(const Duration(milliseconds: 200));
    
    _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    await _playCurrent();
    _saveData();
  }

  Future<void> togglePlayPause() async {
    if (_queue.isEmpty) return;
    
    if (_status == PlaybackStatus.playing) {
      await _audioManager.pause();
      _status = PlaybackStatus.paused;
      notifyListeners();
    } else {
      if (_currentSong == null) {
        await _playCurrent();
      } else {
        await _audioManager.play();
        _status = PlaybackStatus.playing;
        notifyListeners();
      }
    }
    _saveData();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle) _repeatMode = 0;
    _saveData();
    notifyListeners();
  }

  void toggleFavorite(Song song) {
    final index = _favorites.indexOf(song);
    if (index != -1) {
      _favorites.removeAt(index);
    } else {
      _favorites.add(song);
    }
    final queueIndex = _queue.indexOf(song);
    if (queueIndex != -1) {
      _queue[queueIndex] = song.copyWith(isFavorite: !song.isFavorite);
    }
    _saveData();
    notifyListeners();
  }

  void setRepeatMode(int mode) {
    _repeatMode = mode;
    if (_repeatMode != 0) _isShuffle = false;
    _saveData();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioManager.seek(position);
    _position = position;
    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioManager.setVolume(_volume);
    _saveData();
    notifyListeners();
  }

  void clearQueue() {
    _queue.clear();
    _currentSong = null;
    _currentIndex = 0;
    _status = PlaybackStatus.stopped;
    _position = Duration.zero;
    _duration = Duration.zero;
    _saveData();
    notifyListeners();
  }

  void addSongsToQueue(List<Song> songs) {
    _queue.addAll(songs);
    _saveData();
    notifyListeners();
  }

  void removeFromQueue(Song song) {
    _queue.remove(song);
    if (_currentIndex >= _queue.length) {
      _currentIndex = _queue.isNotEmpty ? _queue.length - 1 : 0;
    }
    if (_queue.isEmpty) {
      _currentSong = null;
      _status = PlaybackStatus.stopped;
    }
    _saveData();
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioManager.dispose();
    super.dispose();
  }
}

// ============================================================
// PLAYER SCREEN
// ============================================================
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  // ✅ AudioManagerExtended instance
  late AudioManagerExtended _audioManager;
  
  int _selectedTab = 0;
  bool _is3DMode = false;
  bool _sleepTimerActive = false;
  int _sleepTimerMinutes = 0;
  Timer? _sleepTimer;
  
  bool _isEqActive = false;
  String _currentEqPreset = 'Normal';
  List<double> _currentEqValues = [0, 0, 0];
  double _baseVolume = 1.0;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _audioManager = AudioManagerExtended();
    _audioManager.addListener(_onAudioManagerChanged);
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _loadEQState();
  }

  void _onAudioManagerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadEQState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEqActive = prefs.getBool('eqActive') ?? false;
      _currentEqPreset = prefs.getString('eqPreset') ?? 'Normal';
      
      List<String>? eqValues = prefs.getStringList('eqValues');
      if (eqValues != null && eqValues.length == 3) {
        _currentEqValues = eqValues.map((v) => double.tryParse(v) ?? 0).toList();
      }
      _baseVolume = prefs.getDouble('baseVolume') ?? 1.0;
      setState(() {});
    } catch (e) {
      print('❌ Error loading EQ state: $e');
    }
  }

  Future<void> _saveEQState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('eqActive', _isEqActive);
      await prefs.setString('eqPreset', _currentEqPreset);
      await prefs.setStringList('eqValues', _currentEqValues.map((v) => v.toString()).toList());
      await prefs.setDouble('baseVolume', _baseVolume);
    } catch (e) {
      print('❌ Error saving EQ state: $e');
    }
  }

  Future<void> _applyEqualizer() async {
    if (!_isEqActive) {
      await _audioManager.setVolume(_baseVolume);
      return;
    }
    
    double bass = _currentEqValues[0];
    double mid = _currentEqValues[1];
    double treble = _currentEqValues[2];
    
    double volumeEffect = 1.0 + (bass + mid + treble) * 0.015;
    double newVolume = (_baseVolume * volumeEffect).clamp(0.0, 1.0);
    await _audioManager.setVolume(newVolume);
  }

  @override
  void dispose() {
    _audioManager.removeListener(_onAudioManagerChanged);
    _audioManager.dispose();
    _sleepTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ============================================================
  // SLEEP TIMER
  // ============================================================
  void _startSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    setState(() {
      _sleepTimerActive = true;
      _sleepTimerMinutes = minutes;
    });
    
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      if (mounted) {
        setState(() {
          _sleepTimerActive = false;
          _sleepTimerMinutes = 0;
        });
        _audioManager.togglePlayPause();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏰ Sleep timer: Playback stopped'),
            backgroundColor: AppConstants.warningColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    setState(() {
      _sleepTimerActive = false;
      _sleepTimerMinutes = 0;
    });
  }

  // ============================================================
  // PICK SONGS
  // ============================================================
  Future<void> _pickSongs() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final songs = result.files.map((file) => Song(
          path: file.path!,
          name: file.name,
        )).toList();
        
        if (_audioManager.queue.isEmpty) {
          await _audioManager.playSong(songs.first, queue: songs);
        } else {
          for (var song in songs) {
            _audioManager.queue.add(song);
          }
          setState(() {});
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${songs.length} songs added'),
            backgroundColor: AppConstants.accentColor.withOpacity(0.3),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
    }
  }

  // ============================================================
  // EQ DIALOG
  // ============================================================
  void _showEqualizerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEQHeader(setModalState),
                  const Divider(color: Colors.white24),
                  _buildEQPresets(setModalState),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  _buildEQSliders(setModalState),
                  const SizedBox(height: 8),
                  _buildEQToggle(setModalState),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEQHeader(StateSetter setModalState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppConstants.primaryGradient),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.equalizer, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Equalizer', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            if (_isEqActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('ON', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
              onPressed: () async {
                setState(() {
                  _currentEqPreset = 'Normal';
                  _currentEqValues = [0, 0, 0];
                  _isEqActive = false;
                });
                setModalState(() {});
                await _applyEqualizer();
                _saveEQState();
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEQPresets(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PRESETS', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppConstants.eqPresets.keys.map((preset) {
            bool isSelected = _currentEqPreset == preset;
            return FilterChip(
              label: Text(preset, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 11)),
              selected: isSelected,
              selectedColor: AppConstants.accentColor.withOpacity(0.3),
              backgroundColor: AppConstants.cardColor,
              side: BorderSide(color: isSelected ? AppConstants.accentColor : Colors.grey.shade700, width: 1.5),
              onSelected: (selected) async {
                if (selected) {
                  setState(() {
                    _currentEqPreset = preset;
                    _currentEqValues = List.from(AppConstants.eqPresets[preset]!);
                    _isEqActive = preset != 'Normal';
                  });
                  setModalState(() {});
                  await _applyEqualizer();
                  _saveEQState();
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEQSliders(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('3 BAND EQUALIZER', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: 3,
            itemBuilder: (context, index) {
              final colors = [Colors.red, Colors.green, Colors.blue];
              final color = colors[index % colors.length];
              
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppConstants.bandLabels[index],
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _currentEqValues[index] > 0 
                              ? '+${_currentEqValues[index].toInt()}' 
                              : '${_currentEqValues[index].toInt()}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _currentEqValues[index],
                    min: -10,
                    max: 10,
                    activeColor: color,
                    inactiveColor: Colors.grey.shade800,
                    onChanged: (value) async {
                      setState(() {
                        _currentEqValues[index] = value;
                        _currentEqPreset = 'Custom';
                        _isEqActive = true;
                      });
                      setModalState(() {});
                      await _applyEqualizer();
                      _saveEQState();
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEQToggle(StateSetter setModalState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Enable Equalizer', style: TextStyle(color: Colors.white, fontSize: 14)),
        Switch(
          value: _isEqActive,
          activeColor: AppConstants.accentColor,
          activeTrackColor: AppConstants.accentColor.withOpacity(0.3),
          onChanged: (value) async {
            setState(() {
              _isEqActive = value;
              if (!value) {
                _currentEqValues = [0, 0, 0];
                _currentEqPreset = 'Normal';
              }
            });
            setModalState(() {});
            await _applyEqualizer();
            _saveEQState();
          },
        ),
      ],
    );
  }

  // ============================================================
  // VOLUME POPUP
  // ============================================================
  void _showVolumePopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              height: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: AppConstants.primaryGradient,
                        ).createShader(bounds),
                        child: const Icon(Icons.volume_up, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text('Volume', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.volume_down, color: Colors.white54),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            activeTrackColor: AppConstants.accentColor,
                            inactiveTrackColor: Colors.grey.shade800,
                            thumbColor: AppConstants.accentColor,
                          ),
                          child: Slider(
                            min: 0.0,
                            max: 1.0,
                            value: _audioManager.volume,
                            onChanged: (value) async {
                              setModalState(() {});
                              await _audioManager.setVolume(value);
                              _baseVolume = value;
                              if (_isEqActive) {
                                await _applyEqualizer();
                              }
                              _saveEQState();
                            },
                          ),
                        ),
                      ),
                      const Icon(Icons.volume_up, color: Colors.white54),
                    ],
                  ),
                  Center(
                    child: Text(
                      '${(_audioManager.volume * 100).toInt()}%',
                      style: TextStyle(color: AppConstants.accentColor, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // SLEEP TIMER DIALOG
  // ============================================================
  void _showSleepTimerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              height: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppConstants.warningColor, Color(0xFFE17055)]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.timer, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text('Sleep Timer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (_sleepTimerActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${_sleepTimerMinutes}m', style: const TextStyle(color: Colors.green, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Stop playback after:', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppConstants.sleepTimerOptions.map((minutes) {
                      return GestureDetector(
                        onTap: () {
                          _startSleepTimer(minutes);
                          setModalState(() {});
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: _sleepTimerActive && _sleepTimerMinutes == minutes
                                ? const LinearGradient(colors: [AppConstants.warningColor, Color(0xFFE17055)])
                                : null,
                            color: _sleepTimerActive && _sleepTimerMinutes == minutes ? null : AppConstants.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _sleepTimerActive && _sleepTimerMinutes == minutes
                                  ? Colors.transparent
                                  : Colors.grey.shade700,
                            ),
                          ),
                          child: Text(
                            '$minutes min',
                            style: TextStyle(
                              color: _sleepTimerActive && _sleepTimerMinutes == minutes
                                  ? Colors.white
                                  : Colors.white70,
                              fontWeight: _sleepTimerActive && _sleepTimerMinutes == minutes
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  if (_sleepTimerActive)
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          _cancelSleepTimer();
                          setModalState(() {});
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cancel, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Cancel Timer', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // SHUFFLE/REPEAT MENU
  // ============================================================
  void _showShuffleRepeatMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: AppConstants.primaryGradient),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.repeat, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Playback Mode', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              _buildMenuOption(
                icon: Icons.shuffle,
                title: 'Shuffle',
                subtitle: 'Play songs in random order',
                isActive: _audioManager.isShuffle,
                onTap: () {
                  _audioManager.toggleShuffle();
                  Navigator.pop(context);
                },
              ),
              const Divider(color: Colors.white24),
              _buildMenuOption(
                icon: Icons.repeat_outlined,
                title: 'Repeat Off',
                subtitle: 'Stop after current song',
                isActive: _audioManager.repeatMode == 0 && !_audioManager.isShuffle,
                onTap: () {
                  _audioManager.setRepeatMode(0);
                  Navigator.pop(context);
                },
              ),
              const Divider(color: Colors.white24),
              _buildMenuOption(
                icon: Icons.repeat_one,
                title: 'Repeat One',
                subtitle: 'Repeat current song',
                isActive: _audioManager.repeatMode == 1,
                onTap: () {
                  _audioManager.setRepeatMode(1);
                  Navigator.pop(context);
                },
              ),
              const Divider(color: Colors.white24),
              _buildMenuOption(
                icon: Icons.repeat,
                title: 'Repeat All',
                subtitle: 'Repeat entire queue',
                isActive: _audioManager.repeatMode == 2,
                onTap: () {
                  _audioManager.setRepeatMode(2);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: isActive ? const LinearGradient(colors: AppConstants.primaryGradient) : null,
                color: isActive ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isActive ? Colors.white : Colors.white54, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isActive ? AppConstants.accentColor : Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            if (isActive) Icon(Icons.check_circle, color: AppConstants.accentColor, size: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SONG POPUP
  // ============================================================
  void _showSongPopup(Song song, {List<Song>? playlist}) {
    bool isFavorite = _audioManager.favorites.contains(song);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppHelpers.getSongGradient(song.path.hashCode),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        song.firstLetter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          song.artist,
                          style: const TextStyle(
                            color: AppConstants.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              _buildPopupOption(
                icon: Icons.play_arrow,
                title: 'Play Now',
                subtitle: 'Start playing this song',
                color: AppConstants.accentColor,
                onTap: () {
                  Navigator.pop(context);
                  _audioManager.playSong(song, queue: playlist);
                },
              ),
              _buildPopupOption(
                icon: Icons.playlist_add,
                title: 'Play Next',
                subtitle: 'Add to queue after current',
                color: AppConstants.secondaryGradient[0],
                onTap: () {
                  Navigator.pop(context);
                  _audioManager.playNext();
                },
              ),
              _buildPopupOption(
                icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                title: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                subtitle: isFavorite ? 'Remove from your favorites' : 'Save to your favorites',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _audioManager.toggleFavorite(song);
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPopupOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppConstants.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade800, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppConstants.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SONG LIST ITEM
  // ============================================================
  Widget _buildSongListItem(Song song, int index, {List<Song>? playlist}) {
    bool isFavorite = _audioManager.favorites.contains(song);
    List<Color> gradient = AppHelpers.getSongGradient(index);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppConstants.cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              song.firstLetter,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          song.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          playlist != null ? 'Playlist' : 'Master List',
          style: TextStyle(
            color: AppConstants.textSecondary,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.red : Colors.white54,
            size: 20,
          ),
          onPressed: () {
            _audioManager.toggleFavorite(song);
            setState(() {});
          },
        ),
        onLongPress: () => _showSongPopup(song, playlist: playlist),
        onTap: () => _audioManager.playSong(song, queue: playlist),
      ),
    );
  }

  // ============================================================
  // PLAYLIST FUNCTIONS
  // ============================================================
  void _showCreatePlaylistDialog() {
    String name = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: const TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppConstants.accentColor.withOpacity(0.3)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppConstants.accentColor),
            ),
          ),
          onChanged: (value) => name = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              _audioManager.createPlaylist(name);
              Navigator.pop(context);
            },
            child: Text('Create', style: TextStyle(color: AppConstants.accentColor)),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistDialog(String playlistName) {
    List<Song> availableSongs = _audioManager.queue.where((song) =>
      !_audioManager.playlists[playlistName]!.contains(song)
    ).toList();

    if (_audioManager.queue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ No songs in queue. Add songs first!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (availableSongs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ All songs already in this playlist!'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    List<Song> selectedSongs = [];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: AppConstants.secondaryGradient),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.playlist_add, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Add to $playlistName',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: selectedSongs.length == availableSongs.length && availableSongs.isNotEmpty,
                        onChanged: (value) {
                          setModalState(() {
                            if (value == true) {
                              selectedSongs = List.from(availableSongs);
                            } else {
                              selectedSongs.clear();
                            }
                          });
                        },
                        activeColor: AppConstants.accentColor,
                      ),
                      Text(
                        'Select All (${availableSongs.length})',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const Spacer(),
                      if (selectedSongs.isNotEmpty)
                        Container(
                          height: 35,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: AppConstants.primaryGradient),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              for (var song in selectedSongs) {
                                _audioManager.addToPlaylist(playlistName, song);
                              }
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ ${selectedSongs.length} songs added to $playlistName'),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: Text('Add ${selectedSongs.length} Songs'),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: availableSongs.length,
                      itemBuilder: (context, index) {
                        final song = availableSongs[index];
                        bool isSelected = selectedSongs.contains(song);
                        List<Color> gradient = AppHelpers.getSongGradient(index);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppConstants.accentColor.withOpacity(0.1) : AppConstants.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected 
                                ? Border.all(color: AppConstants.accentColor.withOpacity(0.5), width: 1.5) 
                                : null,
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: gradient),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  song.firstLetter,
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            title: Text(
                              song.displayName,
                              style: TextStyle(
                                color: isSelected ? AppConstants.accentColor : Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Checkbox(
                              value: isSelected,
                              onChanged: (value) {
                                setModalState(() {
                                  if (value == true) {
                                    selectedSongs.add(song);
                                  } else {
                                    selectedSongs.remove(song);
                                  }
                                });
                              },
                              activeColor: AppConstants.accentColor,
                            ),
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  selectedSongs.remove(song);
                                } else {
                                  selectedSongs.add(song);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _clearQueue() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Queue?', style: TextStyle(color: Colors.white)),
        content: const Text('Remove all songs from queue?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              _audioManager.clearQueue();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: AppConstants.errorColor)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB BUILDERS
  // ============================================================
  Widget _buildFavoritesTab() {
    final favorites = _audioManager.favorites;
    if (favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('No favorites yet', style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        return _buildSongListItem(favorites[index], index);
      },
    );
  }

  Widget _buildRecentTab() {
    final recent = _audioManager.recent;
    if (recent.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('No recent songs', style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: recent.length,
      itemBuilder: (context, index) {
        return _buildSongListItem(recent[index], index);
      },
    );
  }

  Widget _buildPlaylistsTab() {
    final playlists = _audioManager.playlists;
    final queue = _audioManager.queue;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppConstants.primaryGradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton.icon(
              onPressed: _showCreatePlaylistDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Create New Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: playlists.keys.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Card(
                  color: AppConstants.cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Row(
                      children: [
                        const Icon(Icons.music_note, color: AppConstants.accentColor, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'All Songs',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${queue.length} songs',
                      style: const TextStyle(color: AppConstants.textSecondary),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: AppConstants.primaryGradient),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.library_music, color: Colors.white),
                    ),
                    children: queue.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No songs in queue. Add songs from Player screen!',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                          ]
                        : queue.asMap().entries.map((entry) {
                            return _buildSongListItem(entry.value, entry.key);
                          }).toList(),
                  ),
                );
              }
              
              final playlistIndex = index - 1;
              final playlistName = playlists.keys.elementAt(playlistIndex);
              final songs = playlists[playlistName]!;
              
              return Card(
                color: AppConstants.cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text(
                    playlistName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    '${songs.length} songs',
                    style: const TextStyle(color: AppConstants.textSecondary),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppHelpers.getSongGradient(playlistIndex),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.playlist_play, color: Colors.white),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: AppConstants.secondaryGradient),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.white, size: 20),
                          onPressed: () => _showAddToPlaylistDialog(playlistName),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          _audioManager.deletePlaylist(playlistName);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  children: songs.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Text(
                                  'No songs in this playlist',
                                  style: TextStyle(color: Colors.white54),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: AppConstants.primaryGradient),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showAddToPlaylistDialog(playlistName),
                                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                                    label: const Text(
                                      'Add Songs from Queue',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]
                      : songs.asMap().entries.map((entry) {
                          return _buildSongListItem(entry.value, entry.key, playlist: songs);
                        }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
// PLAYER UI - EXACT DESIGN
// ============================================================
Widget _buildPlayerUI() {
  final queue = _audioManager.queue;
  final currentSong = _audioManager.currentSong;
  final isPlaying = _audioManager.isPlaying;
  final currentIndex = _audioManager.currentIndex;
  
  String currentSongName = currentSong?.displayName ?? "No song playing";
  bool hasSongs = queue.isNotEmpty;
  List<Color> currentGradient = hasSongs 
      ? AppHelpers.getSongGradient(currentIndex)
      : AppConstants.primaryGradient;

  return SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ============================================================
          // SONG INFO - CENTER ALIGNED
          // ============================================================
          Column(
            children: [
              Text(
                currentSongName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                currentSong?.artist ?? "Luna Echo",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppConstants.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          
          const SizedBox(height: 30),
          
          // ============================================================
          // ALBUM ART
          // ============================================================
          AlbumArt(
            isPlaying: isPlaying,
            is3DMode: _is3DMode,
            songName: currentSongName,
            songPath: currentSong?.path,
            gradient: currentGradient,
            isSleepTimerActive: _sleepTimerActive,
            animation: _pulseAnimation,
            accentColor: AppConstants.accentColor,
          ),
          
          const SizedBox(height: 30),
          
          // ============================================================
          // PROGRESS BAR
          // ============================================================
          Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  activeTrackColor: AppConstants.accentColor,
                  inactiveTrackColor: Colors.grey.shade800,
                  thumbColor: AppConstants.accentColor,
                ),
                child: Slider(
                  min: 0.0,
                  max: _audioManager.duration.inSeconds.toDouble() > 0 
                      ? _audioManager.duration.inSeconds.toDouble() 
                      : 1.0,
                  value: _audioManager.position.inSeconds.toDouble().clamp(
                      0.0, 
                      _audioManager.duration.inSeconds.toDouble() > 0 
                          ? _audioManager.duration.inSeconds.toDouble() 
                          : 1.0
                  ),
                  onChanged: (value) async {
                    final position = Duration(seconds: value.toInt());
                    await _audioManager.seek(position);
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppHelpers.formatDuration(_audioManager.position),
                    style: const TextStyle(color: AppConstants.textSecondary, fontSize: 11),
                  ),
                  Text(
                    AppHelpers.formatDuration(_audioManager.duration),
                    style: const TextStyle(color: AppConstants.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // ============================================================
          // PLAYBACK CONTROLS - WITH REPEAT & QUEUE BUTTONS
          // ============================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LEFT: Repeat/Loop Button
              GestureDetector(
                onTap: _showShuffleRepeatMenu,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _audioManager.repeatMode != 0 
                        ? AppConstants.accentColor.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(
                    _audioManager.repeatMode == 0 ? Icons.repeat_outlined :
                    _audioManager.repeatMode == 1 ? Icons.repeat_one :
                    Icons.repeat,
                    color: _audioManager.repeatMode != 0 
                        ? AppConstants.accentColor 
                        : Colors.white54,
                    size: 22,
                  ),
                ),
              ),
              
              const SizedBox(width: 20),
              
              // PREVIOUS BUTTON
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
                child: IconButton(
                  icon: const Icon(Icons.skip_previous, color: Colors.white, size: 28),
                  onPressed: hasSongs ? () => _audioManager.playPrevious() : null,
                  padding: const EdgeInsets.all(12),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // PLAY/PAUSE BUTTON - PROMINENT
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: currentGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppConstants.accentColor.withOpacity(0.4),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 36,
                  ),
                  onPressed: () => _audioManager.togglePlayPause(),
                  padding: const EdgeInsets.all(18),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // NEXT BUTTON
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
                child: IconButton(
                  icon: const Icon(Icons.skip_next, color: Colors.white, size: 28),
                  onPressed: hasSongs ? () => _audioManager.playNext() : null,
                  padding: const EdgeInsets.all(12),
                ),
              ),
              
              const SizedBox(width: 20),
              
              // RIGHT: Queue/Playlist Button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTab = 3; // Switch to Playlists tab
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppConstants.secondaryGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.queue_music,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),
          
          // ============================================================
          // BOTTOM UTILITY ROW - 3D, EQ, Volume, Heart, Timer
          // ============================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 3D Audio
              _buildUtilityButton(
                icon: Icons.three_mp,
                label: '3D',
                isActive: _is3DMode,
                activeColor: Colors.purple,
                onTap: () {
                  setState(() {
                    _is3DMode = !_is3DMode;
                  });
                },
              ),
              
              // EQ (Equalizer)
              _buildUtilityButton(
                icon: Icons.equalizer,
                label: 'EQ',
                isActive: _isEqActive,
                activeColor: AppConstants.accentColor,
                onTap: _showEqualizerDialog,
              ),
              
              // Volume
              _buildUtilityButton(
                icon: Icons.volume_up,
                label: 'Volume',
                isActive: false,
                activeColor: Colors.white,
                onTap: _showVolumePopup,
              ),
              
              // Heart / Favorite
              _buildUtilityButton(
                icon: currentSong != null && _audioManager.favorites.contains(currentSong) 
                    ? Icons.favorite 
                    : Icons.favorite_border,
                label: 'Heart',
                isActive: currentSong != null && _audioManager.favorites.contains(currentSong),
                activeColor: Colors.red,
                onTap: () {
                  if (currentSong != null) {
                    _audioManager.toggleFavorite(currentSong);
                    setState(() {});
                  }
                },
              ),
              
              // Timer
              _buildUtilityButton(
                icon: Icons.timer,
                label: 'Timer',
                isActive: _sleepTimerActive,
                activeColor: AppConstants.warningColor,
                onTap: _showSleepTimerDialog,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

// ============================================================
// UTILITY BUTTON - For bottom row
// ============================================================
Widget _buildUtilityButton({
  required IconData icon,
  required String label,
  required bool isActive,
  required Color activeColor,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive 
                ? Border.all(color: activeColor.withOpacity(0.5), width: 1.5)
                : null,
          ),
          child: Icon(
            icon,
            color: isActive ? activeColor : Colors.white54,
            size: 22,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? activeColor : AppConstants.textSecondary,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}

  // ============================================================
  // BODY CONTENT
  // ============================================================
  Widget _buildBodyContent() {
    switch (_selectedTab) {
      case 1:
        return _buildFavoritesTab();
      case 2:
        return _buildRecentTab();
      case 3:
        return _buildPlaylistsTab();
      default:
        return _buildPlayerUI();
    }
  }

  // ============================================================
  // BUILD METHOD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgColor,
      appBar: AppBar(
        title: Text(
          _selectedTab == 0 ? 'My Music' : 
          _selectedTab == 1 ? 'Favorites' : 
          _selectedTab == 2 ? 'Recent' : 'Playlists',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_selectedTab == 0) ...[
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white70),
              onPressed: _pickSongs,
            ),
            IconButton(
              icon: const Icon(Icons.equalizer, color: Colors.white70),
              onPressed: _showEqualizerDialog,
            ),
            IconButton(
              icon: const Icon(Icons.clear_all, color: Colors.white70),
              onPressed: _clearQueue,
            ),
          ],
        ],
      ),
      body: _buildBodyContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        backgroundColor: AppConstants.cardColor,
        selectedItemColor: AppConstants.accentColor,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        onTap: (index) {
          setState(() => _selectedTab = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.play_circle_filled), label: 'Player'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Recent'),
          BottomNavigationBarItem(icon: Icon(Icons.playlist_play), label: 'Playlists'),
        ],
      ),
    );
  }
}
