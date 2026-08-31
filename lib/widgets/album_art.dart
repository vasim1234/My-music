import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

class AlbumArt extends StatelessWidget {
  final bool isPlaying;
  final bool is3DMode;
  final String songName;
  final String? songPath; // PlayerScreen ke parameter compatibility ke liye
  final int? songId;
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
    this.songId,
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
                // Outer Glow Circle
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
                    color: Colors.grey.shade900,
                  ),
                  child: ClipOval(
                    child: songId != null
                        ? QueryArtworkWidget(
                            id: songId!,
                            type: ArtworkType.AUDIO,
                            artworkFit: BoxFit.cover,
                            nullArtworkWidget: _buildDefaultFallback(),
                            errorBuilder: (context, error, stackTrace) => _buildDefaultFallback(),
                          )
                        : _buildDefaultFallback(),
                  ),
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

  // Photo na hone par app logo/icon dikhane ke liye
  Widget _buildDefaultFallback() {
    return Container(
      color: const Color(0xFF1E1E2C),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note_rounded,
              size: 70,
              color: accentColor,
            ),
            const SizedBox(height: 8),
            Text(
              songName.isNotEmpty ? songName.substring(0, 1).toUpperCase() : "M",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
