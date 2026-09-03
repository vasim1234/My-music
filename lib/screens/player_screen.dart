import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
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

  // ============================================================
  // 🔥 HELPER FUNCTIONS - SIRF EK BAAR
  // ============================================================
  String _cleanSongName(String fileName) {
    String name = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    name = name.replaceAll(RegExp(r'\(\w*_\d+K\)', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\(\d+K\)', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\(MP3_\d+K\)', caseSensitive: false), '');
    name = name.trim();
    if (name.length > 35) {
      name = '${name.substring(0, 35)}...';
    }
    return name;
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
  // EQUALIZER FUNCTIONS
  // ============================================================
  Future<void> _applyEqualizer() async {
    if (!_isEqActive) {
      if (audioHandler is MyAudioHandler) {
        await (audioHandler as MyAudioHandler).setVolume(_baseVolume);
      }
      return;
    }
    
    double bass = _currentEqValues[0];
    double mid = _currentEqValues[1];
    double treble = _currentEqValues[2];
    
    double volumeEffect = 1.0 + (bass + mid + treble) * 0.015;
    double newVolume = (_baseVolume * volumeEffect).clamp(0.0, 1.0);
    
    if (audioHandler is MyAudioHandler) {
      await (audioHandler as MyAudioHandler).setVolume(newVolume);
    }
  }

  Future<void> _resetEqualizer() async {
    setState(() {
      _currentEqPreset = 'Normal';
      _currentEqValues = [0, 0, 0];
      _isEqActive = false;
    });
    await _applyEqualizer();
    _saveData();
  }

  Future<void> _applyPreset(String presetName) async {
    setState(() {
      _currentEqPreset = presetName;
      _currentEqValues = List.from(_eqPresets[presetName]!);
      _isEqActive = presetName != 'Normal';
    });
    await _applyEqualizer();
    _saveData();
  }

  void _showEqualizerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bgColor,
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
                              gradient: LinearGradient(colors: _primaryGradient),
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
                            onPressed: () { _resetEqualizer(); setModalState(() {}); },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  const Text('PRESETS', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _eqPresets.keys.map((preset) {
                      bool isSelected = _currentEqPreset == preset;
                      return FilterChip(
                        label: Text(preset, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 11)),
                        selected: isSelected,
                        selectedColor: _accentColor.withOpacity(0.3),
                        backgroundColor: _cardColor,
                        side: BorderSide(color: isSelected ? _accentColor : Colors.grey.shade700, width: 1.5),
                        onSelected: (selected) {
                          if (selected) { _applyPreset(preset); setModalState(() {}); }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const Text('3 BAND EQUALIZER', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: 3,
                      itemBuilder: (context, index) {
                        return _buildEqSlider(
                          label: _bandLabels[index],
                          index: index,
                          value: _currentEqValues[index],
                          onChanged: (value) {
                            setState(() {
                              _currentEqValues[index] = value;
                              _currentEqPreset = 'Custom';
                              _isEqActive = true;
                            });
                            setModalState(() {});
                            _applyEqualizer();
                            _saveData();
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Enable Equalizer', style: TextStyle(color: Colors.white, fontSize: 14)),
                      Switch(
                        value: _isEqActive,
                        activeColor: _accentColor,
                        activeTrackColor: _accentColor.withOpacity(0.3),
                        onChanged: (value) async {
                          setState(() {
                            _isEqActive = value;
                            if (!value) {
                              _currentEqValues = [0, 0, 0];
                              _currentEqPreset = 'Normal';
                            }
                          });
                          await _applyEqualizer();
                          _saveData();
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEqSlider({
    required String label,
    required int index,
    required double value,
    required Function(double) onChanged,
  }) {
    List<Color> colors = [Colors.red, Colors.green, Colors.blue];
    Color color = colors[index % colors.length];
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value > 0 ? '+${value.toInt()}' : '${value.toInt()}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: -10,
          max: 10,
          activeColor: color,
          inactiveColor: Colors.grey.shade800,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ============================================================
  // DATA PERSISTENCE
  // ============================================================
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      List<String> masterPaths = _masterList.map((f) => f.path ?? '').toList();
      await prefs.setStringList('masterList', masterPaths);
      
      List<String> playlistPaths = _playlist.map((f) => f.path ?? '').toList();
      await prefs.setStringList('playlist', playlistPaths);
      
      List<String> favoritePaths = _favorites.map((f) => f.path ?? '').toList();
      await prefs.setStringList('favorites', favoritePaths);
      
      List<String> recentPaths = _recent.map((f) => f.path ?? '').toList();
      await prefs.setStringList('recent', recentPaths);
      
      await prefs.setInt('currentIndex', _currentIndex);
      await prefs.setString('eqPreset', _currentEqPreset);
      await prefs.setBool('eqActive', _isEqActive);
      await prefs.setStringList('eqValues', _currentEqValues.map((v) => v.toString()).toList());
      await prefs.setDouble('volume', _volume);
      await prefs.setBool('is3DMode', is3DMode);
      await prefs.setBool('isShuffle', isShuffle);
      await prefs.setInt('repeatMode', repeatMode);
      
      Map<String, List<String>> playlistMap = {};
      _customPlaylists.forEach((key, value) {
        playlistMap[key] = value.map((f) => f.path ?? '').toList();
      });
      await prefs.setString('customPlaylists', jsonEncode(playlistMap));
      
    } catch (e) {
      print('❌ Error saving data: $e');
    }
  }

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      List<String>? masterPaths = prefs.getStringList('masterList');
      if (masterPaths != null && masterPaths.isNotEmpty) {
        _masterList = masterPaths
            .where((path) => File(path).existsSync())
            .map((path) => PlatformFile(
                  name: path.split('/').last,
                  path: path,
                  size: 0,
                ))
            .toList();
      }
      
      List<String>? playlistPaths = prefs.getStringList('playlist');
      if (playlistPaths != null && playlistPaths.isNotEmpty) {
        _playlist = playlistPaths
            .where((path) => File(path).existsSync())
            .map((path) => PlatformFile(
                  name: path.split('/').last,
                  path: path,
                  size: 0,
                ))
            .toList();
      }
      
      List<String>? favoritePaths = prefs.getStringList('favorites');
      if (favoritePaths != null && favoritePaths.isNotEmpty) {
        _favorites = favoritePaths
            .where((path) => File(path).existsSync())
            .map((path) => PlatformFile(
                  name: path.split('/').last,
                  path: path,
                  size: 0,
                ))
            .toList();
      }
      
      List<String>? recentPaths = prefs.getStringList('recent');
      if (recentPaths != null && recentPaths.isNotEmpty) {
        _recent = recentPaths
            .where((path) => File(path).existsSync())
            .map((path) => PlatformFile(
                  name: path.split('/').last,
                  path: path,
                  size: 0,
                ))
            .toList();
      }
      
      _currentIndex = prefs.getInt('currentIndex') ?? 0;
      if (_currentIndex >= _playlist.length) {
        _currentIndex = _playlist.isNotEmpty ? _playlist.length - 1 : 0;
      }
      
      _currentEqPreset = prefs.getString('eqPreset') ?? 'Normal';
      _isEqActive = prefs.getBool('eqActive') ?? false;
      
      List<String>? eqValues = prefs.getStringList('eqValues');
      if (eqValues != null && eqValues.length == 3) {
        _currentEqValues = eqValues.map((v) => double.tryParse(v) ?? 0).toList();
      }
      
      _volume = prefs.getDouble('volume') ?? 1.0;
      _baseVolume = _volume;
      is3DMode = prefs.getBool('is3DMode') ?? false;
      isShuffle = prefs.getBool('isShuffle') ?? false;
      repeatMode = prefs.getInt('repeatMode') ?? 0;
      
      String? playlistJson = prefs.getString('customPlaylists');
      if (playlistJson != null) {
        Map<String, dynamic> decoded = jsonDecode(playlistJson);
        decoded.forEach((key, value) {
          List<String> paths = List<String>.from(value);
          _customPlaylists[key] = paths
              .where((path) => File(path).existsSync())
              .map((path) => PlatformFile(
                    name: path.split('/').last,
                    path: path,
                    size: 0,
                  ))
              .toList();
        });
      }
      
      if (_masterList.isEmpty && _playlist.isNotEmpty) {
        _masterList = List.from(_playlist);
      }
      
      setState(() {});
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.files.length} songs added'),
              backgroundColor: _accentColor.withOpacity(0.3),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Color(0xFFFF6B6B)),
        );
      }
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
          content: Text('❌ File not found'),
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
      
      // 🔥 UPDATE UI
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        setState(() {
          isPlaying = true;
        });
        _saveData();
        print('✅ Song playing: $cleanName');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('▶️ $cleanName'),
            backgroundColor: Colors.green.withOpacity(0.7),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      print('❌ audioHandler is not MyAudioHandler');
      print('🔍 Type: ${audioHandler.runtimeType}');
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
    print('⚠️ No songs in playlist');
    await _pickSongs();
    return;
  }
  
  try {
    if (audioHandler == null) {
      print('⚠️ audioHandler is null, initializing...');
      await _initAudioService();
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    print('🔄 Toggle play/pause, isPlaying: $isPlaying');
    
    if (isPlaying) {
      print('⏸️ Pausing...');
      await audioHandler?.pause();
      setState(() {
        isPlaying = false;
      });
    } else {
      print('▶️ Playing...');
      // 🔥 If no song is loaded, play current
      if (_playlist.isNotEmpty && audioHandler is MyAudioHandler) {
        final handler = audioHandler as MyAudioHandler;
        if (handler.currentSong == null) {
          await _playCurrentSongInQueue();
        } else {
          await audioHandler?.play();
        }
      } else {
        await _playCurrentSongInQueue();
      }
      setState(() {
        isPlaying = true;
      });
    }
    _saveData();
  } catch (e) {
    print('❌ Error toggling play/pause: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Error: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  }
 
  void _toggleFavorite(PlatformFile song) {
    setState(() {
      if (_favorites.contains(song)) {
        _favorites.remove(song);
      } else {
        _favorites.add(song);
      }
    });
    _saveData();
  }

  // ============================================================
  // SHUFFLE/REPEAT MENU
  // ============================================================
  void _showShuffleRepeatMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bgColor,
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
                      gradient: LinearGradient(colors: _primaryGradient),
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
                isActive: isShuffle,
                onTap: () {
                  setState(() { isShuffle = true; repeatMode = 0; });
                  _saveData();
                  Navigator.pop(context);
                },
              ),
              const Divider(color: Colors.white24),
              _buildMenuOption(
                icon: Icons.repeat_outlined,
                title: 'Repeat Off',
                subtitle: 'Stop after current song',
                isActive: repeatMode == 0 && !isShuffle,
                onTap: () {
                  setState(() { isShuffle = false; repeatMode = 0; });
                  _saveData();
                  Navigator.pop(context);
                },
              ),
              const Divider(color: Colors.white24),
              _buildMenuOption(
                icon: Icons.repeat_one,
                title: 'Repeat One',
                subtitle: 'Repeat current song',
                isActive: repeatMode == 1,
                onTap: () {
                  setState(() { isShuffle = false; repeatMode = 1; });
                  _saveData();
                  Navigator.pop(context);
                },
              ),
              const Divider(color: Colors.white24),
              _buildMenuOption(
                icon: Icons.repeat,
                title: 'Repeat All',
                subtitle: 'Repeat entire queue',
                isActive: repeatMode == 2,
                onTap: () {
                  setState(() { isShuffle = false; repeatMode = 2; });
                  _saveData();
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
                gradient: isActive ? LinearGradient(colors: _primaryGradient) : null,
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
                  Text(title, style: TextStyle(color: isActive ? _accentColor : Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            if (isActive) Icon(Icons.check_circle, color: _accentColor, size: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BODY CONTENT
  // ============================================================
  Widget _buildBodyContent() {
    if (_selectedIndex == 1) {
      return _buildFavoritesTab();
    } else if (_selectedIndex == 2) {
      return _buildRecentTab();
    } else if (_selectedIndex == 3) {
      return _buildPlaylistsTab();
    }
    return _buildPlayerUI();
  }

  // ============================================================
  // FAVORITES TAB
  // ============================================================
  Widget _buildFavoritesTab() {
    if (_favorites.isEmpty) {
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
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final song = _favorites[index];
        String cleanName = _cleanSongName(song.name);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _getSongGradient(index)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(cleanName.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            title: Text(cleanName, style: const TextStyle(color: Colors.white, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _playSpecificSong(song),
          ),
        );
      },
    );
  }

  // ============================================================
  // RECENT TAB
  // ============================================================
  Widget _buildRecentTab() {
    if (_recent.isEmpty) {
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
      itemCount: _recent.length,
      itemBuilder: (context, index) {
        final song = _recent[index];
        String cleanName = _cleanSongName(song.name);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _getSongGradient(index)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(cleanName.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            title: Text(cleanName, style: const TextStyle(color: Colors.white, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _playSpecificSong(song),
          ),
        );
      },
    );
  }

  // ============================================================
  // PLAYLISTS TAB
  // ============================================================
  Widget _buildPlaylistsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_play, size: 64, color: Colors.white24),
          SizedBox(height: 16),
          Text('Playlists feature coming soon', style: TextStyle(color: Colors.white54, fontSize: 16)),
        ],
      ),
    );
  }

  // ============================================================
  // PLAYER UI
  // ============================================================
  Widget _buildPlayerUI() {
    String currentSongName = _playlist.isNotEmpty ? _cleanSongName(_playlist[_currentIndex].name) : "No song playing";
    bool hasSongs = _playlist.isNotEmpty;
    List<Color> currentGradient = hasSongs ? _getSongGradient(_currentIndex) : _primaryGradient;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              currentSongName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              "Luna Echo",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            AlbumArt(
              isPlaying: isPlaying,
              is3DMode: is3DMode,
              songName: currentSongName,
              songPath: _playlist.isNotEmpty ? _playlist[_currentIndex].path : null,
              gradient: currentGradient,
              isSleepTimerActive: _sleepTimerActive,
              animation: _pulseAnimation,
              accentColor: _accentColor,
            ),     
            const SizedBox(height: 20),
            Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    activeTrackColor: _accentColor,
                    inactiveTrackColor: Colors.grey.shade800,
                    thumbColor: _accentColor,
                  ),
                  child: Slider(
                    min: 0.0,
                    max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                    value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0),
                    onChanged: (value) async {
                      final position = Duration(seconds: value.toInt());
                      await audioHandler?.seek(position);
                      setState(() => _position = position);
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_position), style: TextStyle(color: _textSecondary, fontSize: 11)),
                    Text(_formatDuration(_duration), style: TextStyle(color: _textSecondary, fontSize: 11)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: Colors.white, size: 24),
                  onPressed: hasSongs ? _playPreviousSong : null,
                ),
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: currentGradient),
                    boxShadow: [
                      BoxShadow(color: _accentColor.withOpacity(0.35), blurRadius: 15, spreadRadius: 3),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                    iconSize: 30,
                    onPressed: _togglePlayPause,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.skip_next, color: Colors.white, size: 24),
                  onPressed: hasSongs ? _playNextSong : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD METHOD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 ? 'My Music' : 
          _selectedIndex == 1 ? 'Favorites' : 
          _selectedIndex == 2 ? 'Recent' : 'Playlists',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white70),
              onPressed: _pickSongs,
            ),
        ],
      ),
      body: _buildBodyContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: _cardColor,
        selectedItemColor: _accentColor,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        onTap: (index) {
          setState(() => _selectedIndex = index);
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

  // ============================================================
  // ADDITIONAL METHODS
  // ============================================================
  Future<void> _playSpecificSong(PlatformFile song, {List<PlatformFile>? playlist}) async {
    print('🎵 _playSpecificSong called');
    print('🎵 Song: ${song.name}');
    
    if (playlist != null && playlist.isNotEmpty) {
      setState(() {
        _playlist = List.from(playlist);
        _currentIndex = _playlist.indexOf(song);
        if (_currentIndex == -1) _currentIndex = 0;
      });
    } else {
      int index = _playlist.indexOf(song);
      if (index != -1) {
        setState(() => _currentIndex = index);
      } else {
        setState(() {
          _playlist.add(song);
          _currentIndex = _playlist.length - 1;
        });
      }
    }
    _saveData();
    await _playCurrentSongInQueue();
    print('✅ _playSpecificSong completed');
  }

  void _handleSongCompletion() {
    if (repeatMode == 1) {
      _playCurrentSongInQueue();
    } else if (repeatMode == 2) {
      _playNextSong();
    } else {
      if (_currentIndex < _playlist.length - 1) {
        _playNextSong();
      } else {
        if (mounted) setState(() => isPlaying = false);
      }
    }
  }

  void _showQueueBottomSheet() {
    // Queue bottom sheet
  }

  void _showVolumePopup(BuildContext context) {
    // Volume popup
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required double size,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? activeColor.withOpacity(0.15) : _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isActive ? activeColor : Colors.grey.shade800, width: 1),
            ),
            child: Icon(icon, color: isActive ? activeColor : Colors.white54, size: size),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: isActive ? activeColor : _textSecondary, fontSize: 9, fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }
}
