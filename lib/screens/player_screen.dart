import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  int _selectedIndex = 0; // Bottom bar index for switching tabs

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  bool is3DMode = false;

  List<PlatformFile> _playlist = [];
  final List<PlatformFile> _favorites = [];
  final List<PlatformFile> _recent = [];
  int _currentIndex = 0;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() => _duration = newDuration);
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      setState(() => _position = newPosition);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      _playNextSong();
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickSongs() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _playlist = result.files;
        _currentIndex = 0;
      });
      _playCurrentSongInQueue();
    }
  }

  Future<void> _playCurrentSongInQueue() async {
    if (_playlist.isEmpty) return;
    final currentFile = _playlist[_currentIndex];
    
    // Add to Recent list if not already present at top
    if (!_recent.contains(currentFile)) {
      _recent.insert(0, currentFile);
    }

    if (currentFile.path != null) {
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(currentFile.path!));
      await _audioPlayer.setVolume(_volume);

      if (is3DMode) {
        await _audioPlayer.setBalance(0.5);
      }
      setState(() => isPlaying = true);
    }
  }

  Future<void> _playSpecificSong(PlatformFile song) async {
    int index = _playlist.indexOf(song);
    if (index != -1) {
      setState(() {
        _currentIndex = index;
      });
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
    setState(() {
      _currentIndex = (_currentIndex + 1) % _playlist.length;
    });
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
    if (_playlist.isEmpty) return;
    if (isPlaying) {
      await _audioPlayer.pause();
      setState(() => isPlaying = false);
    } else {
      await _audioPlayer.resume();
      setState(() => isPlaying = true);
    }
  }

  Future<void> _seekRelative(int seconds) async {
    final newPosition = _position + Duration(seconds: seconds);
    await _audioPlayer.seek(newPosition);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
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

  // Queue Bottom Sheet
  void _showQueueBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Playback Queue', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: _playlist.isEmpty
                    ? const Center(child: Text('Queue is empty', style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        itemCount: _playlist.length,
                        itemBuilder: (context, index) {
                          bool isCurrent = index == _currentIndex;
                          return ListTile(
                            leading: Icon(isCurrent ? Icons.play_arrow : Icons.music_note, color: isCurrent ? Colors.purpleAccent : Colors.white70),
                            title: Text(_playlist[index].name, style: TextStyle(color: isCurrent ? Colors.purpleAccent : Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () {
                              setState(() => _currentIndex = index);
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
  }

  // Body content based on Bottom Navigation Tab
  Widget _buildBodyContent() {
    if (_selectedIndex == 1) {
      // Favorites Tab
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(title: const Text('Favorites', style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, elevation: 0),
        body: _favorites.isEmpty
            ? const Center(child: Text('No favorite songs yet', style: TextStyle(color: Colors.white54)))
            : ListView.builder(
                itemCount: _favorites.length,
                itemBuilder: (context, index) {
                  final song = _favorites[index];
                  return ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.redAccent),
                    title: Text(song.name, style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => _playSpecificSong(song),
                  );
                },
              ),
      );
    } else if (_selectedIndex == 2) {
      // Recent Tab
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(title: const Text('Recent Played', style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, elevation: 0),
        body: _recent.isEmpty
            ? const Center(child: Text('No recent songs', style: TextStyle(color: Colors.white54)))
            : ListView.builder(
                itemCount: _recent.length,
                itemBuilder: (context, index) {
                  final song = _recent[index];
                  return ListTile(
                    leading: const Icon(Icons.history, color: Colors.purpleAccent),
                    title: Text(song.name, style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => _playSpecificSong(song),
                  );
                },
              ),
      );
    } else if (_selectedIndex == 3) {
      // Playlists / Folders Tab
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(title: const Text('Playlists', style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, elevation: 0),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Card(
                color: const Color(0xFF1E293B),
                child: ListTile(
                  leading: const Icon(Icons.playlist_play, color: Colors.purpleAccent, size: 30),
                  title: const Text('Custom Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('${_playlist.length} Songs in Queue', style: const TextStyle(color: Colors.white70)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                  onTap: () => _showQueueBottomSheet(context),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
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
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            isCurrentFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isCurrentFavorite ? Colors.redAccent : Colors.white70,
                          ),
                          onPressed: _playlist.isNotEmpty ? () => _toggleFavorite(_playlist[_currentIndex]) : null,
                        ),
                      ],
                    ),
                    Container(
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
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.music_note_rounded, size: 60, color: Colors.white),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      currentSongName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _playlist.isNotEmpty ? "Song ${_currentIndex + 1} of ${_playlist.length}" : "Queue empty",
                      style: TextStyle(fontSize: 12, color: Colors.purple.shade200),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SwitchListTile(
              title: const Text('3D Spatial Sound Effect', style: TextStyle(fontSize: 14, color: Colors.white)),
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
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white, size: 28),
                onPressed: _playlist.isNotEmpty ? _playPreviousSong : null,
              ),
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white70, size: 24),
                onPressed: () => _seekRelative(-10),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.deepPurpleAccent,
                child: IconButton(
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                  iconSize: 30,
                  onPressed: _togglePlayPause,
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white70, size: 24),
                onPressed: () => _seekRelative(10),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white, size: 28),
                onPressed: _playlist.isNotEmpty ? _playNextSong : null,
              ),
            ],
          ),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: _pickSongs,
            icon: const Icon(Icons.playlist_add),
            label: const Text('Add Songs to Queue'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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
              title: const Text('My Music 3D', style: TextStyle(color: Colors.white)),
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
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.play_circle_filled), label: 'Player'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Recent'),
          BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Playlists'),
        ],
      ),
    );
  }
}
