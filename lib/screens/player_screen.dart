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
  String currentFileName = "No file selected";
  double audioSpeed = 1.0;
  bool is3DMode = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('3D Sound Music Player'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Visualizer / 3D Icon Box
            Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.deepPurple, Colors.purpleAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurpleAccent.withOpacity(0.5),
                    blurRadius: is3DMode ? 30 : 10,
                    spreadRadius: is3DMode ? 10 : 2,
                  ),
                ],
              ),
              child: const Icon(Icons.headphones_rounded, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 30),
            Text(
              currentFileName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // 3D Sound Toggle
            SwitchListTile(
              title: const Text('3D Surround Sound Effect'),
              value: is3DMode,
              activeColor: Colors.purpleAccent,
              onChanged: (val) {
                setState(() => is3DMode = val);
              },
            ),
            const SizedBox(height: 30),
            // Controls Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickAndPlayAudio,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Open Song'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                ),
                const SizedBox(width: 20),
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.deepPurpleAccent,
                  child: IconButton(
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                    iconSize: 32,
                    onPressed: _togglePlayPause,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

