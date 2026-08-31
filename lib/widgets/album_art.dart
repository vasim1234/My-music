import 'dart:io';
import 'package:flutter/material.dart';

class AlbumArt extends StatelessWidget {
  final bool isPlaying;
  final bool is3DMode;
  final String songName;
  final String? songPath;
  final List<Color> gradient;
  final bool isSleepTimerActive;
  final Animation<double> animation;
  final Color accentColor;

  const AlbumArt({
    super.key,
    required this.isPlaying,
    required this.is3DMode,
    required this.songName,
    this.songPath,
    required this.gradient,
    required this.isSleepTimerActive,
    required this.animation,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.scale(
            scale: isPlaying ? animation.value : 1.0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Glow
                Container(
                  height: 220,
                  width: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: gradient),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.35),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
                // Main Album Art Circle
                Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E1E2C),
                    image: _getAlbumArtImage(),
                  ),
                  child: _getAlbumArtFallback(),
                ),
                // Sleep Timer Badge
                if (isSleepTimerActive)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF9F43),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.timer, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // ALBUM ART HELPERS
  // ============================================================

  // Try to get album art from song file
  DecorationImage? _getAlbumArtImage() {
    if (songPath == null || songPath!.isEmpty) return null;
    
    try {
      final file = File(songPath!);
      if (file.existsSync()) {
        // Check if file has embedded image
        return DecorationImage(
          image: FileImage(file),
          fit: BoxFit.cover,
        );
      }
    } catch (e) {
      // Image load nahi hui toh null return karo
    }
    return null;
  }

  // Fallback: Agar image nahi hai toh letter ya icon dikhao
  Widget _getAlbumArtFallback() {
    // Agar songPath nahi hai toh music note dikhao
    if (songPath == null || songPath!.isEmpty || songName == "No song playing") {
      return Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 60,
          color: Colors.white.withOpacity(0.5),
        ),
      );
    }
    
    // Try to check if image exists
    final hasImage = _getAlbumArtImage() != null;
    
    if (!hasImage) {
      // Agar image nahi hai toh song ka first letter dikhao
      return Center(
        child: Text(
          songName.isNotEmpty ? songName.substring(0, 1).toUpperCase() : "M",
          style: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    
    return const SizedBox.shrink(); // Image show hogi via BoxDecoration
  }
}
