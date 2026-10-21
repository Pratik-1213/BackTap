import 'dart:async';
import 'package:flutter/material.dart';
import '../models/tap_action.dart';
import '../services/backtap_channel_service.dart';
import '../widgets/action_selector_sheet.dart';
import '../widgets/calibration_visualizer.dart';

/// HomeScreen serves as the primary dashboard for BackTap.
///
/// Responsibilities:
/// 1. Checks and displays Android Accessibility Service & Battery Optimization status.
/// 2. Provides mapping cards for the two gestures:
///    - 4x Tap: Screenshot
///    - 8x Tap: Flashlight
/// 3. Integrates the live Calibration Studio with visual smartphone target.
/// 4. Listens to real-time gesture trigger events from native Kotlin.
/// 5. Clean, accessible light-theme design with zero layout overflow.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final BackTapChannelService _service = BackTapChannelService.instance;

  // System permissions & service state
  bool _isAccessibilityEnabled = false;
  bool _isBatteryOptIgnored = false;
  bool _isServiceActive = true;
  bool _hapticsEnabled = true;
  double _sensitivityThreshold = 18.0;

  // Active mappings for 4x and 8x taps
  String _quadTapActionId = 'SCREENSHOT'; // 4x tap: Screenshot
  String _octaTapActionId = 'FLASHLIGHT';  // 8x tap: Flashlight

  // Real-time gesture trigger subscription
  StreamSubscription<GestureTrigger>? _gestureSubscription;
  String? _recentTriggerMessage;
  Timer? _recentTriggerTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadState();
    _listenToGestures();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gestureSubscription?.cancel();
    _recentTriggerTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-query permissions when user returns from Android Settings
      _checkPermissions();
    }
  }

  /// Loads stored preferences from native SharedPreferences
  Future<void> _loadState() async {
    final settings = await _service.getStoredSettings();
    setState(() {
      _quadTapActionId = settings['quadTapAction'] as String? ?? 'SCREENSHOT';
      _octaTapActionId = settings['octaTapAction'] as String? ?? 'FLASHLIGHT';
      _sensitivityThreshold = (settings['sensitivity'] as num?)?.toDouble() ?? 18.0;
      _hapticsEnabled = settings['haptics'] as bool? ?? true;
      _isServiceActive = settings['active'] as bool? ?? true;
    });

    await _checkPermissions();
  }

  /// Checks system permission states via platform channel
  Future<void> _checkPermissions() async {
    final accessEnabled = await _service.isAccessibilityServiceEnabled();
    final batteryIgnored = await _service.isBatteryOptimizationIgnored();

    if (mounted) {
      setState(() {
        _isAccessibilityEnabled = accessEnabled;
        _isBatteryOptIgnored = batteryIgnored;
      });
    }
  }

  /// Saves updated preferences to native SharedPreferences and notifies service
  Future<void> _saveSettings() async {
    await _service.updateSettings(
      quadTapAction: _quadTapActionId,
      octaTapAction: _octaTapActionId,
      sensitivity: _sensitivityThreshold,
      haptics: _hapticsEnabled,
      active: _isServiceActive,
    );
  }

  /// Subscribes to native gesture trigger events and displays an animated toast banner
  void _listenToGestures() {
    _gestureSubscription = _service.gestureStream.listen((gesture) {
      if (!mounted) return;

      final action = TapAction.getById(gesture.action);
      final gestureName = gesture.type == 'QUAD_TAP'
          ? '4x Tap'
          : '8x Tap';

      setState(() {
        _recentTriggerMessage = '⚡ $gestureName Triggered: ${action.title}';
      });

      _recentTriggerTimer?.cancel();
      _recentTriggerTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _recentTriggerMessage = null;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final quadTapAction = TapAction.getById(_quadTapActionId);
    final octaTapAction = TapAction.getById(_octaTapActionId);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/logo.png',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'BackTap',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Color(0xFF0F172A),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            tooltip: 'Check Status',
            onPressed: _checkPermissions,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        children: [
          // Live Gesture Trigger Notification Banner
          if (_recentTriggerMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2563EB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFF2563EB)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _recentTriggerMessage!,
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Permission Alert Card (if Accessibility is not yet enabled)
          if (!_isAccessibilityEnabled) ...[
            _buildAccessibilityWarningCard(),
            const SizedBox(height: 18),
          ] else ...[
            _buildServiceActiveCard(),
            const SizedBox(height: 18),
          ],

          // Gesture Mapping Header
          const Text(
            'GESTURE MAPPING',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),

          // Option 1: Tap 4 Times (Default: Screenshot)
          _buildGestureCard(
            title: 'Tap 4 Times',
            badgeText: '4x TAP',
            action: quadTapAction,
            onTapChange: () async {
              final selected = await ActionSelectorSheet.show(
                context,
                title: 'Assign 4x Tap Action',
                currentActionId: _quadTapActionId,
              );
              if (selected != null) {
                setState(() => _quadTapActionId = selected.id);
                _saveSettings();
              }
            },
            onTest: () {
              _service.testAction(quadTapAction.id);
            },
          ),
          const SizedBox(height: 12),

          // Option 2: Tap 8 Times (Default: Flashlight)
          _buildGestureCard(
            title: 'Tap 8 Times',
            badgeText: '8x TAP',
            action: octaTapAction,
            onTapChange: () async {
              final selected = await ActionSelectorSheet.show(
                context,
                title: 'Assign 8x Tap Action',
                currentActionId: _octaTapActionId,
              );
              if (selected != null) {
                setState(() => _octaTapActionId = selected.id);
                _saveSettings();
              }
            },
            onTest: () {
              _service.testAction(octaTapAction.id);
            },
          ),
          const SizedBox(height: 24),

          // Live Calibration Studio
          CalibrationVisualizer(
            sensitivityThreshold: _sensitivityThreshold,
            onSensitivityChanged: (newVal) {
              setState(() => _sensitivityThreshold = newVal);
              _saveSettings();
            },
          ),
          const SizedBox(height: 24),

          // Preferences & System Optimizations
          const Text(
            'PREFERENCES & SYSTEM',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),

          // Haptics Setting Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.vibration_rounded,
                          color: Color(0xFF9333EA),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Haptic Feedback',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Vibrate upon recognizing tap',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _hapticsEnabled,
                  activeTrackColor: const Color(0xFF2563EB),
                  onChanged: (val) {
                    setState(() => _hapticsEnabled = val);
                    _saveSettings();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Battery Optimization Exemption Card
          if (!_isBatteryOptIgnored) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.battery_saver_rounded,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unrestricted Battery',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Prevent Android from pausing sensor listener',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _service.requestIgnoreBatteryOptimizations();
                    },
                    child: const Text(
                      'Allow',
                      style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Quick Tips Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates_outlined, color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Tip: Tap on the side fingerprint sensor / power button. Tap 4 times quickly to take a screenshot, and tap 8 times quickly to turn on the flashlight!',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAccessibilityWarningCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.accessibility_new_rounded,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Accessibility Service Required',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'To capture screenshots, toggle flashlight, or execute gestures while using other apps, Android requires enabling the BackTap Accessibility Service.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF78350F),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _service.openAccessibilitySettings();
              },
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text('Open Accessibility Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceActiveCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isServiceActive ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: _isServiceActive
                ? const Color(0xFF059669).withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isServiceActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                    boxShadow: [
                      if (_isServiceActive)
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isServiceActive ? 'Service Active & Listening' : 'Service Paused',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        _isServiceActive ? '4x and 8x taps recognized globally' : 'Gestures paused',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: _isServiceActive,
            activeTrackColor: const Color(0xFF2563EB),
            onChanged: (val) {
              setState(() => _isServiceActive = val);
              _saveSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGestureCard({
    required String title,
    required String badgeText,
    required TapAction action,
    required VoidCallback onTapChange,
    required VoidCallback onTest,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: action.accentColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: action.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onTest,
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text('Test'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTapChange,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: action.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        action.icon,
                        color: action.accentColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            action.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
