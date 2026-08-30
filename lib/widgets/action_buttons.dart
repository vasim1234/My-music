import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final bool is3DMode;
  final bool isEqActive;
  final bool isCurrentFavorite;
  final bool isSleepTimerActive;
  final int sleepTimerMinutes;
  final double volume;
  final VoidCallback on3DToggle;
  final VoidCallback onEQTap;
  final VoidCallback onVolumeTap;
  final VoidCallback onFavoriteTap;
  final VoidCallback onTimerTap;
  final Color accentColor;

  const ActionButtons({
    super.key,
    required this.is3DMode,
    required this.isEqActive,
    required this.isCurrentFavorite,
    required this.isSleepTimerActive,
    required this.sleepTimerMinutes,
    required this.volume,
    required this.on3DToggle,
    required this.onEQTap,
    required this.onVolumeTap,
    required this.onFavoriteTap,
    required this.onTimerTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildButton(
          icon: Icons.spatial_audio,
          label: '3D',
          isActive: is3DMode,
          activeColor: accentColor,
          onTap: on3DToggle,
        ),
        _buildButton(
          icon: Icons.equalizer,
          label: 'EQ',
          isActive: isEqActive,
          activeColor: accentColor,
          onTap: onEQTap,
        ),
        _buildButton(
          icon: Icons.volume_up,
          label: 'Volume',
          isActive: false,
          activeColor: Colors.white,
          onTap: onVolumeTap,
        ),
        _buildButton(
          icon: isCurrentFavorite ? Icons.favorite : Icons.favorite_border,
          label: isCurrentFavorite ? 'Liked' : 'Heart',
          isActive: isCurrentFavorite,
          activeColor: Colors.red,
          onTap: onFavoriteTap,
        ),
        _buildButton(
          icon: Icons.timer,
          label: isSleepTimerActive ? '${sleepTimerMinutes}m' : 'Timer',
          isActive: isSleepTimerActive,
          activeColor: const Color(0xFFFF9F43),
          onTap: onTimerTap,
        ),
      ],
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? activeColor.withOpacity(0.15) : const Color(0xFF16161E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? activeColor : Colors.grey.shade800,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : Colors.white54,
              size: 18,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : const Color(0xFF8888AA),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
