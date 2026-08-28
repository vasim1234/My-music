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
  String currentFileName = "No song selected";
  bool is3DMode = false;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0; // Volume ke liye state variable (0.0 se 1.0)

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
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickAndPlayAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      String fileName = result.files.single.name;

      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(filePath));
      await _audioPlayer.setVolume(_volume); // Set current volume

      setState(() {
        currentFileName = fileName;
        isPlaying = true;
      });
    }
  }

  Future<void> _togglePlayPause() async {
    if (isPlaying) {
      await _audioPlayer.pause();
      setState(() => isPlaying = false);
    } else {
      await _audioPlayer.resume();
      setState(() => isPlaying = true);
    }
  }

  // 10 seconds aage ya piche karne ke liye function
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Music 3D'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView( // Scrollable banaya hai taaki screen choti na pade
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            Container(
              height: 160,
              width: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Colors.deepPurple, Colors.purpleAccent],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurpleAccent.withOpacity(0.5),
                    blurRadius: is3DMode ? 35 : 12,
                    spreadRadius: is3DMode ? 8 : 2,
                  ),
                ],
              ),
              child: const Icon(Icons.headphones_rounded, size: 70, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              currentFileName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text('3D Sound Effect', style: TextStyle(fontSize: 14)),
              value: is3DMode,
              activeColor: Colors.purpleAccent,
              onChanged: (val) {
                setState(() => is3DMode = val);
              },
            ),
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
            const SizedBox(height: 15),
            
            // Skip & Rewind Buttons (-10s aur +10s)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10, color: Colors.white70, size: 28),
                  onPressed: () => _seekRelative(-10),
                ),
                const SizedBox(width: 20),
                // Play / Pause Button
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.deepPurpleAccent,
                  child: IconButton(
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                    iconSize: 30,
                    onPressed: _togglePlayPause,
                  ),
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.forward_10, color: Colors.white70, size: 28),
                  onPressed: () => _seekRelative(10),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Volume Slider Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                        await _audioPlayer.setVolume(_volume);
                      },
                    ),
                  ),
                  const Icon(Icons.volume_up, color: Colors.white70, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // Open Song Button
            ElevatedButton.icon(
              onPressed: _pickAndPlayAudio,
              icon: const Icon(Icons.folder_open),
              label: const Text('Open Song'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
