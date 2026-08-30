import 'package:flutter/material.dart';

class PlaybackControls extends StatelessWidget {
  final bool isShuffle;
  final int repeatMode;
  final VoidCallback onShuffleRepeatToggle;
  final VoidCallback onShuffleRepeatLongPress;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onQueue;
  final bool isPlaying;
  final List<Color> gradient;

  const PlaybackControls({
    super.key,
    required this.isShuffle,
    required this.repeatMode,
    required this.onShuffleRepeatToggle,
    required this.onShuffleRepeatLongPress,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    required this.onQueue,
    required this.isPlaying,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Shuffle/Repeat
        GestureDetector(
          onTap: onShuffleRepeatToggle,
          onLongPress: onShuffleRepeatLongPress,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: (isShuffle || repeatMode > 0) 
                  ? gradient[0].withOpacity(0.15) 
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: (isShuffle || repeatMode > 0) 
                  ? Border.all(color: gradient[0].withOpacity(0.3), width: 1) 
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isShuffle ? Icons.shuffle : Icons.repeat,
                  color: (isShuffle || repeatMode > 0) ? gradient[0] : Colors.white54,
                  size: 16,
                ),
                const SizedBox(width: 2),
                Text(
                  isShuffle ? 'Shuffle' : (repeatMode == 1 ? '1' : (repeatMode == 2 ? 'All' : '')),
                  style: TextStyle(
                    color: (isShuffle || repeatMode > 0) ? gradient[0] : Colors.white54,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(width: 4),
        
        // Previous
        IconButton(
          icon: const Icon(Icons.skip_previous, color: Colors.white, size: 24),
          onPressed: onPrevious,
          padding: const EdgeInsets.all(4),
        ),
        
        const SizedBox(width: 4),
        
        // Play/Pause
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: gradient),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withOpacity(0.35),
                blurRadius: 15,
                spreadRadius: 3,
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
            iconSize: 30,
            onPressed: onPlayPause,
            padding: const EdgeInsets.all(12),
          ),
        ),
        
        const SizedBox(width: 4),
        
        // Next
        IconButton(
          icon: const Icon(Icons.skip_next, color: Colors.white, size: 24),
          onPressed: onNext,
          padding: const EdgeInsets.all(4),
        ),
        
        const SizedBox(width: 4),
        
        // Queue
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4ECDC4), Color(0xFF2C7A78)],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: IconButton(
            icon: const Icon(Icons.queue_music, color: Colors.white, size: 18),
            onPressed: onQueue,
            padding: const EdgeInsets.all(6),
          ),
        ),
      ],
    );
  }
}
