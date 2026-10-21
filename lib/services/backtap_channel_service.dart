import 'dart:async';
import 'package:flutter/services.dart';

/// Immutable data class carrying real-time accelerometer readings
/// from the native Android sensor listener to Flutter.
class SensorSample {
  final double jerkSide;
  final double jerkTotal;
  final bool isTap;
  final DateTime timestamp;

  SensorSample({
    required this.jerkSide,
    required this.jerkTotal,
    required this.isTap,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SensorSample.fromMap(Map<dynamic, dynamic> map) {
    return SensorSample(
      jerkSide: (map['jerkSide'] as num?)?.toDouble() ?? 0.0,
      jerkTotal: (map['jerkTotal'] as num?)?.toDouble() ?? 0.0,
      isTap: (map['isTap'] as bool?) ?? false,
    );
  }
}

/// Event emitted when a completed multi-tap gesture sequence is recognized.
class GestureTrigger {
  final String type; // QUAD_TAP (4x) or OCTA_TAP (8x)
  final String action;
  final DateTime timestamp;

  GestureTrigger({
    required this.type,
    required this.action,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory GestureTrigger.fromMap(Map<dynamic, dynamic> map) {
    return GestureTrigger(
      type: (map['type'] as String?) ?? 'QUAD_TAP',
      action: (map['action'] as String?) ?? 'UNKNOWN',
    );
  }
}

/// BackTapChannelService provides typed asynchronous APIs and event streams
/// to communicate with native Kotlin platform channels.
class BackTapChannelService {
  static const MethodChannel _methodChannel = MethodChannel('com.backtap.app/channel');
  static const EventChannel _sensorEventChannel = EventChannel('com.backtap.app/sensor_stream');
  static const EventChannel _gestureEventChannel = EventChannel('com.backtap.app/gesture_stream');

  static final BackTapChannelService instance = BackTapChannelService._internal();
  BackTapChannelService._internal();

  Stream<SensorSample>? _sensorStream;
  Stream<GestureTrigger>? _gestureStream;

  /// Checks if BackTap is enabled in Android's Accessibility Services list.
  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final bool? enabled = await _methodChannel.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return enabled ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the Android Accessibility Settings screen for user onboarding.
  Future<void> openAccessibilitySettings() async {
    try {
      await _methodChannel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (_) {}
  }

  /// Checks if battery optimization is disabled for uninterrupted background detection.
  Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final bool? ignored = await _methodChannel.invokeMethod<bool>('isBatteryOptimizationIgnored');
      return ignored ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Requests exemption from Android Doze battery optimizations.
  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _methodChannel.invokeMethod('requestIgnoreBatteryOptimizations');
    } on PlatformException catch (_) {}
  }

  /// Checks if the AccessibilityService instance is currently alive and active.
  Future<bool> isServiceRunning() async {
    try {
      final bool? running = await _methodChannel.invokeMethod<bool>('isServiceRunning');
      return running ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Persists gesture configuration to native SharedPreferences and reloads service.
  Future<bool> updateSettings({
    required String quadTapAction,
    required String octaTapAction,
    required double sensitivity,
    required bool haptics,
    required bool active,
  }) async {
    try {
      final bool? success = await _methodChannel.invokeMethod<bool>('updateSettings', {
        'quadTapAction': quadTapAction,
        'octaTapAction': octaTapAction,
        'sensitivity': sensitivity,
        'haptics': haptics,
        'active': active,
      });
      return success ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Fetches saved settings from native SharedPreferences.
  Future<Map<String, dynamic>> getStoredSettings() async {
    try {
      final Map<dynamic, dynamic>? settings = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getSettings');
      if (settings != null) {
        return Map<String, dynamic>.from(settings);
      }
    } on PlatformException catch (_) {}

    return {
      'quadTapAction': 'SCREENSHOT',
      'octaTapAction': 'FLASHLIGHT',
      'sensitivity': 18.0,
      'haptics': true,
      'active': true,
    };
  }

  /// Directly tests an action by executing it via native action executors.
  Future<bool> testAction(String actionId) async {
    try {
      final bool? success = await _methodChannel.invokeMethod<bool>('testAction', {
        'actionId': actionId,
      });
      return success ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Real-time stream of sensor samples used for calibration visualizer graph.
  Stream<SensorSample> get sensorStream {
    _sensorStream ??= _sensorEventChannel
        .receiveBroadcastStream()
        .map((event) => SensorSample.fromMap(event as Map<dynamic, dynamic>))
        .handleError((error) {});
    return _sensorStream!;
  }

  /// Stream of recognized multi-tap gesture trigger events.
  Stream<GestureTrigger> get gestureStream {
    _gestureStream ??= _gestureEventChannel
        .receiveBroadcastStream()
        .map((event) => GestureTrigger.fromMap(event as Map<dynamic, dynamic>))
        .handleError((error) {});
    return _gestureStream!;
  }
}
