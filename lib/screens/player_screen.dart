import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  bool is3DMode = false;
  bool isShuffle = false;
  int repeatMode = 0;
  
  List<PlatformFile> _playlist = [];
  List<PlatformFile> _favorites = [];
  List<PlatformFile> _recent = [];
  int _currentIndex = 0;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Search
  String _searchQuery = '';
  
  // Sleep Timer
  Timer? _sleepTimer;
  bool _sleepTimerActive = false;
  int _sleepTimerMinutes = 0;

  // Custom Playlists
  Map<String, List<PlatformFile>> _customPlaylists = {};
  String _newPlaylistName = '';

  // Equalizer
  String _currentEqPreset = 'Normal';
  bool _isEqActive = false;
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
  // NEW THEME COLORS - 3D Headphone Style
  // ============================================================
  final Color _bgColor = const Color(0xFF000000); // Pure Black
  final Color _cardColor = const Color(0xFF1A1A1A); // Dark Grey
  
  // Gradient 1: Blue → Teal (Primary)
  final List<Color> _primaryGradient = [
    const Color(0xFF2196F3), // Blue
    const Color(0xFF00BCD4), // Teal
  ];
  
  // Gradient 2: Green → Yellow-Green (Secondary)
  final List<Color> _secondaryGradient = [
    const Color(0xFF4CAF50), // Green
    const Color(0xFF8BC34A), // Light Green
  ];
  
  // Neon Glow Color
  final Color _neonColor = const Color(0xFF00E5FF);
  
  // Combined Gradient for Album Art
  final List<List<Color>> _albumGradients = [
    [Color(0xFF2196F3), Color(0xFF00BCD4)], // Blue→Teal
    [Color(0xFF4CAF50), Color(0xFF8BC34A)], // Green→Yellow
    [Color(0xFF00BCD4), Color(0xFF009688)], // Teal→Green
    [Color(0xFF2196F3), Color(0xFF4CAF50)], // Blue→Green
    [Color(0xFF00E5FF), Color(0xFF00BCD4)], // Neon→Teal
    [Color(0xFF4CAF50), Color(0xFFFFEB3B)], // Green→Yellow
    [Color(0xFF00BCD4), Color(0xFF2196F3)], // Teal→Blue
    [Color(0xFF8BC34A), Color(0xFF4CAF50)], // LightGreen→Green
    [Color(0xFF009688), Color(0xFF00BCD4)], // Teal Dark→Teal
    [Color(0xFF00E5FF), Color(0xFF2196F3)], // Neon→Blue
    [Color(0xFF4CAF50), Color(0xFF009688)], // Green→Teal
    [Color(0xFF2196F3), Color(0xFF00E5FF)], // Blue→Neon
  ];

  List<Color> _getSongGradient(int index) {
    return _albumGradients[index % _albumGradients.length];
  }

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

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadSavedData();

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });
    
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
    
    _audioPlayer.onPlayerComplete.listen((_) {
      _handleSongCompletion();
    });
  }

  @override
  void dispose() {
    _saveData();
    _pulseController.dispose();
    _audioPlayer.dispose();
    _sleepTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // DATA PERSISTENCE
  // ============================================================
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
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
      debugPrint('❌ Error saving data: $e');
    }
  }

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
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
      
      if (_playlist.isNotEmpty && _currentIndex < _playlist.length) {
        _playCurrentSongInQueue();
      }
      
      setState(() {});
    } catch (e) {
      debugPrint('❌ Error loading data: $e');
    }
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

  // ===== EQUALIZER =====
  Future<void> _applyEqualizer() async {
    if (!_isEqActive) {
      await _audioPlayer.setBalance(0.0);
      await _audioPlayer.setVolume(_baseVolume);
      return;
    }
    
    double bass = _currentEqValues[0];
    double mid = _currentEqValues[1];
    double treble = _currentEqValues[2];
    
    double balanceEffect = (treble - bass) * 0.04;
    double volumeEffect = 1.0 + (bass + mid + treble) * 0.015;
    
    await _audioPlayer.setBalance(balanceEffect.clamp(-1.0, 1.0));
    await _audioPlayer.setVolume((_baseVolume * volumeEffect).clamp(0.0, 1.0));
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
              padding: const EdgeInsets.all(24),
              height: MediaQuery.of(context).size.height * 0.75,
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
                            child: const Icon(Icons.equalizer, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text('Equalizer', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
                  const Divider(color: Colors.white24, height: 20),
                  const Text('PRESETS', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _eqPresets.keys.map((preset) {
                      bool isSelected = _currentEqPreset == preset;
                      return FilterChip(
                        label: Text(preset, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 11)),
                        selected: isSelected,
                        selectedColor: _neonColor.withOpacity(0.2),
                        backgroundColor: _cardColor,
                        side: BorderSide(color: isSelected ? _neonColor : Colors.grey.shade700, width: 1.5),
                        onSelected: (selected) {
                          if (selected) { _applyPreset(preset); setModalState(() {}); }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const Text('FREQUENCY BANDS', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: 3,
                      itemBuilder: (context, index) {
                        return _buildEqSlider(
                          label: _bandLabels[index],
                          index: index,
                          value: _currentEqValues[index],
                          color: _getSliderColor(index),
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
                        activeColor: _neonColor,
                        activeTrackColor: _neonColor.withOpacity(0.3),
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

  Color _getSliderColor(int index) {
    final colors = [
      const Color(0xFF2196F3), // Blue
      const Color(0xFF4CAF50), // Green
      const Color(0xFF00BCD4), // Teal
    ];
    return colors[index % colors.length];
  }

  Widget _buildEqSlider({
    required String label,
    required int index,
    required double value,
    required Color color,
    required Function(double) onChanged,
  }) {
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
  // PLAYLIST FUNCTIONS
  // ============================================================
  void _createPlaylist(String name) {
    if (name.trim().isEmpty) return;
    setState(() {
      _customPlaylists[name.trim()] = [];
      _newPlaylistName = '';
    });
    _saveData();
  }

  void _deletePlaylist(String name) {
    setState(() {
      _customPlaylists.remove(name);
    });
    _saveData();
  }

  void _addSongToPlaylist(String playlistName, PlatformFile song) {
    setState(() {
      if (_customPlaylists.containsKey(playlistName)) {
        if (!_customPlaylists[playlistName]!.contains(song)) {
          _customPlaylists[playlistName]!.add(song);
        }
      }
    });
    _saveData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Added to $playlistName'),
        backgroundColor: _neonColor.withOpacity(0.3),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _removeFromPlaylist(String playlistName, PlatformFile song) {
    setState(() {
      if (_customPlaylists.containsKey(playlistName)) {
        _customPlaylists[playlistName]!.remove(song);
      }
    });
    _saveData();
  }

  void _showCreatePlaylistDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: const TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _neonColor.withOpacity(0.3)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _neonColor),
            ),
          ),
          onChanged: (value) => _newPlaylistName = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              _createPlaylist(_newPlaylistName);
              Navigator.pop(context);
            },
            child: Text('Create', style: TextStyle(color: _neonColor)),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistDialog(String playlistName) {
    List<PlatformFile> availableSongs = _playlist.where((song) =>
      !_customPlaylists[playlistName]!.contains(song)
    ).toList();

    if (availableSongs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No songs available to add'),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }

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
              height: MediaQuery.of(context).size.height * 0.6,
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
                              gradient: LinearGradient(colors: _secondaryGradient),
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
                  Expanded(
                    child: ListView.builder(
                      itemCount: availableSongs.length,
                      itemBuilder: (context, index) {
                        final song = availableSongs[index];
                        String cleanName = _cleanSongName(song.name);
                        List<Color> gradient = _getSongGradient(index);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(12),
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
                                  cleanName.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            title: Text(
                              cleanName,
                              style: const TextStyle(color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: _primaryGradient),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 18),
                            ),
                            onTap: () {
                              _addSongToPlaylist(playlistName, song);
                              setModalState(() {
                                availableSongs.remove(song);
                              });
                              if (availableSongs.isEmpty) {
                                Navigator.pop(context);
                              }
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

  // ===== QUEUE MANAGEMENT =====
  void _clearQueue() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
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
              setState(() {
                _playlist.clear();
                _currentIndex = 0;
                isPlaying = false;
                _position = Duration.zero;
                _duration = Duration.zero;
              });
              _audioPlayer.stop();
              _saveData();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
  }

  // ===== SHOW QUEUE =====
  void _showQueueBottomSheet() {
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
              height: MediaQuery.of(context).size.height * 0.6,
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
                            child: const Icon(Icons.queue_music, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text('Queue', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: _primaryGradient),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_playlist.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
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
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search in queue...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _neonColor.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _neonColor),
                      ),
                    ),
                    onChanged: (value) => setModalState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _playlist.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.queue_music, size: 50, color: Colors.white24),
                                SizedBox(height: 10),
                                Text('Queue is empty', style: TextStyle(color: Colors.white54)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _getFilteredSongs().length,
                            itemBuilder: (context, index) {
                              final song = _getFilteredSongs()[index];
                              final originalIndex = _playlist.indexOf(song);
                              bool isCurrent = originalIndex == _currentIndex;
                              String cleanName = _cleanSongName(song.name);
                              List<Color> gradient = _getSongGradient(originalIndex);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: isCurrent ? _neonColor.withOpacity(0.1) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isCurrent ? Border.all(color: _neonColor.withOpacity(0.3), width: 1) : null,
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isCurrent ? _primaryGradient : gradient,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${originalIndex + 1}',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    cleanName,
                                    style: TextStyle(
                                      color: isCurrent ? _neonColor : Colors.white,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_favorites.contains(song))
                                        const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                                      const SizedBox(width: 4),
                                      if (isCurrent)
                                        Icon(Icons.play_arrow, color: _neonColor),
                                    ],
                                  ),
                                  onTap: () {
                                    setState(() => _currentIndex = originalIndex);
                                    _playCurrentSongInQueue();
                                    _saveData();
                                    Navigator.pop(context);
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

  // ============================================================
  // SLEEP TIMER
  // ============================================================
  void _startSleepTimer(int minutes) {
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
        _audioPlayer.stop();
        setState(() => isPlaying = false);
        _saveData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏰ Sleep timer stopped'),
            backgroundColor: Color(0xFFFF9F43),
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
    _saveData();
  }

  void _showSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sleep Timer', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTimerOption(15),
            _buildTimerOption(30),
            _buildTimerOption(60),
            _buildTimerOption(90),
            if (_sleepTimerActive)
              ListTile(
                leading: const Icon(Icons.stop, color: Color(0xFFFF6B6B)),
                title: const Text('Cancel Timer', style: TextStyle(color: Colors.white)),
                onTap: () {
                  _cancelSleepTimer();
                  Navigator.pop(context);
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerOption(int minutes) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _primaryGradient),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.timer, color: Colors.white, size: 18),
      ),
      title: Text('$minutes minutes', style: const TextStyle(color: Colors.white)),
      trailing: _sleepTimerActive && _sleepTimerMinutes == minutes
          ? Icon(Icons.check_circle, color: _neonColor)
          : null,
      onTap: () {
        _startSleepTimer(minutes);
        Navigator.pop(context);
      },
    );
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
          _playlist.addAll(result.files);
          if (_playlist.length == result.files.length) {
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
              backgroundColor: _neonColor.withOpacity(0.3),
              duration: const Duration(seconds: 1),
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
    if (_playlist.isEmpty) return;
    
    try {
      final currentFile = _playlist[_currentIndex];
      
      if (!_recent.contains(currentFile)) {
        _recent.insert(0, currentFile);
        if (_recent.length > 50) _recent.removeLast();
        _saveData();
      }

      if (currentFile.path != null) {
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(currentFile.path!));
        _baseVolume = _volume;
        await _audioPlayer.setVolume(_volume);
        await _audioPlayer.setBalance(is3DMode ? 0.5 : 0.0);
        await _applyEqualizer();
        if (mounted) {
          setState(() => isPlaying = true);
          _saveData();
        }
      }
    } catch (e) {
      debugPrint('Error playing song: $e');
    }
  }

  Future<void> _playSpecificSong(PlatformFile song) async {
    int index = _playlist.indexOf(song);
    if (index != -1) {
      setState(() => _currentIndex = index);
    } else {
      setState(() {
        _playlist.add(song);
        _currentIndex = _playlist.length - 1;
      });
    }
    _saveData();
    await _playCurrentSongInQueue();
  }

  Future<void> _playNextSong() async {
    if (_playlist.isEmpty) return;
    
    if (isShuffle && _playlist.length > 1) {
      int newIndex;
      do {
        newIndex = DateTime.now().millisecondsSinceEpoch % _playlist.length;
      } while (newIndex == _currentIndex);
      setState(() => _currentIndex = newIndex);
    } else {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _playlist.length;
      });
    }
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
    
    try {
      if (isPlaying) {
        await _audioPlayer.pause();
        if (mounted) setState(() => isPlaying = false);
        _saveData();
      } else {
        if (_position == Duration.zero && _duration == Duration.zero) {
          await _playCurrentSongInQueue();
        } else {
          await _audioPlayer.resume();
          if (mounted) setState(() => isPlaying = true);
          _saveData();
        }
      }
    } catch (e) {
      debugPrint('Error toggling play/pause: $e');
      await _playCurrentSongInQueue();
    }
  }

  Future<void> _seekRelative(int seconds) async {
    final newPosition = _position + Duration(seconds: seconds);
    final clampedPosition = newPosition > _duration 
        ? _duration 
        : (newPosition < Duration.zero ? Duration.zero : newPosition);
    await _audioPlayer.seek(clampedPosition);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final hours = duration.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
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
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 250,
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
              child: Icon(
                icon,
                color: isActive ? Colors.white : Colors.white54,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isActive ? _neonColor : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isActive)
              Icon(Icons.check_circle, color: _neonColor, size: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // UI HELPERS
  // ============================================================
  List<PlatformFile> _getFilteredSongs() {
    if (_searchQuery.isEmpty) return _playlist;
    return _playlist.where((song) =>
      _cleanSongName(song.name).toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
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

  // ===== FAVORITES TAB =====
  Widget _buildFavoritesTab() {
    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('No favorites yet', style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Tap ♡ on any song', style: TextStyle(color: Colors.white24, fontSize: 13)),
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
        List<Color> gradient = _getSongGradient(index);
        return _buildSongTile(
          title: cleanName,
          subtitle: '${index + 1}',
          gradient: gradient,
          trailing: IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            onPressed: () {
              setState(() => _favorites.remove(song));
              _saveData();
            },
          ),
          onTap: () => _playSpecificSong(song),
        );
      },
    );
  }

  // ===== RECENT TAB =====
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
        List<Color> gradient = _getSongGradient(index);
        return _buildSongTile(
          title: cleanName,
          subtitle: 'Recently played',
          gradient: gradient,
          trailing: Text('${index + 1}', style: const TextStyle(color: Colors.white24, fontSize: 12)),
          onTap: () => _playSpecificSong(song),
        );
      },
    );
  }

  // ===== PLAYLISTS TAB =====
  Widget _buildPlaylistsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _primaryGradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton.icon(
              onPressed: _showCreatePlaylistDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Create New Playlist', style: TextStyle(color: Colors.white)),
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
          child: _customPlaylists.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.playlist_play, size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text('No playlists yet', style: TextStyle(color: Colors.white54, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('Create your first playlist', style: TextStyle(color: Colors.white24, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _customPlaylists.keys.length,
                  itemBuilder: (context, index) {
                    final playlistName = _customPlaylists.keys.elementAt(index);
                    final songs = _customPlaylists[playlistName]!;
                    return Card(
                      color: _cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Text(
                          playlistName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Text(
                          '${songs.length} songs',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: _getSongGradient(index)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.playlist_play, color: Colors.white),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: _secondaryGradient),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                                onPressed: () => _showAddToPlaylistDialog(playlistName),
                                tooltip: 'Add songs',
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deletePlaylist(playlistName),
                            ),
                          ],
                        ),
                        children: songs.isEmpty
                            ? [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      const Text('No songs in this playlist', style: TextStyle(color: Colors.white54)),
                                      const SizedBox(height: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: _primaryGradient),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: () => _showAddToPlaylistDialog(playlistName),
                                          icon: const Icon(Icons.add, size: 16, color: Colors.white),
                                          label: const Text('Add Songs', style: TextStyle(color: Colors.white)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            shadowColor: Colors.transparent,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ]
                            : songs.map((song) {
                                return _buildSongTile(
                                  title: _cleanSongName(song.name),
                                  subtitle: 'Tap to play',
                                  gradient: _getSongGradient(index),
                                  onTap: () => _playSpecificSong(song),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                                    onPressed: () => _removeFromPlaylist(playlistName, song),
                                  ),
                                );
                              }).toList(),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ===== SONG TILE =====
  Widget _buildSongTile({
    required String title,
    required String subtitle,
    required List<Color> gradient,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              title.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  // ============================================================
  // PLAYER UI - WITH THEME
  // ============================================================
  Widget _buildPlayerUI() {
    String currentSongName = _playlist.isNotEmpty ? _cleanSongName(_playlist[_currentIndex].name) : "No song playing";
    bool isCurrentFavorite = _playlist.isNotEmpty && _favorites.contains(_playlist[_currentIndex]);
    bool hasSongs = _playlist.isNotEmpty;
    List<Color> currentGradient = hasSongs ? _getSongGradient(_currentIndex) : _primaryGradient;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              
              // Song Name
              Text(
                currentSongName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 2),
              
              Text(
                hasSongs ? "Song ${_currentIndex + 1} of ${_playlist.length}" : "No songs",
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              
              const SizedBox(height: 12),
              
              // Album Art
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isPlaying ? _pulseAnimation.value : 1.0,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 180,
                          width: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: currentGradient),
                            boxShadow: [
                              BoxShadow(
                                color: _neonColor.withOpacity(0.3),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Center(
                            child: hasSongs
                                ? Text(
                                    _cleanSongName(_playlist[_currentIndex].name).substring(0, 1).toUpperCase(),
                                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                                  )
                                : const Icon(Icons.music_note_rounded, size: 60, color: Colors.white),
                          ),
                        ),
                        if (_sleepTimerActive)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Color(0xFFFF9F43), shape: BoxShape.circle),
                              child: const Icon(Icons.timer, color: Colors.white, size: 14),
                            ),
                          ),
                        Positioned(
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _neonColor.withOpacity(0.3), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(isPlaying ? Icons.play_arrow : Icons.pause, color: _neonColor, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  isPlaying ? 'Playing' : 'Paused',
                                  style: TextStyle(color: _neonColor, fontSize: 10, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 12),
              
              // Progress Bar
              Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: _neonColor,
                      inactiveTrackColor: Colors.grey.shade800,
                      thumbColor: _neonColor,
                    ),
                    child: Slider(
                      min: 0.0,
                      max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                      value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0),
                      onChanged: (value) async {
                        final position = Duration(seconds: value.toInt());
                        await _audioPlayer.seek(position);
                        setState(() => _position = position);
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_position), style: TextStyle(color: Colors.white54, fontSize: 10)),
                      Text(_formatDuration(_duration), style: TextStyle(color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Playback Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Shuffle/Repeat Button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isShuffle) {
                          isShuffle = false;
                          repeatMode = (repeatMode + 1) % 3;
                        } else {
                          isShuffle = true;
                          repeatMode = 0;
                        }
                      });
                      _saveData();
                    },
                    onLongPress: _showShuffleRepeatMenu,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isShuffle || repeatMode > 0) ? _neonColor.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: (isShuffle || repeatMode > 0) ? Border.all(color: _neonColor.withOpacity(0.3), width: 1) : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isShuffle ? Icons.shuffle : Icons.repeat,
                            color: (isShuffle || repeatMode > 0) ? _neonColor : Colors.white54,
                            size: 18,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            isShuffle ? 'Shuffle' : (repeatMode == 1 ? '1' : (repeatMode == 2 ? 'All' : '')),
                            style: TextStyle(
                              color: (isShuffle || repeatMode > 0) ? _neonColor : Colors.white54,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 4),
                  
                  // Previous
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white, size: 24),
                    onPressed: hasSongs ? _playPreviousSong : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  
                  const SizedBox(width: 4),
                  
                  // Play/Pause
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: currentGradient),
                      boxShadow: [
                        BoxShadow(
                          color: _neonColor.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                      iconSize: 28,
                      onPressed: _togglePlayPause,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  
                  const SizedBox(width: 4),
                  
                  // Next
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white, size: 24),
                    onPressed: hasSongs ? _playNextSong : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  
                  const SizedBox(width: 4),
                  
                  // Queue Button
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: _secondaryGradient),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.queue_music, color: Colors.white, size: 20),
                      onPressed: _showQueueBottomSheet,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 10),
              
              // Bottom Action Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: isCurrentFavorite ? Icons.favorite : Icons.favorite_border,
                    label: '',
                    isActive: isCurrentFavorite,
                    activeColor: Colors.red,
                    size: 18,
                    onTap: hasSongs ? () => _toggleFavorite(_playlist[_currentIndex]) : null,
                  ),
                  
                  _buildActionButton(
                    icon: Icons.spatial_audio,
                    label: '3D',
                    isActive: is3DMode,
                    activeColor: _neonColor,
                    size: 18,
                    onTap: () async {
                      setState(() => is3DMode = !is3DMode);
                      if (is3DMode) {
                        await _audioPlayer.setBalance(0.5);
                        await _audioPlayer.setVolume(0.9);
                      } else {
                        await _audioPlayer.setBalance(0.0);
                        await _audioPlayer.setVolume(_volume);
                      }
                      _saveData();
                    },
                  ),
                  
                  _buildActionButton(
                    icon: Icons.equalizer,
                    label: _isEqActive ? 'EQ' : '',
                    isActive: _isEqActive,
                    activeColor: _neonColor,
                    size: 18,
                    onTap: () => _showEqualizerDialog(),
                  ),
                  
                  _buildActionButton(
                    icon: Icons.timer,
                    label: _sleepTimerActive ? '${_sleepTimerMinutes}m' : '',
                    isActive: _sleepTimerActive,
                    activeColor: const Color(0xFFFF9F43),
                    size: 18,
                    onTap: () => _showSleepTimerDialog(),
                  ),
                  
                  _buildActionButton(
                    icon: Icons.volume_up,
                    label: '${(_volume * 100).toInt()}%',
                    isActive: false,
                    activeColor: Colors.white,
                    size: 18,
                    onTap: () => _showVolumePopup(context),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ===== ACTION BUTTON =====
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
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isActive ? activeColor.withOpacity(0.15) : _cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive ? activeColor : Colors.grey.shade800,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : Colors.white54,
              size: size,
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : Colors.white54,
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===== VOLUME POPUP =====
  void _showVolumePopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bgColor,
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: _primaryGradient),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.volume_up, color: Colors.white, size: 20),
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
                            activeTrackColor: _neonColor,
                            inactiveTrackColor: Colors.grey.shade800,
                            thumbColor: _neonColor,
                          ),
                          child: Slider(
                            min: 0.0,
                            max: 1.0,
                            value: _volume,
                            onChanged: (value) async {
                              setModalState(() => _volume = value);
                              setState(() => _volume = value);
                              _baseVolume = value;
                              await _audioPlayer.setVolume(value);
                              await _applyEqualizer();
                              _saveData();
                            },
                          ),
                        ),
                      ),
                      const Icon(Icons.volume_up, color: Colors.white54),
                    ],
                  ),
                  Center(
                    child: Text(
                      '${(_volume * 100).toInt()}%',
                      style: TextStyle(color: _neonColor, fontSize: 18, fontWeight: FontWeight.bold),
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

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 1: return 'Favorites';
      case 2: return 'Recent';
      case 3: return 'Playlists';
      default: return 'My Music';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selectedIndex == 0) ...[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _primaryGradient),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.music_note, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              _getAppBarTitle(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_selectedIndex == 0) ...[
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _secondaryGradient),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
              onPressed: _pickSongs,
              tooltip: 'Add Songs',
            ),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              color: _cardColor,
              onSelected: (value) {
                if (value == 'clear') {
                  _clearQueue();
                } else if (value == 'reset_eq') {
                  _resetEqualizer();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Color(0xFFFF6B6B), size: 20),
                      SizedBox(width: 10),
                      Text('Clear Queue', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset_eq',
                  child: Row(
                    children: [
                      Icon(Icons.equalizer, color: Color(0xFF00E5FF), size: 20),
                      SizedBox(width: 10),
                      Text('Reset Equalizer', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _buildBodyContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: _cardColor,
        selectedItemColor: _neonColor,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          _saveData();
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_filled),
            label: 'Player',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Recent',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.playlist_play),
            label: 'Playlists',
          ),
        ],
      ),
    );
  }
}
