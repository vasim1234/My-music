import 'package:flutter/material.dart';

class PlaybackMenu extends StatelessWidget {
  final bool isShuffle;
  final int repeatMode;
  final VoidCallback onShuffleTap;
  final VoidCallback onRepeatOffTap;
  final VoidCallback onRepeatOneTap;
  final VoidCallback onRepeatAllTap;
  final Color accentColor;

  const PlaybackMenu({
    super.key,
    required this.isShuffle,
    required this.repeatMode,
    required this.onShuffleTap,
    required this.onRepeatOffTap,
    required this.onRepeatOneTap,
    required this.onRepeatAllTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor, accentColor.withOpacity(0.6)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.repeat, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Playback Mode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMenuOption(
            icon: Icons.shuffle,
            title: 'Shuffle',
            subtitle: 'Play songs in random order',
            isActive: isShuffle,
            onTap: onShuffleTap,
            accentColor: accentColor,
          ),
          const Divider(color: Colors.white24),
          _buildMenuOption(
            icon: Icons.repeat_outlined,
            title: 'Repeat Off',
            subtitle: 'Stop after current song',
            isActive: repeatMode == 0 && !isShuffle,
            onTap: onRepeatOffTap,
            accentColor: accentColor,
          ),
          const Divider(color: Colors.white24),
          _buildMenuOption(
            icon: Icons.repeat_one,
            title: 'Repeat One',
            subtitle: 'Repeat current song',
            isActive: repeatMode == 1,
            onTap: onRepeatOneTap,
            accentColor: accentColor,
          ),
          const Divider(color: Colors.white24),
          _buildMenuOption(
            icon: Icons.repeat,
            title: 'Repeat All',
            subtitle: 'Repeat entire queue',
            isActive: repeatMode == 2,
            onTap: onRepeatAllTap,
            accentColor: accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: isActive
                    ? LinearGradient(colors: [accentColor, accentColor.withOpacity(0.6)])
                    : null,
                color: isActive ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isActive ? Colors.white : Colors.white54,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isActive ? accentColor : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isActive)
              Icon(Icons.check_circle, color: accentColor, size: 20),
          ],
        ),
      ),
    );
  }
}
