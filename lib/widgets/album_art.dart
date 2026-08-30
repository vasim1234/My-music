import 'package:flutter/material.dart';

class AlbumArt extends StatelessWidget {
  final bool isPlaying;
  final bool is3DMode;
  final String songName;
  final List<Color> gradient;
  final bool isSleepTimerActive;
  final Animation<double> animation;

  const AlbumArt({
    super.key,
    required this.isPlaying,
    required this.is3DMode,
    required this.songName,
    required this.gradient,
    required this.isSleepTimerActive,
    required this.animation,
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
                Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: gradient),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.3),
                        blurRadius: 35,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 180,
                  width: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: songName.isNotEmpty
                        ? Text(
                            songName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.music_note_rounded,
                            size: 60,
                            color: Colors.white,
                          ),
                  ),
                ),
                if (isSleepTimerActive)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF9F43),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.timer, color: Colors.white, size: 12),
                    ),
                  ),
                Positioned(
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: gradient[0].withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPlaying ? Icons.play_arrow : Icons.pause,
                          color: gradient[0],
                          size: 11,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPlaying ? 'Playing' : 'Paused',
                          style: TextStyle(
                            color: gradient[0],
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
