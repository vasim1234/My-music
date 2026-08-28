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
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  bool is3DMode = false;

  // Playlist & Queue Management
  List<PlatformFile> _playlist = [];
  int _currentIndex = 0;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() {
        _duration = newDuration;
      });
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      setState(() {
        _position = newPosition;
      });
    });

    // Song khatam hone par automatically agla song play karne ke liye (Queue auto-advance)
    _audioPlayer.onPlayerComplete.listen((_) {
      _playNextSong();
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // Multiple Songs Pick karne ke liye (Playlist/Queue)
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

  // Queue me se specific index wala song play karne ke liye
  Future<void> _playCurrentSongInQueue() async {
    if (_playlist.isEmpty) return;
    
    final currentFile = _playlist[_currentIndex];
    if (currentFile.path != null) {
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(currentFile.path!));
      await _audioPlayer.setVolume(_volume);

      if (is3DMode) {
        await _audioPlayer.setBalance(0.5);
      }

      setState(() {
        isPlaying = true;
      });
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

  @override
  Widget build(BuildContext context) {
    String currentSongName = _playlist.isNotEmpty 
        ? _playlist[_currentIndex].name 
        : "No song selected";

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('My Music 3D & Queue', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Smooth Animated Card Layout for Player Art
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: is3DMode 
                        ? Colors.purpleAccent.withOpacity(0.4) 
                        : Colors.black.withOpacity(0.3),
                    blurRadius: is3DMode ? 30 : 15,
                    spreadRadius: is3DMode ? 5 : 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: 130,
                    width: 130,
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
                  const SizedBox(height: 16),
                  Text(
                    currentSongName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _playlist.isNotEmpty ? "Song ${_currentIndex + 1} of ${_playlist.length}" : "Queue empty",
                    style: TextStyle(fontSize: 12, color: Colors.purple.shade200),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // 3D Sound Switch Card
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

            // Seek Bar
            Slider(
              activeColor: Colors.purpleAccent,
              inactiveColor: Colors.grey.shade800,
              min: 0.0,
              max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
              value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0),
              onChanged: (value) async {
                final position = Duration(seconds: value.toInt());
                await _audioPlayer.seek(position);
                setState(() {
                  _position = position;
                });
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
            
            // Player Controls (Previous, Rewind, Play/Pause, Forward, Next)
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

            // Volume Slider Card
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.volume_down, color: Colors.white70, size: 20),
                    Expanded(
                      child: Slider(
                        activeColor: Colors.purpleAccent,
                        inactiveColor: Colors.grey.shade800,
                        min: 0.0,
                        max: 1.0,
                        value: _volume,
                        onChanged: (val) async {
                          setState(() {
                            _volume = val;
                          });
                          if (!is3DMode) {
                            await _audioPlayer.setVolume(_volume);
                          }
                        },
                      ),
                    ),
                    const Icon(Icons.volume_up, color: Colors.white70, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Add Songs to Queue Button
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
            const SizedBox(height: 15),

            // Queue List View Display
            if (_playlist.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Playback Queue', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _playlist.length,
                itemBuilder: (context, index) {
                  bool isCurrent = index == _currentIndex;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrent ? Colors.purple.withOpacity(0.2) : const Color(0xFF1E293B).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isCurrent ? Colors.purpleAccent : Colors.transparent),
                    ),
                    child: ListTile(
                      leading: Icon(
                        isCurrent ? Icons.play_arrow : Icons.music_note, 
                        color: isCurrent ? Colors.purpleAccent : Colors.white70,
                      ),
                      title: Text(
                        _playlist[index].name,
                        style: TextStyle(
                          color: isCurrent ? Colors.purpleAccent : Colors.white,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        setState(() {
                          _currentIndex = index;
                        });
                        _playCurrentSongInQueue();
                      },
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
