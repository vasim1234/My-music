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

  // ===== EQUALIZER =====
  String _currentEqPreset = 'Normal';
  final Map<String, double> _eqValues = {
    'bass': 0.0,
    'treble': 0.0,
    'mid': 0.0,
    'lowMid': 0.0,
    'highMid': 0.0,
  };
  
  final Map<String, Map<String, double>> _eqPresets = {
    'Normal': {'bass': 0.0, 'treble': 0.0, 'mid': 0.0, 'lowMid': 0.0, 'highMid': 0.0},
    'Bass Boost': {'bass': 0.8, 'treble': -0.2, 'mid': 0.0, 'lowMid': 0.4, 'highMid': -0.2},
    'Treble Boost': {'bass': -0.2, 'treble': 0.8, 'mid': 0.0, 'lowMid': -0.2, 'highMid': 0.4},
    'Pop': {'bass': 0.3, 'treble': 0.4, 'mid': 0.0, 'lowMid': 0.2, 'highMid': 0.2},
    'Rock': {'bass': 0.5, 'treble': 0.3, 'mid': 0.2, 'lowMid': 0.3, 'highMid': 0.3},
    'Classical': {'bass': -0.3, 'treble': 0.6, 'mid': 0.1, 'lowMid': -0.1, 'highMid': 0.5},
    'Jazz': {'bass': 0.4, 'treble': -0.1, 'mid': 0.2, 'lowMid': 0.3, 'highMid': 0.0},
  };

  // ===== SONG COLORS FOR ALBUM ART =====
  final List<Color> _albumColors = [
    Colors.purple,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.pink,
    Colors.cyan,
    Colors.teal,
    Colors.indigo,
    Colors.deepPurple,
    Colors.amber,
    Colors.lime,
  ];

  Color _getSongColor(int index) {
    return _albumColors[index % _albumColors.length];
  }

  String _cleanSongName(String fileName) {
    String name = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    name = name.replaceAll(RegExp(r'\(\w*_\d+K\)', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\(\d+K\)', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\(MP3_\d+K\)', caseSensitive: false), '');
    name = name.trim();
    if (name.length > 40) {
      name = '${name.substring(0, 40)}...';
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
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
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

  // ===== EQUALIZER FUNCTIONS =====
  void _applyEqualizer() {
    double bassBoost = _eqValues['bass']!;
    double trebleBoost = _eqValues['treble']!;
    double balance = (trebleBoost - bassBoost).clamp(-1.0, 1.0) * 0.3;
    double volumeMultiplier = 1.0 + (bassBoost + trebleBoost) * 0.1;
    _audioPlayer.setBalance(balance.clamp(-1.0, 1.0));
    _audioPlayer.setVolume((_volume * volumeMultiplier).clamp(0.0, 1.0));
  }

  void _resetEqualizer() {
    setState(() {
      _currentEqPreset = 'Normal';
      _eqValues['bass'] = 0.0;
      _eqValues['treble'] = 0.0;
      _eqValues['mid'] = 0.0;
      _eqValues['lowMid'] = 0.0;
      _eqValues['highMid'] = 0.0;
    });
    _applyEqualizer();
  }

  void _applyPreset(String presetName) {
    setState(() {
      _currentEqPreset = presetName;
      final preset = _eqPresets[presetName]!;
      _eqValues['bass'] = preset['bass']!;
      _eqValues['treble'] = preset['treble']!;
      _eqValues['mid'] = preset['mid']!;
      _eqValues['lowMid'] = preset['lowMid']!;
      _eqValues['highMid'] = preset['highMid']!;
    });
    _applyEqualizer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎵 $presetName preset applied'),
        backgroundColor: Colors.purpleAccent,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showEqualizerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.equalizer, color: Colors.purpleAccent, size: 28),
                          const SizedBox(width: 10),
                          const Text('Equalizer', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.purpleAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(_currentEqPreset, style: const TextStyle(color: Colors.purpleAccent, fontSize: 11)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                            onPressed: () {
                              _resetEqualizer();
                              setModalState(() {});
                            },
                            tooltip: 'Reset',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white24),
                  const Text('PRESETS', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _eqPresets.keys.map((preset) {
                      bool isSelected = _currentEqPreset == preset;
                      return FilterChip(
                        label: Text(preset, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12)),
                        selected: isSelected,
                        selectedColor: Colors.purpleAccent.withOpacity(0.3),
                        backgroundColor: Colors.grey.shade800,
                        side: BorderSide(color: isSelected ? Colors.purpleAccent : Colors.grey.shade700, width: 1.5),
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
                  const Text('CUSTOM EQ', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildEqSlider('Bass', 'bass', Colors.blue, setModalState),
                        _buildEqSlider('Low Mid', 'lowMid', Colors.cyan, setModalState),
                        _buildEqSlider('Mid', 'mid', Colors.green, setModalState),
                        _buildEqSlider('High Mid', 'highMid', Colors.orange, setModalState),
                        _buildEqSlider('Treble', 'treble', Colors.red, setModalState),
                      ],
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

  Widget _buildEqSlider(String label, String key, Color color, Function setModalState) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.music_note, color: color, size: 16),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Text('${(_eqValues[key]! * 10).toInt()} dB', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        Slider(
          value: _eqValues[key]!,
          min: -1.0,
          max: 1.0,
          activeColor: color,
          inactiveColor: Colors.grey.shade800,
          onChanged: (value) {
            setState(() {
              _eqValues[key] = value;
              _currentEqPreset = 'Custom';
            });
            setModalState(() {});
            _applyEqualizer();
          },
        ),
      ],
    );
  }

  // ===== QUEUE MANAGEMENT =====
  void _clearQueue() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
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
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
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
          const SnackBar(content: Text('⏰ Sleep timer stopped playback'), backgroundColor: Colors.orange),
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
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Sleep Timer', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSleepTimerOption(15),
            _buildSleepTimerOption(30),
            _buildSleepTimerOption(60),
            _buildSleepTimerOption(90),
            if (_sleepTimerActive)
              ListTile(
                leading: const Icon(Icons.stop, color: Colors.red),
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

  Widget _buildSleepTimerOption(int minutes) {
    return ListTile(
      leading: const Icon(Icons.timer, color: Colors.purpleAccent),
      title: Text('$minutes minutes', style: const TextStyle(color: Colors.white)),
      trailing: _sleepTimerActive && _sleepTimerMinutes == minutes
          ? const Icon(Icons.check_circle, color: Colors.green)
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
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Create Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
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
            child: const Text('Create', style: TextStyle(color: Colors.purpleAccent)),
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
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
        await _audioPlayer.setVolume(_volume);
        await _audioPlayer.setBalance(is3DMode ? 0.5 : 0.0);
        _applyEqualizer();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from favorites'), backgroundColor: Colors.grey, duration: Duration(seconds: 1)),
        );
      } else {
        _favorites.add(song);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to favorites ❤️'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
        );
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

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    bool isActive = false,
    Color activeColor = Colors.purple,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.15) : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? activeColor : Colors.grey.shade700, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? activeColor : Colors.white54, size: 16),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: isActive ? activeColor : Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ===== BODY CONTENT =====
  Widget _buildBodyContent() {
    if (_selectedIndex == 1) {
      return _favorites.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 60, color: Colors.white24),
                  SizedBox(height: 10),
                  Text('No favorite songs yet', style: TextStyle(color: Colors.white54)),
                  SizedBox(height: 5),
                  Text('Tap ♡ on any song to add', style: TextStyle(color: Colors.white24, fontSize: 12)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _favorites.length,
              itemBuilder: (context, index) {
                final song = _favorites[index];
                String cleanName = _cleanSongName(song.name);
                Color songColor = _getSongColor(index);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: songColor,
                    child: Text(cleanName.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  title: Text(cleanName, style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    onPressed: () => setState(() => _favorites.remove(song)),
                  ),
                  onTap: () => _playSpecificSong(song),
                );
              },
            );
    } else if (_selectedIndex == 2) {
      return _recent.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: Colors.white24),
                  SizedBox(height: 10),
                  Text('No recent songs', style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _recent.length,
              itemBuilder: (context, index) {
                final song = _recent[index];
                String cleanName = _cleanSongName(song.name);
                Color songColor = _getSongColor(index);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: songColor,
                    child: Text(cleanName.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  title: Text(cleanName, style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text('${index + 1}', style: const TextStyle(color: Colors.white24, fontSize: 12)),
                  onTap: () => _playSpecificSong(song),
                );
              },
            );
    } else if (_selectedIndex == 3) {
      return _buildCustomPlaylistsTab();
    }

    return _buildPlayerUI();
  }

  // ===== CUSTOM PLAYLISTS TAB =====
  Widget _buildCustomPlaylistsTab() {
    if (_customPlaylists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.playlist_play, size: 60, color: Colors.white24),
            const SizedBox(height: 10),
            const Text('No playlists yet', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 5),
            const Text('Create your first playlist', style: TextStyle(color: Colors.white24, fontSize: 12)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showCreatePlaylistDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Playlist'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _customPlaylists.keys.length,
      itemBuilder: (context, index) {
        final playlistName = _customPlaylists.keys.elementAt(index);
        final songs = _customPlaylists[playlistName]!;
        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            title: Text(playlistName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('${songs.length} songs', style: const TextStyle(color: Colors.white54)),
            leading: const Icon(Icons.playlist_play, color: Colors.purpleAccent),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => setState(() => _customPlaylists.remove(playlistName)),
                ),
              ],
            ),
            children: songs.isEmpty
                ? [const Padding(padding: EdgeInsets.all(16), child: Text('No songs in this playlist', style: TextStyle(color: Colors.white54)))]
                : songs.map((song) {
                    return ListTile(
                      title: Text(_cleanSongName(song.name), style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => _removeFromPlaylist(playlistName, song),
                      ),
                      onTap: () => _playSpecificSong(song),
                    );
                  }).toList(),
          ),
        );
      },
    );
  }

  // ===== PLAYER UI - NEW LAYOUT =====
  Widget _buildPlayerUI() {
    String currentSongName = _playlist.isNotEmpty ? _cleanSongName(_playlist[_currentIndex].name) : "No song selected";
    bool isCurrentFavorite = _playlist.isNotEmpty && _favorites.contains(_playlist[_currentIndex]);
    bool hasSongs = _playlist.isNotEmpty;
    bool isEqActive = _currentEqPreset != 'Normal';
    Color currentColor = hasSongs ? _getSongColor(_currentIndex) : Colors.purple;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 1),
            
            // ===== TOP ROW: FAVORITE & EQ CHIPS (Arrow wali jagah) =====
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Favorite Button
                GestureDetector(
                  onTap: hasSongs ? () => _toggleFavorite(_playlist[_currentIndex]) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrentFavorite ? Colors.red.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrentFavorite ? Colors.redAccent : Colors.grey.shade700,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCurrentFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isCurrentFavorite ? Colors.redAccent : Colors.white54,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCurrentFavorite ? '❤️' : 'Add Fav',
                          style: TextStyle(
                            color: isCurrentFavorite ? Colors.redAccent : Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // EQ Button
                GestureDetector(
                  onTap: () => _showEqualizerDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isEqActive ? Colors.blue.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isEqActive ? Colors.blue : Colors.grey.shade700,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.equalizer,
                          color: isEqActive ? Colors.blue : Colors.white54,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isEqActive ? _currentEqPreset : 'EQ',
                          style: TextStyle(
                            color: isEqActive ? Colors.blue : Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // ===== ALBUM ART with Song Color =====
            AnimatedBuilder(
              animation: _pulseController,
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
                          gradient: LinearGradient(
                            colors: [currentColor, currentColor.withOpacity(0.6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: is3DMode ? currentColor.withOpacity(0.5) : Colors.black.withOpacity(0.3),
                              blurRadius: is3DMode ? 50 : 20,
                              spreadRadius: is3DMode ? 10 : 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: hasSongs
                              ? Text(
                                  _cleanSongName(_playlist[_currentIndex].name).substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 60,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.music_note_rounded,
                                  size: 80,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                      // Sleep Timer Indicator
                      if (_sleepTimerActive)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.timer, color: Colors.white, size: 16),
                          ),
                        ),
                      // Play Indicator
                      if (isPlaying)
                        Positioned(
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.play_arrow, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('Playing', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            
            const SizedBox(height: 20),
            
            // ===== SONG NAME =====
            Text(
              currentSongName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 4),
            
            Text(
              hasSongs ? "Song ${_currentIndex + 1} of ${_playlist.length}" : "No songs",
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // ===== PROGRESS BAR =====
            Slider(
              activeColor: currentColor,
              inactiveColor: Colors.grey.shade800,
              min: 0.0,
              max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
              value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0),
              onChanged: (value) async {
                final position = Duration(seconds: value.toInt());
                await _audioPlayer.seek(position);
                setState(() => _position = position);
              },
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(_position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            
            const SizedBox(height: 10),
            
            // ===== PLAYBACK CONTROLS =====
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(repeatMode == 1 ? Icons.repeat_one : (repeatMode == 2 ? Icons.repeat : Icons.repeat_outlined),
                      color: repeatMode > 0 ? currentColor : Colors.white54, size: 22),
                    onPressed: () => setState(() => repeatMode = (repeatMode + 1) % 3),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white, size: 28),
                    onPressed: hasSongs ? _playPreviousSong : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.replay_10, color: Colors.white70, size: 24),
                    onPressed: hasSongs ? () => _seekRelative(-10) : null,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [currentColor, currentColor.withOpacity(0.7)]),
                      boxShadow: [BoxShadow(color: currentColor.withOpacity(0.4), blurRadius: 15, spreadRadius: 3)],
                    ),
                    child: IconButton(
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                      iconSize: 32,
                      onPressed: _togglePlayPause,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_10, color: Colors.white70, size: 24),
                    onPressed: hasSongs ? () => _seekRelative(10) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white, size: 28),
                    onPressed: hasSongs ? _playNextSong : null,
                  ),
                  IconButton(
                    icon: Icon(isShuffle ? Icons.shuffle : Icons.shuffle_outlined,
                      color: isShuffle ? currentColor : Colors.white54, size: 22),
                    onPressed: () => setState(() => isShuffle = !isShuffle),
                  ),
                ],
              ),
            ),
            
            const Spacer(flex: 1),
            
            // ===== BOTTOM ROW: 3D, VOLUME, TIMER =====
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 3D
                  _buildActionChip(
                    icon: Icons.spatial_audio,
                    label: '3D',
                    isActive: is3DMode,
                    activeColor: currentColor,
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
                  
                  const SizedBox(width: 8),
                  
                  // Volume
                  _buildActionChip(
                    icon: Icons.volume_up,
                    label: '${(_volume * 100).toInt()}%',
                    isActive: false,
                    onTap: () => _showVolumePopup(context),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Timer
                  _buildActionChip(
                    icon: Icons.timer,
                    label: _sleepTimerActive ? '${_sleepTimerMinutes}m' : 'Timer',
                    isActive: _sleepTimerActive,
                    activeColor: Colors.orange,
                    onTap: () => _showSleepTimerDialog(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== VOLUME POPUP =====
  void _showVolumePopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              height: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Volume', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.volume_down, color: Colors.white54),
                      Expanded(
                        child: Slider(
                          activeColor: Colors.purpleAccent,
                          inactiveColor: Colors.grey.shade800,
                          min: 0.0,
                          max: 1.0,
                          value: _volume,
                          onChanged: (value) async {
                            setModalState(() => _volume = value);
                            setState(() => _volume = value);
                            await _audioPlayer.setVolume(value);
                            _applyEqualizer();
                          },
                        ),
                      ),
                      const Icon(Icons.volume_up, color: Colors.white54),
                    ],
                  ),
                  Center(
                    child: Text('${(_volume * 100).toInt()}%',
                      style: const TextStyle(color: Colors.purpleAccent, fontSize: 16, fontWeight: FontWeight.bold),
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

  // ===== QUEUE BOTTOM SHEET =====
  void _showQueueBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                          const Text('Queue', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purpleAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('${_playlist.length}', style: const TextStyle(color: Colors.purpleAccent, fontSize: 12)),
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
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.grey)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.purpleAccent)),
                    ),
                    onChanged: (value) => setModalState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 10),
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
                              Color songColor = _getSongColor(originalIndex);
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isCurrent ? Colors.purpleAccent : songColor,
                                  child: Text(
                                    '${originalIndex + 1}',
                                    style: TextStyle(
                                      color: isCurrent ? Colors.white : Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(cleanName,
                                  style: TextStyle(
                                    color: isCurrent ? Colors.purpleAccent : Colors.white,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_favorites.contains(song)) const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                                    const SizedBox(width: 4),
                                    if (isCurrent) const Icon(Icons.play_arrow, color: Colors.purpleAccent),
                                  ],
                                ),
                                onTap: () {
                                  setState(() => _currentIndex = originalIndex);
                                  _playCurrentSongInQueue();
                                  Navigator.pop(context);
                                },
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
      case 1: return 'Favorites ❤️';
      case 2: return 'Recent 🕐';
      case 3: return 'Playlists 📁';
      default: return 'My Music 3D';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selectedIndex == 0) ...[
              const Icon(Icons.music_note, color: Colors.purpleAccent, size: 22),
              const SizedBox(width: 8),
            ],
            Text(_getAppBarTitle(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
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
            color: const Color(0xFF1E293B),
            onSelected: (value) {
              if (value == 'clear') {
                _clearQueue();
              } else if (value == 'reset_eq') {
                _resetEqualizer();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Equalizer reset to Normal'), backgroundColor: Colors.grey),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
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
      ),
      body: _buildBodyContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: Colors.purpleAccent,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        onTap: (index) => setState(() => _selectedIndex = index),
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
