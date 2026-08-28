import 'dart:io';
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
  int repeatMode = 0; // 0: Off, 1: Repeat One, 2: Repeat All
  
  List<PlatformFile> _playlist = [];
  final List<PlatformFile> _favorites = [];
  final List<PlatformFile> _recent = [];
  int _currentIndex = 0;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() => _duration = newDuration);
    });
    
    _audioPlayer.onPositionChanged.listen((newPosition) {
      setState(() => _position = newPosition);
    });
    
    _audioPlayer.onPlayerComplete.listen((_) {
      _handleSongCompletion();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _handleSongCompletion() {
    if (repeatMode == 1) {
      // Repeat One
      _playCurrentSongInQueue();
    } else if (repeatMode == 2) {
      // Repeat All
      _playNextSong();
    } else {
      // No Repeat
      if (_currentIndex < _playlist.length - 1) {
        _playNextSong();
      } else {
        setState(() => isPlaying = false);
      }
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.files.length} songs added to queue'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking songs: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
        setState(() => isPlaying = true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error playing song: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _playSpecificSong(PlatformFile song) async {
    int index = _playlist.indexOf(song);
    if (index != -1) {
      setState(() => _currentIndex = index);
      await _playCurrentSongInQueue();
    } else {
      setState(() {
        _playlist.add(song);
        _currentIndex = _playlist.length - 1;
      });
      await _playCurrentSongInQueue();
    }
  }

  Future<void> _playNextSong() async {
    if (_playlist.isEmpty) return;
    
    if (isShuffle) {
      int newIndex;
      do {
        newIndex = DateTime.now().millisecondsSinceEpoch % _playlist.length;
      } while (newIndex == _currentIndex && _playlist.length > 1);
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
        setState(() => isPlaying = false);
      } else {
        await _audioPlayer.resume();
        setState(() => isPlaying = true);
      }
    } catch (e) {
      print('Error toggling play/pause: $e');
    }
  }

  Future<void> _seekRelative(int seconds) async {
    final newPosition = _position + Duration(seconds: seconds);
    await _audioPlayer.seek(newPosition.clamp(Duration.zero, _duration));
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
          const SnackBar(content: Text('Removed from favorites'), backgroundColor: Colors.grey),
        );
      } else {
        _favorites.add(song);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to favorites ❤️'), backgroundColor: Colors.red),
        );
      }
    });
  }

  void _clearQueue() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Clear Queue?', style: TextStyle(color: Colors.white)),
        content: const Text('This will remove all songs from the queue.', style: TextStyle(color: Colors.white70)),
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
                _duration = Duration.zero;
                _position = Duration.zero;
                isPlaying = false;
              });
              _audioPlayer.stop();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Queue cleared'), backgroundColor: Colors.orange),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showQueueBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
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
                            'Playback Queue',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purpleAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_playlist.length}',
                              style: const TextStyle(color: Colors.purpleAccent, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.clear_all, color: Colors.white70, size: 20),
                            onPressed: _clearQueue,
                            tooltip: 'Clear Queue',
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
                  Expanded(
                    child: _playlist.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.queue_music, size: 50, color: Colors.white24),
                                SizedBox(height: 10),
                                Text('Queue is empty', style: TextStyle(color: Colors.white54)),
                                SizedBox(height: 5),
                                Text('Add songs using the + button', style: TextStyle(color: Colors.white24, fontSize: 12)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _playlist.length,
                            itemBuilder: (context, index) {
                              bool isCurrent = index == _currentIndex;
                              return Dismissible(
                                key: Key(_playlist[index].path ?? ''),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: Colors.red,
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                onDismissed: (direction) {
                                  setState(() {
                                    _playlist.removeAt(index);
                                    if (_currentIndex >= _playlist.length) {
                                      _currentIndex = _playlist.length - 1;
                                    } else if (_currentIndex > index) {
                                      _currentIndex--;
                                    }
                                  });
                                },
                                child: ListTile(
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: isCurrent ? Colors.purpleAccent : Colors.grey.shade800,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: isCurrent ? Colors.white : Colors.white54,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    _playlist[index].name,
                                    style: TextStyle(
                                      color: isCurrent ? Colors.purpleAccent : Colors.white,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: isCurrent
                                      ? const Icon(Icons.play_arrow, color: Colors.purpleAccent)
                                      : null,
                                  onTap: () {
                                    setState(() => _currentIndex = index);
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

  Widget _buildBodyContent() {
    if (_selectedIndex == 1) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: const Text('Favorites ❤️', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            if (_favorites.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.white54),
                onPressed: () {
                  setState(() => _favorites.clear());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Favorites cleared'), backgroundColor: Colors.orange),
                  );
                },
              ),
          ],
        ),
        body: _favorites.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border, size: 60, color: Colors.white24),
                    SizedBox(height: 10),
                    Text('No favorite songs yet', style: TextStyle(color: Colors.white54)),
                    SizedBox(height: 5),
                    Text('Add songs by tapping the heart icon', style: TextStyle(color: Colors.white24, fontSize: 12)),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: _favorites.length,
                itemBuilder: (context, index) {
                  final song = _favorites[index];
                  return ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.redAccent),
                    title: Text(song.name, style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                      onPressed: () {
                        setState(() => _favorites.remove(song));
                      },
                    ),
                    onTap: () => _playSpecificSong(song),
                  );
                },
              ),
      );
    } else if (_selectedIndex == 2) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: const Text('Recent Played 🕐', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            if (_recent.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.white54),
                onPressed: () {
                  setState(() => _recent.clear());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('History cleared'), backgroundColor: Colors.orange),
                  );
                },
              ),
          ],
        ),
        body: _recent.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 60, color: Colors.white24),
                    SizedBox(height: 10),
                    Text('No recent songs', style: TextStyle(color: Colors.white54)),
                    SizedBox(height: 5),
                    Text('Play some songs to see them here', style: TextStyle(color: Colors.white24, fontSize: 12)),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: _recent.length,
                itemBuilder: (context, index) {
                  final song = _recent[index];
                  return ListTile(
                    leading: const Icon(Icons.history, color: Colors.purpleAccent),
                    title: Text(song.name, style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(
                      '${index + 1}',
                      style: TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                    onTap: () => _playSpecificSong(song),
                  );
                },
              ),
      );
    } else if (_selectedIndex == 3) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: const Text('Playlists 📁', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Card(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.playlist_play, color: Colors.purpleAccent, size: 30),
                  title: const Text('Current Queue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('${_playlist.length} Songs', style: const TextStyle(color: Colors.white70)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                  onTap: () => _showQueueBottomSheet(context),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.favorite, color: Colors.redAccent, size: 30),
                  title: const Text('Favorites', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('${_favorites.length} Songs', style: const TextStyle(color: Colors.white70)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                  onTap: () {
                    setState(() => _selectedIndex = 1);
                  },
                ),
              ),
              const SizedBox(height: 10),
              Card(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.history, color: Colors.purpleAccent, size: 30),
                  title: const Text('Recent Played', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('${_recent.length} Songs', style: const TextStyle(color: Colors.white70)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                  onTap: () {
                    setState(() => _selectedIndex = 2);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default Tab: Player Screen
    String currentSongName = _playlist.isNotEmpty ? _playlist[_currentIndex].name : "No song selected";
    bool isCurrentFavorite = _playlist.isNotEmpty && _favorites.contains(_playlist[_currentIndex]);
    bool hasSongs = _playlist.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: is3DMode
                        ? [const Color(0xFF1E293B), Colors.purple.shade900.withOpacity(0.3)]
                        : [const Color(0xFF1E293B), const Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: is3DMode ? Colors.purpleAccent.withOpacity(0.4) : Colors.black.withOpacity(0.3),
                      blurRadius: is3DMode ? 35 : 15,
                      spreadRadius: is3DMode ? 6 : 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            isShuffle ? Icons.shuffle : Icons.shuffle_outlined,
                            color: isShuffle ? Colors.purpleAccent : Colors.white54,
                          ),
                          onPressed: () => setState(() => isShuffle = !isShuffle),
                          tooltip: 'Shuffle',
                        ),
                        IconButton(
                          icon: Icon(
                            isCurrentFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isCurrentFavorite ? Colors.redAccent : Colors.white70,
                          ),
                          onPressed: hasSongs ? () => _toggleFavorite(_playlist[_currentIndex]) : null,
                        ),
                      ],
                    ),
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: isPlaying ? _pulseAnimation.value : 1.0,
                          child: Container(
                            height: 120,
                            width: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Colors.deepPurple, Colors.purpleAccent],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: is3DMode ? Colors.purpleAccent.withOpacity(0.8) : Colors.transparent,
                                  blurRadius: 25,
                                  spreadRadius: is3DMode ? 8 : 0,
                                ),
                              ],
                            ),
                            child: Icon(
                              isPlaying ? Icons.music_note_rounded : Icons.music_off_rounded,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 15),
                    Text(
                      currentSongName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasSongs ? "Song ${_currentIndex + 1} of ${_playlist.length}" : "Tap + to add songs",
                      style: TextStyle(fontSize: 12, color: Colors.purple.shade200),
                    ),
                    if (is3DMode)
                      const SizedBox(height: 4),
                    if (is3DMode)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '🎧 3D Spatial Sound',
                          style: TextStyle(color: Colors.purpleAccent, fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      '3D Spatial Sound',
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    value: is3DMode,
                    activeColor: Colors.purpleAccent,
                    onChanged: (val) async {
                      setState(() => is3DMode = val);
                      if (is3DMode) {
                        await _audioPlayer.setBalance(0.5);
                        await _audioPlayer.setVolume(0.9);
                      } else {
                        await _audioPlayer.setBalance(0.0);
                        await _audioPlayer.setVolume(_volume);
                      }
                    },
                  ),
                  Row(
                    children: [
                      const Icon(Icons.volume_up, color: Colors.white54, size: 20),
                      Expanded(
                        child: Slider(
                          activeColor: Colors.purpleAccent,
                          inactiveColor: Colors.grey.shade800,
                          min: 0.0,
                          max: 1.0,
                          value: _volume,
                          onChanged: (value) async {
                            setState(() => _volume = value);
                            await _audioPlayer.setVolume(value);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  repeatMode == 1 ? Icons.repeat_one : (repeatMode == 2 ? Icons.repeat : Icons.repeat_outlined),
                  color: repeatMode > 0 ? Colors.purpleAccent : Colors.white54,
                ),
                onPressed: () => setState(() => repeatMode = (repeatMode + 1) % 3),
                tooltip: 'Repeat: ${repeatMode == 0 ? "Off" : (repeatMode == 1 ? "One" : "All")}',
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white, size: 28),
                onPressed: hasSongs ? _playPreviousSong : null,
              ),
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white70, size: 24),
                onPressed: hasSongs ? () => _seekRelative(-10) : null,
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.deepPurpleAccent,
                child: IconButton(
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                  iconSize: 32,
                  onPressed: _togglePlayPause,
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white70, size: 24),
                onPressed: hasSongs ? () => _seekRelative(10) : null,
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white, size: 28),
                onPressed: hasSongs ? _playNextSong : null,
              ),
              IconButton(
                icon: const Icon(Icons.queue_music, color: Colors.white54),
                onPressed: () => _showQueueBottomSheet(context),
                tooltip: 'View Queue',
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _pickSongs,
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('Add Songs'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 10),
              if (hasSongs)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _playlist.clear();
                      _currentIndex = 0;
                      isPlaying = false;
                    });
                    _audioPlayer.stop();
                  },
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: _selectedIndex == 0
          ? AppBar(
              title: const Text('🎵 My Music 3D', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.queue_music, color: Colors.white),
                  onPressed: () => _showQueueBottomSheet(context),
                  tooltip: 'View Queue',
                ),
              ],
            )
          : null,
      body: _buildBodyContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: Colors.purpleAccent,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        onTap: (index) {
          setState(() => _selectedIndex = index);
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
            icon: Icon(Icons.library_music),
            label: 'Playlists',
          ),
        ],
      ),
    );
  }
}
