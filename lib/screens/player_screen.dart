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
  
  // ===== MASTER LIST - All songs safe =====
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

  // ===== CUSTOM PLAYLISTS =====
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
  // EQUALIZER FUNCTIONS
  // ============================================================
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
      debugPrint('❌ Error saving data: $e');
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
              borderSide: BorderSide(color: _accentColor.withOpacity(0.3)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _accentColor),
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
            child: Text('Create', style: TextStyle(color: _accentColor)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADD SONGS TO PLAYLIST - FIXED
  // ============================================================
    void _showAddToPlaylistDialog(String playlistName) {
    List<PlatformFile> availableSongs = _masterList.where((song) =>
      !_customPlaylists[playlistName]!.contains(song)
    ).toList();

    if (_masterList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ No songs in master list. Add songs first!'),
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

    // 💡 FIX 1: List ko showModalBottomSheet aur StatefulBuilder ke UPAR rakha hai
    List<PlatformFile> selectedSongs = [];

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
                  
                  // Select All & Add Button Area
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
                        activeColor: _accentColor,
                      ),
                      Text(
                        'Select All (${availableSongs.length})',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const Spacer(),
                      
                      // Add Button
                      if (selectedSongs.isNotEmpty)
                        Container(
                          height: 35,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: _primaryGradient),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              for (var song in selectedSongs) {
                                _addSongToPlaylist(playlistName, song);
                              }
                              
                              // 💡 FIX 2: Songs add hone ke baad UI refresh hone ke liye setState
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
                  
                  // Songs List
                  Expanded(
                    child: ListView.builder(
                      itemCount: availableSongs.length,
                      itemBuilder: (context, index) {
                        final song = availableSongs[index];
                        String cleanName = _cleanSongName(song.name);
                        List<Color> gradient = _getSongGradient(index);
                        bool isSelected = selectedSongs.contains(song);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? _accentColor.withOpacity(0.1) : _cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected 
                                ? Border.all(color: _accentColor.withOpacity(0.5), width: 1.5) 
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
                                  cleanName.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            title: Text(
                              cleanName,
                              style: TextStyle(
                                color: isSelected ? _accentColor : Colors.white,
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
                              activeColor: _accentColor,
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
 
  // ============================================================
  // QUEUE MANAGEMENT
  // ============================================================
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
              content: Text('${result.files.length} songs added to master list'),
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

  Future<void> _playSpecificSong(PlatformFile song, {List<PlatformFile>? playlist}) async {
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
  // UI HELPERS
  // ============================================================
  List<PlatformFile> _getFilteredSongs() {
    if (_searchQuery.isEmpty) return _playlist;
    return _playlist.where((song) =>
      _cleanSongName(song.name).toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  // ============================================================
  // GRADIENT ICON HELPER
  // ============================================================
  Widget _buildGradientIcon(IconData icon, double size, List<Color> gradient) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: gradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Icon(icon, color: Colors.white, size: size),
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
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(cleanName.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            title: Text(cleanName, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 18),
              onPressed: () {
                setState(() => _favorites.remove(song));
                _saveData();
              },
            ),
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
        List<Color> gradient = _getSongGradient(index);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(cleanName.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            title: Text(cleanName, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text('${index + 1}', style: TextStyle(color: _textSecondary, fontSize: 12)),
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
  return Column(
    children: [
      // Create Playlist Button
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
      
      // Playlists List
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _customPlaylists.keys.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              // ===== ALL SONGS - Fixed =====
              return Card(
                color: _cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Row(
                    children: [
                      const Icon(Icons.music_note, color: Color(0xFF6C63FF), size: 20),
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
                    '${_masterList.length} songs',
                    style: TextStyle(color: _textSecondary),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF3F3D9E)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.library_music, color: Colors.white),
                  ),
                  // ===== NO TRAILING (Delete button nahi) =====
                  children: _masterList.isEmpty
                      ? [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No songs in master list. Add songs from Player screen!',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        ]
                      : _masterList.map((song) {
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
                                  gradient: LinearGradient(
                                    colors: _getSongGradient(_masterList.indexOf(song)),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    _cleanSongName(song.name).substring(0, 1).toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                _cleanSongName(song.name),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'Master List',
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // ===== NO DELETE BUTTON =====
                              onTap: () => _playSpecificSong(song),
                            ),
                          );
                        }).toList(),
                ),
              );
            }
            
            // ===== CUSTOM PLAYLISTS =====
            final playlistIndex = index - 1;
            final playlistName = _customPlaylists.keys.elementAt(playlistIndex);
            final songs = _customPlaylists[playlistName]!;
            
            return Card(
              color: _cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
                  style: TextStyle(color: _textSecondary),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getSongGradient(playlistIndex),
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
                        gradient: LinearGradient(
                          colors: _secondaryGradient,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.white, size: 20),
                        onPressed: () => _showAddToPlaylistDialog(playlistName),
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
                              const Text(
                                'No songs in this playlist',
                                style: TextStyle(color: Colors.white54),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _primaryGradient,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAddToPlaylistDialog(playlistName),
                                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                                  label: const Text(
                                    'Add Songs from Master List',
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
                    : songs.map((song) {
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
                                gradient: LinearGradient(
                                  colors: _getSongGradient(playlistIndex),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  _cleanSongName(song.name).substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              _cleanSongName(song.name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                              onPressed: () => _removeFromPlaylist(playlistName, song),
                            ),
                            onTap: () => _playSpecificSong(song, playlist: songs),
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

  // ============================================================
  // VOLUME POPUP
  // ============================================================
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
                      _buildGradientIcon(Icons.volume_up, 24, _primaryGradient),
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
                            activeTrackColor: _accentColor,
                            inactiveTrackColor: Colors.grey.shade800,
                            thumbColor: _accentColor,
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
                      style: TextStyle(color: _accentColor, fontSize: 18, fontWeight: FontWeight.bold),
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
  // ACTION BUTTON
  // ============================================================
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

  // ============================================================
  // PLAYER UI
  // ============================================================
  Widget _buildPlayerUI() {
    String currentSongName = _playlist.isNotEmpty ? _cleanSongName(_playlist[_currentIndex].name) : "No song playing";
    String currentArtist = _playlist.isNotEmpty ? "Luna Echo" : "Luna Echo";
    bool isCurrentFavorite = _playlist.isNotEmpty && _favorites.contains(_playlist[_currentIndex]);
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
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 4),
            
            Text(
              currentArtist,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 20),
            
            // Album Art
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isPlaying ? _pulseAnimation.value : 1.0,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 200,
                          width: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: currentGradient),
                            boxShadow: [
                              BoxShadow(color: _accentColor.withOpacity(0.3), blurRadius: 35, spreadRadius: 6),
                            ],
                          ),
                        ),
                        Container(
                          height: 180,
                          width: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: currentGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                          ),
                          child: Center(
                            child: hasSongs
                                ? Text(
                                    _cleanSongName(_playlist[_currentIndex].name).substring(0, 1).toUpperCase(),
                                    style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: Colors.white),
                                  )
                                : const Icon(Icons.music_note_rounded, size: 60, color: Colors.white),
                          ),
                        ),
                        if (_sleepTimerActive)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(color: Color(0xFFFF9F43), shape: BoxShape.circle),
                              child: const Icon(Icons.timer, color: Colors.white, size: 12),
                            ),
                          ),
                        
            const SizedBox(height: 20),
            
            // Progress Bar
            Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
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
                      await _audioPlayer.seek(position);
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
            
            // Playback Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isShuffle || repeatMode > 0) ? _accentColor.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: (isShuffle || repeatMode > 0) ? Border.all(color: _accentColor.withOpacity(0.3), width: 1) : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isShuffle ? Icons.shuffle : Icons.repeat, color: (isShuffle || repeatMode > 0) ? _accentColor : Colors.white54, size: 16),
                        const SizedBox(width: 2),
                        Text(isShuffle ? 'Shuffle' : (repeatMode == 1 ? '1' : (repeatMode == 2 ? 'All' : '')), style: TextStyle(color: (isShuffle || repeatMode > 0) ? _accentColor : Colors.white54, fontSize: 8)),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 4),
                
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: Colors.white, size: 24),
                  onPressed: hasSongs ? _playPreviousSong : null,
                  padding: const EdgeInsets.all(4),
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
                  padding: const EdgeInsets.all(4),
                ),
                
                const SizedBox(width: 4),
                
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _secondaryGradient),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.queue_music, color: Colors.white, size: 18),
                    onPressed: _showQueueBottomSheet,
                    padding: const EdgeInsets.all(6),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 14),
            
            // Bottom Action Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.spatial_audio,
                  label: '3D',
                  isActive: is3DMode,
                  activeColor: _accentColor,
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
                  label: _isEqActive ? 'ON' : 'EQ',
                  isActive: _isEqActive,
                  activeColor: _accentColor,
                  size: 18,
                  onTap: _showEqualizerDialog,
                ),
                
                _buildActionButton(
                  icon: Icons.volume_up,
                  label: 'Volume',
                  isActive: false,
                  activeColor: Colors.white,
                  size: 18,
                  onTap: () => _showVolumePopup(context),
                ),
                
                _buildActionButton(
                  icon: isCurrentFavorite ? Icons.favorite : Icons.favorite_border,
                  label: isCurrentFavorite ? 'Liked' : 'Heart',
                  isActive: isCurrentFavorite,
                  activeColor: Colors.red,
                  size: 18,
                  onTap: hasSongs ? () => _toggleFavorite(_playlist[_currentIndex]) : null,
                ),
                
                _buildActionButton(
                  icon: Icons.timer,
                  label: _sleepTimerActive ? '${_sleepTimerMinutes}m' : 'Timer',
                  isActive: _sleepTimerActive,
                  activeColor: const Color(0xFFFF9F43),
                  size: 18,
                  onTap: () => _showSleepTimerDialog(),
                ),
              ],
            ),
            
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SHOW QUEUE BOTTOM SHEET
  // ============================================================
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
                            child: Text('${_playlist.length}', style: const TextStyle(color: Colors.white, fontSize: 13)),
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
                        borderSide: BorderSide(color: _accentColor.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _accentColor),
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
                                  color: isCurrent ? _accentColor.withOpacity(0.1) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isCurrent ? Border.all(color: _accentColor.withOpacity(0.3), width: 1) : null,
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
                                      color: isCurrent ? _accentColor : Colors.white,
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
                                      if (isCurrent)
                                        Icon(Icons.play_arrow, color: _accentColor),
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
          const SnackBar(content: Text('⏰ Sleep timer stopped'), backgroundColor: Color(0xFFFF9F43)),
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
          ? Icon(Icons.check_circle, color: _accentColor)
          : null,
      onTap: () {
        _startSleepTimer(minutes);
        Navigator.pop(context);
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
        title: Text(_getAppBarTitle(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_selectedIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white70),
              onPressed: _pickSongs,
              tooltip: 'Add Songs to Master List',
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
                      Icon(Icons.equalizer, color: Color(0xFF6C63FF), size: 20),
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
        selectedItemColor: _accentColor,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          _saveData();
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
