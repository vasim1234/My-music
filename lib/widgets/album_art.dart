import 'dart:io';
import 'dart:math' as math;
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
          double animValue = animation.value;
          double pulseScale = 1.0;
          double beatGlow = 0.0;
          
          if (isPlaying) {
            double rawFactor = math.sin((animValue - 1.0) * math.pi * 10);
            pulseScale = 1.0 + (rawFactor.abs() * 0.06);
            beatGlow = rawFactor.abs();
          }

          final hasImage = _hasValidImage();

          return Transform.scale(
            scale: pulseScale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Outer Bass Pulse Aura
                Container(
                  height: 245,
                  width: 245,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(
                          isPlaying ? 0.25 + (beatGlow * 0.25) : 0.08,
                        ),
                        blurRadius: isPlaying ? 35 + (beatGlow * 25) : 15,
                        spreadRadius: isPlaying ? 5 + (beatGlow * 12) : 2,
                      ),
                    ],
                  ),
                ),

                // 2. Inner Glowing Border
                Container(
                  height: 215,
                  width: 215,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (gradient.isNotEmpty ? gradient.first : accentColor)
                            .withOpacity(isPlaying ? 0.4 + (beatGlow * 0.3) : 0.2),
                        blurRadius: isPlaying ? 18 + (beatGlow * 10) : 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),

                // 3. Main Album Art Circle (Image or Fallback)
                Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E1E2C),
                    border: Border.all(
                      color: Colors.white.withOpacity(isPlaying ? 0.25 : 0.1),
                      width: 2,
                    ),
                    image: hasImage
                        ? DecorationImage(
                            image: FileImage(File(songPath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: !hasImage ? _buildDefaultFallback() : null,
                ),

                // 4. Sleep Timer Badge
                if (isSleepTimerActive)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9F43),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.timer_rounded, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _hasValidImage() {
    if (songPath == null || songPath!.isEmpty) return false;
    try {
      final file = File(songPath!);
      // Checking if file ends with image extensions, otherwise audio file path directly won't render as image
      final pathLower = songPath!.toLowerCase();
      if (file.existsSync() && (pathLower.endsWith('.jpg') || pathLower.endsWith('.png') || pathLower.endsWith('.jpeg'))) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Widget _buildDefaultFallback() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note_rounded,
            size: 65,
            color: accentColor,
          ),
          const SizedBox(height: 6),
          Text(
            songName.isNotEmpty ? songName.substring(0, 1).toUpperCase() : "M",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.9),
              shadows: [
                Shadow(
                  color: accentColor.withOpacity(0.6),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
