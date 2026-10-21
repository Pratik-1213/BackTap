import 'package:flutter/material.dart';

/// Multi-tap gesture categories supported by BackTap.
enum TapActionType {
  quadTap, // 4 Taps
  octaTap, // 8 Taps
}

/// Model representing an assignable system action with icon, title, description,
/// and accent color tokens tailored for high-contrast light theme display.
class TapAction {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final bool requiresAccessibility;

  const TapAction({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    this.requiresAccessibility = true,
  });

  /// Complete catalogue of all system actions supported by BackTap
  static const List<TapAction> availableActions = [
    TapAction(
      id: 'SCREENSHOT',
      title: 'Take Screenshot',
      description: 'Instantly captures the entire screen content',
      icon: Icons.camera_alt_rounded,
      accentColor: Color(0xFF2563EB), // Rich Royal Blue
      requiresAccessibility: true,
    ),
    TapAction(
      id: 'FLASHLIGHT',
      title: 'Flashlight',
      description: 'Toggles rear LED torch on or off',
      icon: Icons.flashlight_on_rounded,
      accentColor: Color(0xFFD97706), // Rich Amber
      requiresAccessibility: false,
    ),
    TapAction(
      id: 'LOCK_SCREEN',
      title: 'Lock Screen',
      description: 'Immediately locks the phone display',
      icon: Icons.lock_outline_rounded,
      accentColor: Color(0xFFDC2626), // Rose Red
      requiresAccessibility: true,
    ),
    TapAction(
      id: 'NOTIFICATIONS',
      title: 'Open Notifications',
      description: 'Pulls down the system notification drawer',
      icon: Icons.notifications_active_rounded,
      accentColor: Color(0xFF7C3AED), // Vivid Violet
      requiresAccessibility: true,
    ),
    TapAction(
      id: 'HOME',
      title: 'Go to Home',
      description: 'Navigates back to the launcher home screen',
      icon: Icons.home_rounded,
      accentColor: Color(0xFF059669), // Emerald Green
      requiresAccessibility: true,
    ),
    TapAction(
      id: 'BACK',
      title: 'Back Button',
      description: 'Simulates Android system back navigation',
      icon: Icons.arrow_back_rounded,
      accentColor: Color(0xFFEA580C), // Deep Orange
      requiresAccessibility: true,
    ),
    TapAction(
      id: 'RECENTS',
      title: 'Recent Apps',
      description: 'Opens app switcher / multitasking view',
      icon: Icons.view_carousel_rounded,
      accentColor: Color(0xFF0284C7), // Sky Blue
      requiresAccessibility: true,
    ),
    TapAction(
      id: 'MUTE_VOLUME',
      title: 'Mute / Unmute',
      description: 'Toggles media volume mute state',
      icon: Icons.volume_off_rounded,
      accentColor: Color(0xFF9333EA), // Purple
      requiresAccessibility: false,
    ),
  ];

  /// Finds an action by ID, or defaults to the first action (Screenshot).
  static TapAction getById(String id) {
    return availableActions.firstWhere(
      (action) => action.id.toUpperCase() == id.toUpperCase(),
      orElse: () => availableActions[0],
    );
  }
}
