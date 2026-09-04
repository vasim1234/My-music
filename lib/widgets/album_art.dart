// ============================================================
// ALBUM ART - WITH 3D MODE
// ============================================================
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
    final size = MediaQuery.of(context).size.width * 0.6;
    final firstLetter = songName.isNotEmpty ? songName.substring(0, 1).toUpperCase() : '♪';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Main text
          Center(
            child: Text(
              firstLetter,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 80,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Playing indicator (animated pulse)
          if (isPlaying)
            Positioned(
              bottom: 16,
              right: 16,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: animation.value,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          
          // Sleep timer indicator
          if (isSleepTimerActive)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Zzz',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          
          // ✅ 3D Mode indicator
          if (is3DMode)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.purple, Colors.deepPurple],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.three_mp, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      '3D',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
