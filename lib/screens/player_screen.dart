import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';

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
  final List<PlatformFile> _favorites = [];
  final List<PlatformFile> _recent = [];
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
  final Map<String, List<PlatformFile>> _customPlaylists = {};
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

  // MIUI Colors
  final Color _miuiBg = const Color(0xFF1A1A2E);
  final Color _miuiCard = const Color(0xFF2D2D44);
  final Color _miuiAccent = const Color(0xFF6C63FF);
  final Color _miuiText = const Color(0xFFFFFFFF);
  final Color _miuiTextSecondary = const Color(0xFF8888AA);

  // Gradient Colors for Album Art
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
    _pulseController.dispose();
    _audioPlayer.dispose();
    _sleepTimer?.cancel();
    super.dispose();
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
  }

  Future<void> _applyPreset(String presetName) async {
    setState(() {
      _currentEqPreset = presetName;
      _currentEqValues = List.from(_eqPresets[presetName]!);
      _isEqActive = presetName != 'Normal';
    });
    await _applyEqualizer();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎵 $presetName applied'),
          backgroundColor: _miuiAccent,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showEqualizerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _miuiBg,
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
                  // MIUI Style Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Equalizer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                            onPressed: () {
                              _resetEqualizer();
                              setModalState(() {});
                            },
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
                  
                  // Presets
                  const Text(
                    'PRESETS',
                    style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _eqPresets.keys.map((preset) {
                      bool isSelected = _currentEqPreset == preset;
                      return FilterChip(
                        label: Text(
                          preset,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: _miuiAccent.withOpacity(0.3),
                        backgroundColor: _miuiCard,
                        side: BorderSide(
                          color: isSelected ? _miuiAccent : Colors.grey.shade700,
                          width: 1.5,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            _applyPreset(preset);
                            setModalState(() {});
                          }
                        },
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  
                  // EQ Sliders - MIUI Style
                  const Text(
                    'FREQUENCY BANDS',
                    style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  
                  Expanded(
                    child: ListView.builder(
                      itemCount: 3,
                      itemBuilder: (context, index) {
                        return _buildMiuiEqSlider(
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
                          },
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // EQ Toggle - MIUI Style
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Enable Equalizer',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      Switch(
                        value: _isEqActive,
                        activeColor: _miuiAccent,
                        activeTrackColor: _miuiAccent.withOpacity(0.3),
                        onChanged: (value) async {
                          setState(() {
                            _isEqActive = value;
                            if (!value) {
                              _currentEqValues = [0, 0, 0];
                              _currentEqPreset = 'Normal';
                            }
                          });
                          await _applyEqualizer();
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

  Widget _buildMiuiEqSlider({
    required String label,
    required int index,
    required double value,
    required Function(double) onChanged,
  }) {
    List<Color> colors = [
      Color(0xFFFF6B6B),
      Color(0xFF4ECDC4),
      Color(0xFF6C63FF),
    ];
    Color color = colors[index % colors.length];
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value > 0 ? '+${value.toInt()}' : '${value.toInt()}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
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

  // ===== QUEUE MANAGEMENT =====
  void _clearQueue() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _miuiBg,
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
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
  }

  // ===== SLEEP TIMER =====
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
  }

  void _showSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _miuiBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sleep Timer', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMiuiTimerOption(15),
            _buildMiuiTimerOption(30),
            _buildMiuiTimerOption(60),
            _buildMiuiTimerOption(90),
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

  Widget _buildMiuiTimerOption(int minutes) {
    return ListTile(
      leading: const Icon(Icons.timer, color: Color(0xFF6C63FF)),
      title: Text('$minutes minutes', style: const TextStyle(color: Colors.white)),
      trailing: _sleepTimerActive && _sleepTimerMinutes == minutes
          ? const Icon(Icons.check_circle, color: Color(0xFF4ECDC4))
          : null,
      onTap: () {
        _startSleepTimer(minutes);
        Navigator.pop(context);
      },
    );
  }

  // ===== PLAYLIST FUNCTIONS =====
  void _createPlaylist(String name) {
    if (name.trim().isEmpty) return;
    setState(() {
      _customPlaylists[name.trim()] = [];
      _newPlaylistName = '';
    });
  }

  void _removeFromPlaylist(String playlistName, PlatformFile song) {
    setState(() {
      if (_customPlaylists.containsKey(playlistName)) {
        _customPlaylists[playlistName]!.remove(song);
      }
    });
  }

  void _showCreatePlaylistDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _miuiBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6C63FF))),
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
            child: const Text('Create', style: TextStyle(color: Color(0xFF6C63FF))),
          ),
        ],
      ),
    );
  }

  // ===== AUDIO PLAYBACK =====
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.files.length} songs added'),
              backgroundColor: _miuiAccent,
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
      }

      if (currentFile.path != null) {
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(currentFile.path!));
        _baseVolume = _volume;
        await _audioPlayer.setVolume(_volume);
        await _audioPlayer.setBalance(is3DMode ? 0.5 : 0.0);
        await _applyEqualizer();
        if (mounted) setState(() => isPlaying = true);
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
    await _playCurrentSongInQueue();
  }

  Future<void> _playPreviousSong() async {
    if (_playlist.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    });
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
      } else {
        await _audioPlayer.resume();
        if (mounted) setState(() => isPlaying = true);
      }
    } catch (e) {
      debugPrint('Error toggling play/pause: $e');
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
  }

  // ===== UI HELPERS =====
  List<PlatformFile> _getFilteredSongs() {
    if (_searchQuery.isEmpty) return _playlist;
    return _playlist.where((song) =>
      _cleanSongName(song.name).toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  // ===== BODY CONTENT =====
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

  // ===== FAVORITES TAB - MIUI STYLE =====
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
        return _buildMiuiSongTile(
          title: cleanName,
          subtitle: '${index + 1}',
          gradient: gradient,
          trailing: IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            onPressed: () => setState(() => _favorites.remove(song)),
          ),
          onTap: () => _playSpecificSong(song),
        );
      },
    );
  }

  // ===== RECENT TAB - MIUI STYLE =====
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
        return _buildMiuiSongTile(
          title: cleanName,
          subtitle: 'Recently played',
          gradient: gradient,
          trailing: Text(
            '${index + 1}',
            style: const TextStyle(color: Colors.white24, fontSize: 12),
          ),
          onTap: () => _playSpecificSong(song),
        );
      },
    );
  }

  // ===== PLAYLISTS TAB - MIUI STYLE =====
  Widget _buildPlaylistsTab() {
    if (_customPlaylists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_play, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('No playlists yet', style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Create your first playlist', style: TextStyle(color: Colors.white24, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showCreatePlaylistDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Playlist'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _miuiAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _customPlaylists.keys.length,
      itemBuilder: (context, index) {
        final playlistName = _customPlaylists.keys.elementAt(index);
        final songs = _customPlaylists[playlistName]!;
        return Card(
          color: _miuiCard,
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
                gradient: LinearGradient(
                  colors: _getSongGradient(index),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.playlist_play, color: Colors.white),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => setState(() => _customPlaylists.remove(playlistName)),
            ),
            children: songs.isEmpty
                ? [const Padding(padding: EdgeInsets.all(16), child: Text('No songs', style: TextStyle(color: Colors.white54)))]
                : songs.map((song) {
                    return _buildMiuiSongTile(
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
    );
  }

  // ===== MIUI SONG TILE =====
  Widget _buildMiuiSongTile({
    required String title,
    required String subtitle,
    required List<Color> gradient,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _miuiCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              title.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  // ===== MIUI PLAYER UI =====
  Widget _buildPlayerUI() {
    String currentSongName = _playlist.isNotEmpty ? _cleanSongName(_playlist[_currentIndex].name) : "No song playing";
    bool isCurrentFavorite = _playlist.isNotEmpty && _favorites.contains(_playlist[_currentIndex]);
    bool hasSongs = _playlist.isNotEmpty;
    List<Color> currentGradient = hasSongs ? _getSongGradient(_currentIndex) : [Color(0xFF6C63FF), Color(0xFF3F3D9E)];

    return SafeArea(
      child: Column(
        children: [
          // ===== TOP BAR WITH SONG INFO =====
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Song Title - MIUI Style
                Text(
                  currentSongName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  hasSongs ? "Song ${_currentIndex + 1} of ${_playlist.length}" : "No songs",
                  style: TextStyle(
                    fontSize: 14,
                    color: _miuiTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // ===== ALBUM ART - MIUI STYLE =====
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: isPlaying ? _pulseAnimation.value : 1.0,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 280,
                        width: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: currentGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: currentGradient[0].withOpacity(0.4),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Center(
                          child: hasSongs
                              ? Text(
                                  _cleanSongName(_playlist[_currentIndex].name).substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 72,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.music_note_rounded,
                                  size: 100,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                      // Sleep Timer Badge
                      if (_sleepTimerActive)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF9F43),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.timer, color: Colors.white, size: 18),
                          ),
                        ),
                      // Play/Pause Badge - MIUI Style
                      Positioned(
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPlaying ? Icons.play_arrow : Icons.pause,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isPlaying ? 'Playing' : 'Paused',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
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
          ),
          
          const SizedBox(height: 20),
          
          // ===== PROGRESS BAR - MIUI STYLE =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: _miuiAccent,
                    inactiveTrackColor: Colors.grey.shade800,
                    thumbColor: _miuiAccent,
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
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(color: _miuiTextSecondary, fontSize: 12),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(color: _miuiTextSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // ===== PLAYBACK CONTROLS - MIUI STYLE =====
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Repeat
              IconButton(
                icon: Icon(
                  repeatMode == 1 ? Icons.repeat_one : (repeatMode == 2 ? Icons.repeat : Icons.repeat_outlined),
                  color: repeatMode > 0 ? _miuiAccent : Colors.white54,
                  size: 24,
                ),
                onPressed: () => setState(() => repeatMode = (repeatMode + 1) % 3),
              ),
              
              const SizedBox(width: 8),
              
              // Previous
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32),
                onPressed: hasSongs ? _playPreviousSong : null,
              ),
              
              const SizedBox(width: 8),
              
              // Play/Pause - MIUI Big Button
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: currentGradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: currentGradient[0].withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  iconSize: 40,
                  onPressed: _togglePlayPause,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Next
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
                onPressed: hasSongs ? _playNextSong : null,
              ),
              
              const SizedBox(width: 8),
              
              // Shuffle
              IconButton(
                icon: Icon(
                  isShuffle ? Icons.shuffle : Icons.shuffle_outlined,
                  color: isShuffle ? _miuiAccent : Colors.white54,
                  size: 24,
                ),
                onPressed: () => setState(() => isShuffle = !isShuffle),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // ===== BOTTOM ACTION ROW - MIUI STYLE =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Favorite
                _buildMiuiActionButton(
                  icon: isCurrentFavorite ? Icons.favorite : Icons.favorite_border,
                  label: isCurrentFavorite ? 'Liked' : 'Like',
                  isActive: isCurrentFavorite,
                  activeColor: Colors.red,
                  onTap: hasSongs ? () => _toggleFavorite(_playlist[_currentIndex]) : null,
                ),
                
                // 3D
                _buildMiuiActionButton(
                  icon: Icons.spatial_audio,
                  label: '3D',
                  isActive: is3DMode,
                  activeColor: _miuiAccent,
                  onTap: () async {
                    setState(() => is3DMode = !is3DMode);
                    if (is3DMode) {
                      await _audioPlayer.setBalance(0.5);
                      await _audioPlayer.setVolume(0.9);
                    } else {
                      await _audioPlayer.setBalance(0.0);
                      await _audioPlayer.setVolume(_volume);
                    }
                  },
                ),
                
                // EQ
                _buildMiuiActionButton(
                  icon: Icons.equalizer,
                  label: _isEqActive ? _currentEqPreset : 'EQ',
                  isActive: _isEqActive,
                  activeColor: Colors.blue,
                  onTap: () => _showEqualizerDialog(),
                ),
                
                // Timer
                _buildMiuiActionButton(
                  icon: Icons.timer,
                  label: _sleepTimerActive ? '${_sleepTimerMinutes}m' : 'Timer',
                  isActive: _sleepTimerActive,
                  activeColor: const Color(0xFFFF9F43),
                  onTap: () => _showSleepTimerDialog(),
                ),
                
                // Volume
                _buildMiuiActionButton(
                  icon: Icons.volume_up,
                  label: '${(_volume * 100).toInt()}%',
                  isActive: false,
                  activeColor: Colors.white,
                  onTap: () => _showVolumePopup(context),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ===== MIUI ACTION BUTTON =====
  Widget _buildMiuiActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? activeColor.withOpacity(0.15) : _miuiCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? activeColor : Colors.grey.shade800,
                width: 1,
              ),
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
              color: isActive ? activeColor : Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ===== VOLUME POPUP - MIUI STYLE =====
  void _showVolumePopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _miuiBg,
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
                  const Text(
                    'Volume',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                            activeTrackColor: _miuiAccent,
                            inactiveTrackColor: Colors.grey.shade800,
                            thumbColor: _miuiAccent,
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
                      style: const TextStyle(
                        color: Color(0xFF6C63FF),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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

  // ===== QUEUE BOTTOM SHEET - MIUI STYLE =====
  void _showQueueBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _miuiBg,
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
                          const Text(
                            'Queue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _miuiAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_playlist.length}',
                              style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 13),
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
                  
                  // Search
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search in queue...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF6C63FF)),
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
                                  color: isCurrent ? _miuiAccent.withOpacity(0.1) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isCurrent ? [Color(0xFF6C63FF), Color(0xFF3F3D9E)] : gradient,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${originalIndex + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    cleanName,
                                    style: TextStyle(
                                      color: isCurrent ? _miuiAccent : Colors.white,
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
                                        const Icon(Icons.play_arrow, color: Color(0xFF6C63FF)),
                                    ],
                                  ),
                                  onTap: () {
                                    setState(() => _currentIndex = originalIndex);
                                    _playCurrentSongInQueue();
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
      backgroundColor: _miuiBg,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selectedIndex == 0) ...[
              Icon(Icons.music_note, color: _miuiAccent, size: 24),
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
              icon: const Icon(Icons.add, color: Colors.white70),
              onPressed: _pickSongs,
              tooltip: 'Add Songs',
            ),
            IconButton(
              icon: const Icon(Icons.queue_music, color: Colors.white70),
              onPressed: () => _showQueueBottomSheet(context),
              tooltip: 'Queue',
            ),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              color: _miuiBg,
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
                      Icon(Icons.equalizer, color: Colors.blue, size: 20),
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
        backgroundColor: _miuiCard,
        selectedItemColor: _miuiAccent,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        onTap: (index) => setState(() => _selectedIndex = index),
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
