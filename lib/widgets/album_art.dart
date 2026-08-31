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
          // ============================================================
          // BASS BEAT PULSE LOGIC (Equalizer/Music Beat Effect)
          // ============================================================
          // Normal linear scaling ko Curve se replace karke Beat Effect banaya
          double animValue = animation.value; // 通常 1.0 -> 1.08 -> 1.0
          
          // Music Beat Curve Simulation (Double-Beat pulse like heart / bass)
          double pulseScale = 1.0;
          double beatGlow = 0.0;
          
          if (isPlaying) {
            // Sine wave calculation for sharp bass pulse
            double rawFactor = math.sin((animValue - 1.0) * math.pi * 10);
            pulseScale = 1.0 + (rawFactor.abs() * 0.06); // Beats up to 6% larger
            beatGlow = rawFactor.abs(); // Glow intense on beat drop
          }

          return Transform.scale(
            scale: pulseScale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Outer Bass Pulse Aura (Beats hard with music)
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

                // 2. Inner Glowing Border (Gradients with Beat Intensity)
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

                // 3. Main Album Art Circle
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
                    image: _getAlbumArtImage(),
                  ),
                  child: _getAlbumArtFallback(),
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

  // ============================================================
  // ALBUM ART HELPERS
  // ============================================================

  DecorationImage? _getAlbumArtImage() {
    if (songPath == null || songPath!.isEmpty) return null;
    
    try {
      final file = File(songPath!);
      if (file.existsSync()) {
        return DecorationImage(
          image: FileImage(file),
          fit: BoxFit.cover,
        );
      }
    } catch (_) {}
    return null;
  }

  Widget _getAlbumArtFallback() {
    if (songPath == null || songPath!.isEmpty || songName == "No song playing") {
      return Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 60,
          color: accentColor.withOpacity(0.8),
        ),
      );
    }
    
    final hasImage = _getAlbumArtImage() != null;
    
    if (!hasImage) {
      return Center(
        child: Text(
          songName.isNotEmpty ? songName.substring(0, 1).toUpperCase() : "M",
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.bold,
            color: accentColor,
            shadows: [
              Shadow(
                color: accentColor.withOpacity(0.6),
                blurRadius: 15,
              ),
            ],
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }
}
