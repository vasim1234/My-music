import 'dart:io';
import 'dart:async'; // Added for Timer
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:marquee/marquee.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

// ============================================================
// 1. AUDIO SERVICE FOR BACKGROUND PLAYBACK
// ============================================================
class AudioPlayerTask extends BackgroundAudioTask {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  Future<void> onStart(Map<String, dynamic>? params) async {
    await _setupMediaItem();
  }

  Future<void> _setupMediaItem() async {
    final mediaItem = const MediaItem(
      id: 'current_song',
      album: 'My Music 3D',
      title: 'Song Playing',
      artist: 'Local Audio',
      duration: Duration.zero,
    );
    AudioService.setMediaItem(mediaItem);
    AudioService.setPlaybackState(
      const PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.pause,
          MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: {
          MediaAction.seekTo,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
      ),
    );
  }

  @override
  Future<void> onPlay() async {
    _playing = true;
    await _player.resume();
    AudioService.setPlaybackState(
      const PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.pause,
          MediaControl.skipToNext,
        ],
      ),
    );
  }

  @override
  Future<void> onPause() async {
    _playing = false;
    await _player.pause();
    AudioService.setPlaybackState(
      const PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.skipToNext,
        ],
      ),
    );
  }

  @override
  Future<void> onSkipToNext() async {}

  @override
  Future<void> onSkipToPrevious() async {}

  @override
  Future<void> onStop() async {
    await _player.stop();
    await super.onStop();
  }
}

// ============================================================
// 2. MAIN PLAYER SCREEN WITH ALL FEATURES
// ============================================================
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  // ===== STATE VARIABLES =====
  int _selectedIndex = 0;
  
  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  bool is3DMode = false;
  bool isShuffle = false;
  int repeatMode = 0;
  
  // Playlist
  final List<PlatformFile> _playlist = [];
  final List<PlatformFile> _favorites = [];
  final List<PlatformFile> _recent = [];
  int _currentIndex = 0;
  
  // Duration
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0;
  
  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // ===== NEW FEATURES VARIABLES =====
  // 1. Search
  String _searchQuery = '';
  
  // 2. Device Music
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<SongModel> _deviceSongs = [];
  bool _isLoadingDeviceSongs = false;
  
  // 3. Custom Playlists
  final Map<String, List<PlatformFile>> _customPlaylists = {};
  String _newPlaylistName = '';
  
  // 4. Sleep Timer
  bool _sleepTimerActive = false;
  int _sleepTimerMinutes = 0;
  Timer? _sleepTimer;
  
  // 5. Equalizer Presets
  final Map<String, Map<String, double>> _eqPresets = {
    'Normal': {'bass': 0.0, 'treble': 0.0, 'mid': 0.0},
    'Bass Boost': {'bass': 0.8, 'treble': -0.2, 'mid': 0.0},
    'Treble Boost': {'bass': -0.2, 'treble': 0.8, 'mid': 0.0},
    'Pop': {'bass': 0.3, 'treble': 0.4, 'mid': 0.0},
    'Rock': {'bass': 0.5, 'treble': 0.3, 'mid': 0.2},
    'Classical': {'bass': -0.3, 'treble': 0.6, 'mid': 0.1},
    'Jazz': {'bass': 0.4, 'treble': -0.1, 'mid': 0.2},
  };
  String _currentEqPreset = 'Normal';
  Map<String, double> _eqValues = {'bass': 0.0, 'treble': 0.0, 'mid': 0.0};

  // ============================================================
  // 3. HELPER FUNCTIONS
  // ============================================================
  String _cleanSongName(String fileName) {
    String name = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    name = name.replaceAll(RegExp(r'\(\w*_\d+K\)', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\(\d+K\)', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\(MP3_\d+K\)', caseSensitive: false), '');
    name = name.trim();
    return name;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final hours = duration.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  // ============================================================
  // 4. DEVICE MUSIC SCANNING
  // ============================================================
  Future<void> _scanDeviceMusic() async {
    setState(() => _isLoadingDeviceSongs = true);
    try {
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      if (mounted) {
        setState(() {
          _deviceSongs = songs;
          _isLoadingDeviceSongs = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDeviceSongs = false);
    }
  }

  // ============================================================
  // 5. CUSTOM PLAYLIST FUNCTIONS
  // ============================================================
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

  // ============================================================
  // 6. SLEEP TIMER
  // ============================================================
  void _startSleepTimer(int minutes) {
    setState(() {
      _sleepTimerActive = true;
      _sleepTimerMinutes = minutes;
    });
    
    _sleepTimer?.cancel();
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      if (mounted) {
        setState(() {
          _sleepTimerActive = false;
          _sleepTimerMinutes = 0;
          isPlaying = false;
        });
        _audioPlayer.stop();
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

  // ============================================================
  // 7. EQUALIZER
  // ============================================================
  void _showEqualizerDialog() {
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
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Equalizer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  Wrap(
                    spacing: 8,
                    children: _eqPresets.keys.map((preset) {
                      return FilterChip(
                        label: Text(preset, style: const TextStyle(color: Colors.white)),
                        selected: _currentEqPreset == preset,
                        selectedColor: Colors.purpleAccent.withOpacity(0.3),
                        backgroundColor: Colors.grey.shade800,
                        onSelected: (selected) {
                          setState(() {
                            _currentEqPreset = preset;
                            _eqValues = Map.from(_eqPresets[preset]!);
                          });
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  _buildEqSlider('Bass', 'bass', setModalState),
                  _buildEqSlider('Treble', 'treble', setModalState),
                  _buildEqSlider('Mid', 'mid', setModalState),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEqSlider(String label, String key, Function setModalState) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text('${(_eqValues[key]! * 10).toInt()} dB', style: const TextStyle(color: Colors.purpleAccent)),
          ],
        ),
        Slider(
          value: _eqValues[key]!,
          min: -1.0,
          max: 1.0,
          activeColor: Colors.purpleAccent,
          inactiveColor: Colors.grey.shade800,
          onChanged: (value) {
            setState(() {
              _eqValues[key] = value;
              _currentEqPreset = 'Custom';
            });
            setModalState(() {});
          },
        ),
      ],
    );
  }

  // ============================================================
  // 8. SEARCH FUNCTION
  // ============================================================
  List<PlatformFile> _getFilteredSongs() {
    if (_searchQuery.isEmpty) return _playlist;
    return _playlist.where((song) =>
      _cleanSongName(song.name).toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  // ============================================================
  // 9. AUDIO PLAYBACK FUNCTIONS
  // ============================================================
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

    _scanDeviceMusic();
  }

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
            SnackBar(content: Text('${result.files.length} songs added'), backgroundColor: Colors.green, duration: const Duration(seconds: 1)),
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
    final clampedPosition = newPosition > _duration ? _duration : (newPosition < Duration.zero ? Duration.zero : newPosition);
    await _audioPlayer.seek(clampedPosition);
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
                          },
                        ),
                      ),
                      const Icon(Icons.volume_up, color: Colors.white54),
                    ],
                  ),
                  Center(
                    child: Text('${(_volume * 100).toInt()}%', style: const TextStyle(color: Colors.purpleAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

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
                            decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                            child: Text('${_playlist.length}', style: const TextStyle(color: Colors.purpleAccent, fontSize: 12)),
                          ),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
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
                    onChanged: (value) {
                      setModalState(() => _searchQuery = value);
                    },
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
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isCurrent ? Colors.purpleAccent : Colors.grey.shade800,
                                  child: Text('${originalIndex + 1}', style: TextStyle(color: isCurrent ? Colors.white : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                                title: Text(cleanName, style: TextStyle(color: isCurrent ? Colors.purpleAccent : Colors.white, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal), maxLines: 1, overflow: TextOverflow.ellipsis),
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

  // ============================================================
  // 10. UI BUILDERS
  // ============================================================
  Widget _buildDeviceMusicTab() {
    return Column(
      children: [
        if (_isLoadingDeviceSongs)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.purpleAccent)))
        else if (_deviceSongs.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.audio_file, size: 60, color: Colors.white24),
                  SizedBox(height: 10),
                  Text('No songs found on device', style: TextStyle(color: Colors.white54)),
                  SizedBox(height: 5),
                  Text('Tap refresh to scan again', style: TextStyle(color: Colors.white24, fontSize: 12)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _deviceSongs.length,
              itemBuilder: (context, index) {
                final song = _deviceSongs[index];
                return ListTile(
                  leading: QueryArtworkWidget(
                    id: song.id,
                    type: ArtworkType.AUDIO,
                    nullArtworkWidget: CircleAvatar(backgroundColor: Colors.grey.shade800, child: const Icon(Icons.music_note, color: Colors.white54)),
                  ),
                  title: Text(song.title, style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(song.artist ?? 'Unknown Artist', style: const TextStyle(color: Colors.white54), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: PopupMenuButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                    color: const Color(0xFF1E293B),
                    onSelected: (value) {
                      if (value == 'add') {
                        final file = PlatformFile(name: song.title, path: song.data, size: 0);
                        setState(() => _playlist.add(file));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to queue'), backgroundColor: Colors.green, duration: Duration(seconds: 1)));
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'add', child: Row(children: [Icon(Icons.playlist_add, color: Colors.white), SizedBox(width: 10), Text('Add to Queue', style: TextStyle(color: Colors.white))])),
                    ],
                  ),
                  onTap: () {
                    final file = PlatformFile(name: song.title, path: song.data, size: 0);
                    _playSpecificSong(file);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white),
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
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setState(() => _customPlaylists.remove(playlistName))),
              ],
            ),
            children: songs.isEmpty
                ? [const Padding(padding: EdgeInsets.all(16), child: Text('No songs in this playlist', style: TextStyle(color: Colors.white54)))]
                : songs.map((song) {
                    return ListTile(
                      title: Text(_cleanSongName(song.name), style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => _removeFromPlaylist(playlistName, song)),
                      onTap: () => _playSpecificSong(song),
                    );
                  }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildPlayerUI() {
    String currentSongName = _playlist.isNotEmpty ? _cleanSongName(_playlist[_currentIndex].name) : "No song selected";
    bool isCurrentFavorite = _playlist.isNotEmpty && _favorites.contains(_playlist[_currentIndex]);
    bool hasSongs = _playlist.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 1),
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: isPlaying ? _pulseAnimation.value : 1.0,
                      child: Container(
                        height: 180,
                        width: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [Colors.deepPurple, Colors.purpleAccent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          boxShadow: [
                            BoxShadow(color: is3DMode ? Colors.purpleAccent.withOpacity(0.4) : Colors.black.withOpacity(0.3), blurRadius: is3DMode ? 40 : 20, spreadRadius: is3DMode ? 8 : 2),
                          ],
                        ),
                        child: Icon(isPlaying ? Icons.music_note_rounded : Icons.music_off_rounded, size: 75, color: Colors.white),
                      ),
                    );
                  },
                ),
                if (_sleepTimerActive)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                      child: const Icon(Icons.timer, color: Colors.white, size: 16),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (currentSongName.length > 30)
              SizedBox(
                height: 30,
                child: Marquee(
                  text: currentSongName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.3),
                  scrollAxis: Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  blankSpace: 40,
                  velocity: 30,
                  pauseAfterRound: const Duration(seconds: 2),
                  startPadding: 10,
                  accelerationDuration: const Duration(seconds: 1),
                  accelerationCurve: Curves.linear,
                  decelerationDuration: const Duration(milliseconds: 500),
                  decelerationCurve: Curves.easeOut,
                ),
              )
            else
              Text(
                currentSongName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 5),
            Text(hasSongs ? "Song ${_currentIndex + 1} of ${_playlist.length}" : "No songs", style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
            const SizedBox(height: 16),
            Slider(
              activeColor: Colors.purpleAccent,
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(icon: Icon(repeatMode == 1 ? Icons.repeat_one : (repeatMode == 2 ? Icons.repeat : Icons.repeat_outlined), color: repeatMode > 0 ? Colors.purpleAccent : Colors.white54, size: 22), onPressed: () => setState(() => repeatMode = (repeatMode + 1) % 3)),
                  IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white, size: 28), onPressed: hasSongs ? _playPreviousSong : null),
                  IconButton(icon: const Icon(Icons.replay_10, color: Colors.white70, size: 24), onPressed: hasSongs ? () => _seekRelative(-10) : null),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Colors.deepPurple, Colors.purpleAccent]), boxShadow: [BoxShadow(color: Colors.purpleAccent.withOpacity(0.4), blurRadius: 15, spreadRadius: 3)]),
                    child: IconButton(icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white), iconSize: 32, onPressed: _togglePlayPause, padding: const EdgeInsets.all(12)),
                  ),
                  IconButton(icon: const Icon(Icons.forward_10, color: Colors.white70, size: 24), onPressed: hasSongs ? () => _seekRelative(10) : null),
                  IconButton(icon: const Icon(Icons.skip_next, color: Colors.white, size: 28), onPressed: hasSongs ? _playNextSong : null),
                  IconButton(icon: Icon(isShuffle ? Icons.shuffle : Icons.shuffle_outlined, color: isShuffle ? Colors.purpleAccent : Colors.white54, size: 22), onPressed: () => setState(() => isShuffle = !isShuffle)),
                ],
              ),
            ),
            const Spacer(flex: 1),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionChip(icon: isCurrentFavorite ? Icons.favorite : Icons.favorite_border, label: isCurrentFavorite ? 'Favorite' : 'Add Fav', isActive: isCurrentFavorite, activeColor: Colors.red, onTap: hasSongs ? () => _toggleFavorite(_playlist[_currentIndex]) : null),
                    const SizedBox(width: 8),
                    _buildActionChip(icon: Icons.spatial_audio, label: '3D', isActive: is3DMode, activeColor: Colors.purple, onTap: () async {
                      setState(() => is3DMode = !is3DMode);
                      if (is3DMode) {
                        await _audioPlayer.setBalance(0.5);
                        await _audioPlayer.setVolume(0.9);
                      } else {
                        await _audioPlayer.setBalance(0.0);
                        await _audioPlayer.setVolume(_volume);
                      }
                    }),
                    const SizedBox(width: 8),
                    _buildActionChip(icon: Icons.volume_up, label: '${(_volume * 100).toInt()}%', isActive: false, onTap: () => _showVolumePopup(context)),
                    const SizedBox(width: 8),
                    _buildActionChip(icon: Icons.equalizer, label: 'EQ', isActive: _currentEqPreset != 'Normal', activeColor: Colors.blue, onTap: () => _showEqualizerDialog()),
                    const SizedBox(width: 8),
                    _buildActionChip(icon: Icons.timer, label: _sleepTimerActive ? '${_sleepTimerMinutes}m' : 'Timer', isActive: _sleepTimerActive, activeColor: Colors.orange, onTap: () => _showSleepTimerDialog()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({required IconData icon, required String label, bool isActive = false, Color activeColor = Colors.purple, VoidCallback? onTap}) {
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

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 1: return 'Favorites ❤️';
      case 2: return 'Recent 🕐';
      case 3: return 'Device Music 📁';
      case 4: return 'Playlists 🎵';
      default: return 'My Music 3D';
    }
  }

  Widget _buildBodyContent() {
    switch (_selectedIndex) {
      case 1:
        return _favorites.isEmpty
            ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.favorite_border, size: 60, color: Colors.white24), SizedBox(height: 10), Text('No favorite songs yet', style: TextStyle(color: Colors.white54))]))
            : ListView.builder(itemCount: _favorites.length, itemBuilder: (context, index) {
                final song = _favorites[index];
                return ListTile(leading: const Icon(Icons.favorite, color: Colors.redAccent), title: Text(_cleanSongName(song.name), style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis), trailing: IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => setState(() => _favorites.remove(song))), onTap: () => _playSpecificSong(song));
              });
      case 2:
        return _recent.isEmpty
            ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history, size: 60, color: Colors.white24), SizedBox(height: 10), Text('No recent songs', style: TextStyle(color: Colors.white54))]))
            : ListView.builder(itemCount: _recent.length, itemBuilder: (context, index) {
                final song = _recent[index];
                return ListTile(leading: const Icon(Icons.history, color: Colors.purpleAccent), title: Text(_cleanSongName(song.name), style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis), trailing: Text('${index + 1}', style: const TextStyle(color: Colors.white24, fontSize: 12)), onTap: () => _playSpecificSong(song));
              });
      case 3:
        return _buildDeviceMusicTab();
      case 4:
        return _buildCustomPlaylistsTab();
      default:
        return _buildPlayerUI();
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
            if (_selectedIndex == 0) ...[const Icon(Icons.music_note, color: Colors.purpleAccent, size: 22), const SizedBox(width: 8)],
            Text(_getAppBarTitle(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add, color: Colors.white70), onPressed: _pickSongs, tooltip: 'Add Songs'),
          IconButton(icon: const Icon(Icons.queue_music, color: Colors.white70), onPressed: () => _showQueueBottomSheet(context), tooltip: 'Queue'),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF1E293B),
            onSelected: (value) {
              if (value == 'clear') _clearQueue();
              else if (value == 'scan') _scanDeviceMusic();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'scan', child: Row(children: [Icon(Icons.refresh, color: Colors.blue, size: 20), SizedBox(width: 10), Text('Scan Device Music', style: TextStyle(color: Colors.white))])),
              const PopupMenuItem(value: 'clear', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 20), SizedBox(width: 10), Text('Clear Queue', style: TextStyle(color: Colors.white))])),
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
          BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'Device'),
          BottomNavigationBarItem(icon: Icon(Icons.playlist_play), label: 'Playlists'),
        ],
      ),
    );
  }
}
