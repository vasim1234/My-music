import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/album_art.dart';
import '../services/background_handler.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;
  
  bool isPlaying = false;
  bool is3DMode = false;
  bool isShuffle = false;
  int repeatMode = 0;
  
  List<PlatformFile> _masterList = [];
  List<PlatformFile> _playlist = [];
  List<PlatformFile> _favorites = [];
  List<PlatformFile> _recent = [];
  int _currentIndex = 0;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _searchQuery = '';
  
  Timer? _sleepTimer;
  bool _sleepTimerActive = false;
  int _sleepTimerMinutes = 0;

  Map<String, List<PlatformFile>> _customPlaylists = {};
  String _newPlaylistName = '';

  // Equalizer
  bool _isEqActive = false;
  String _currentEqPreset = 'Normal';
  final List<String> _bandLabels = ['Bass', 'Mid', 'Treble'];
  final Map<String, List<double>> _eqPresets = {
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
  List<double> _currentEqValues = [0, 0, 0];
  double _baseVolume = 1.0;

  // ============================================================
  // THEME COLORS
  // ============================================================
  final Color _bgColor = const Color(0xFF0A0A0F);
  final Color _cardColor = const Color(0xFF16161E);
  final Color _accentColor = const Color(0xFF6C63FF);
  final Color _textSecondary = const Color(0xFF8888AA);
  
  final List<Color> _primaryGradient = [
    const Color(0xFF6C63FF),
    const Color(0xFF3F3D9E),
  ];
  
  final List<Color> _secondaryGradient = [
    const Color(0xFF4ECDC4),
    const Color(0xFF2C7A78),
  ];

  // ============================================================
  // ALBUM GRADIENTS
  // ============================================================
  final List<List<Color>> _albumGradients = [
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

  List<Color> _getSongGradient(int index) {
    return _albumGradients[index % _albumGradients.length];
  }

  String _formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  return '$minutes:$seconds';
  }

  // ============================================================
  // 🔥 LIFECYCLE METHODS
  // ============================================================
  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addObserver(this);
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadSavedData();
    _initAudioService();
    _listenToAudioStreams();
    
    Future.delayed(const Duration(milliseconds: 800), () {
      print('🔊 Audio service ready check');
      if (audioHandler is MyAudioHandler) {
        print('✅ Audio handler is ready');
      } else {
        print('⚠️ Audio handler not ready yet');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveData();
    _pulseController.dispose();
    _sleepTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // APP LIFECYCLE HANDLING
  // ============================================================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('📱 App lifecycle changed: $state');
    
    if (state == AppLifecycleState.resumed) {
      _syncPlayerState();
    }
    
    if (state == AppLifecycleState.paused) {
      print('📱 App went to background');
      _saveData();
    }
  }

  Future<void> _syncPlayerState() async {
    print('🔄 Syncing player state...');
    if (audioHandler is MyAudioHandler) {
      final handler = audioHandler as MyAudioHandler;
      setState(() {
        isPlaying = handler.isPlaying;
      });
    }
  }

  // ============================================================
  // AUDIO SERVICE INITIALIZATION
  // ============================================================
  Future<void> _initAudioService() async {
    try {
      print('🔊 Initializing audio service...');
      audioHandler = await initAudioService();
      print('✅ Audio service initialized successfully');
    } catch (e) {
      print('❌ Audio service error: $e');
    }
  }

  // ============================================================
  // LISTEN TO AUDIO STREAMS
  // ============================================================
  void _listenToAudioStreams() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (audioHandler is MyAudioHandler) {
        final handler = audioHandler as MyAudioHandler;
        
        handler.durationStream.listen((duration) {
          if (mounted && duration != null) {
            setState(() => _duration = duration);
            print('⏱️ Duration: $duration');
          }
        });
        
        handler.positionStream.listen((position) {
          if (mounted) {
            setState(() => _position = position);
            print('📍 Position: $position');
          }
        });
        
        handler.playbackState.listen((state) {
          if (mounted) {
            setState(() => isPlaying = state.playing);
            print('🎵 Playing: ${state.playing}');
          }
        });
        
        print('✅ Audio streams connected');
      } else {
        Future.delayed(const Duration(milliseconds: 500), _listenToAudioStreams);
      }
    });
  }

  // ============================================================
  // EQUALIZER FUNCTIONS - (Add your existing equalizer code here)
  // ============================================================
  // ... equalizer functions ...

  // ============================================================
  // DATA PERSISTENCE
  // ============================================================
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // ... save data ...
    } catch (e) {
      print('❌ Error saving data: $e');
    }
  }

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // ... load data ...
    } catch (e) {
      print('❌ Error loading data: $e');
    }
  }

  // ============================================================
  // AUDIO PLAYBACK
  // ============================================================
  Future<void> _pickSongs() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _masterList.addAll(result.files);
          if (_playlist.isEmpty) {
            _playlist.addAll(result.files);
            _currentIndex = 0;
          }
        });
        _saveData();
        if (_playlist.isNotEmpty && !isPlaying) {
          await _playCurrentSongInQueue();
        }
      }
    } catch (e) {
      print('❌ Error picking songs: $e');
    }
  }

  Future<void> _playCurrentSongInQueue() async {
  if (_playlist.isEmpty) {
    print('⚠️ Playlist is empty');
    return;
  }
  
  try {
    final currentFile = _playlist[_currentIndex];
    String cleanName = _cleanSongName(currentFile.name);
    print('🎵 Playing: $cleanName');
    print('📁 Path: ${currentFile.path}');
    
    if (currentFile.path == null) {
      print('❌ Path is null');
      return;
    }
    
    // 🔥 FILE CHECK
    final file = File(currentFile.path!);
    if (!await file.exists()) {
      print('❌ File not found: ${currentFile.path}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ File not found: ${file.path.split('/').last}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    print('✅ File exists: ${file.lengthSync()} bytes');

    // 🔥 UPDATE RECENT
    if (!_recent.contains(currentFile)) {
      _recent.insert(0, currentFile);
      if (_recent.length > 50) _recent.removeLast();
      _saveData();
    }

    // 🔥 INIT AUDIO SERVICE
    if (audioHandler == null) {
      print('⚠️ audioHandler is null, initializing...');
      await _initAudioService();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (audioHandler is MyAudioHandler) {
      print('✅ audioHandler is MyAudioHandler');
      
      final handler = audioHandler as MyAudioHandler;
      
      // 🔥 PLAY SONG
      await handler.playSong(
        currentFile.path!,
        cleanName,
        'Luna Echo',
      );
      
      await Future.delayed(const Duration(milliseconds: 1000));
      
      if (mounted) {
        setState(() {
          isPlaying = true;
        });
        _saveData();
        print('✅ Song playing: $cleanName');
        
        // 🔥 SHOW SUCCESS
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('▶️ Playing: $cleanName'),
            backgroundColor: Colors.green.withOpacity(0.7),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      print('❌ audioHandler is not MyAudioHandler');
    }
  } catch (e) {
    print('❌ Error playing song: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Error: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  }

  Future<void> _playNextSong() async {
    if (_playlist.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _playlist.length;
    });
    _saveData();
    await _playCurrentSongInQueue();
  }

  Future<void> _playPreviousSong() async {
    if (_playlist.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    });
    _saveData();
    await _playCurrentSongInQueue();
  }

  Future<void> _togglePlayPause() async {
    if (_playlist.isEmpty) {
      await _pickSongs();
      return;
    }
    
    if (audioHandler == null) {
      await _initAudioService();
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    if (isPlaying) {
      await audioHandler?.pause();
      setState(() => isPlaying = false);
    } else {
      await audioHandler?.play();
      setState(() => isPlaying = true);
    }
    _saveData();
  }

  // ============================================================
  // BUILD METHOD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('My Music Player', style: TextStyle(color: Colors.white, fontSize: 24)),
            const SizedBox(height: 20),
            Text(_playlist.isNotEmpty ? _cleanSongName(_playlist[_currentIndex].name) : 'No song', 
              style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: Colors.white, size: 30),
                  onPressed: _playlist.isNotEmpty ? _playPreviousSong : null,
                ),
                IconButton(
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 40),
                  onPressed: _togglePlayPause,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, color: Colors.white, size: 30),
                  onPressed: _playlist.isNotEmpty ? _playNextSong : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(_formatDuration(_position), style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickSongs,
              style: ElevatedButton.styleFrom(backgroundColor: _accentColor),
              child: const Text('Add Songs', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: _cardColor,
        selectedItemColor: _accentColor,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.play_circle_filled), label: 'Player'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Recent'),
          BottomNavigationBarItem(icon: Icon(Icons.playlist_play), label: 'Playlists'),
        ],
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
