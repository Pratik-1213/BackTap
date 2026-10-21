import 'dart:async';
import 'package:flutter/material.dart';
import '../services/backtap_channel_service.dart';

/// CalibrationVisualizer provides interactive feedback for tuning tap firmness.
///
/// Features:
/// 1. Live smartphone graphic with highlighted side fingerprint/power sensor.
/// 2. Radial pulse animations triggering on recognized tap peaks.
/// 3. Real-time lateral force meter (X-Jerk) with threshold marker pin.
/// 4. Presets (Sensitive, Balanced, Firm) and precision slider for fine-tuning.
class CalibrationVisualizer extends StatefulWidget {
  final double sensitivityThreshold;
  final ValueChanged<double> onSensitivityChanged;

  const CalibrationVisualizer({
    super.key,
    required this.sensitivityThreshold,
    required this.onSensitivityChanged,
  });

  @override
  State<CalibrationVisualizer> createState() => _CalibrationVisualizerState();
}

class _CalibrationVisualizerState extends State<CalibrationVisualizer>
    with SingleTickerProviderStateMixin {
  StreamSubscription<SensorSample>? _subscription;
  double _currentJerkSide = 0.0;
  double _peakJerkSide = 0.0;
  bool _isRecentTap = false;
  Timer? _tapFlashTimer;
  Timer? _peakDecayTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOutBack,
    );

    _startListening();
  }

  /// Subscribes to the live EventChannel sensor stream
  void _startListening() {
    _subscription = BackTapChannelService.instance.sensorStream.listen((sample) {
      if (!mounted) return;

      setState(() {
        _currentJerkSide = sample.jerkSide;
        if (sample.jerkSide > _peakJerkSide) {
          _peakJerkSide = sample.jerkSide;
        }

        // Trigger visual pulse when a qualifying tap peak is registered
        if (sample.isTap) {
          _isRecentTap = true;
          _pulseController.forward(from: 0.0);
          _tapFlashTimer?.cancel();
          _tapFlashTimer = Timer(const Duration(milliseconds: 600), () {
            if (mounted) setState(() => _isRecentTap = false);
          });
        }
      });
    });

    // Smooth meter falloff decay
    _peakDecayTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && _peakJerkSide > 0.5) {
        setState(() {
          _peakJerkSide *= 0.92;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _tapFlashTimer?.cancel();
    _peakDecayTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isExceeding = _currentJerkSide >= widget.sensitivityThreshold;
    const maxMeterRange = 35.0;
    final normalizedValue = (_currentJerkSide / maxMeterRange).clamp(0.0, 1.0);
    final normalizedThreshold = (widget.sensitivityThreshold / maxMeterRange).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isRecentTap ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          width: _isRecentTap ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _isRecentTap
                ? const Color(0xFF2563EB).withValues(alpha: 0.20)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: _isRecentTap ? 20 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        color: Color(0xFF2563EB),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Side Button Calibration',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Test side fingerprint sensor firmness',
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
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isRecentTap
                      ? const Color(0xFF2563EB)
                      : (isExceeding
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isRecentTap
                      ? 'TAP DETECTED!'
                      : (isExceeding ? 'SPIKE' : 'IDLE'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: _isRecentTap
                        ? Colors.white
                        : (isExceeding ? const Color(0xFFD97706) : const Color(0xFF64748B)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Central Visualizer: Smartphone with Side-Mounted Fingerprint/Power Sensor highlighted
          Center(
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.08).animate(_pulseAnimation),
              child: SizedBox(
                width: 140,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Phone silhouette
                    Container(
                      width: 60,
                      height: 94,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                      ),
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 76,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.touch_app_rounded,
                              size: 20,
                              color: _isRecentTap ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Side Power / Fingerprint Button Indicator (Right side)
                    Positioned(
                      right: 32,
                      top: 32,
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _isRecentTap ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                if (_isRecentTap)
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.6),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _isRecentTap ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Fingerprint',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _isRecentTap ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Tap firmly on your side fingerprint / power button',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Real-time Lateral Force (X-Jerk) Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Side Lateral Force (X-Jerk)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                '${_currentJerkSide.toStringAsFixed(1)} m/s²',
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: isExceeding ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Custom Meter with Threshold marker pin
          LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              final progressWidth = (barWidth * normalizedValue).clamp(0.0, barWidth);
              final markerLeft = (barWidth * normalizedThreshold).clamp(0.0, barWidth - 4);

              return SizedBox(
                height: 20,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Background track
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                    ),
                    // Live current value bar
                    Container(
                      height: 12,
                      width: progressWidth,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isExceeding
                              ? [const Color(0xFF60A5FA), const Color(0xFF2563EB)]
                              : [const Color(0xFFCBD5E1), const Color(0xFF94A3B8)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    // Threshold Marker Pin
                    Positioned(
                      left: markerLeft,
                      child: Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD97706).withValues(alpha: 0.4),
                              blurRadius: 6,
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '0 m/s²',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
              Text(
                'Threshold: ${widget.sensitivityThreshold.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD97706),
                ),
              ),
              const Text(
                '35+ m/s²',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Preset Chips: Sensitive, Balanced, Firm
          Row(
            children: [
              _buildPresetChip('Sensitive (12.0)', 12.0),
              const SizedBox(width: 8),
              _buildPresetChip('Balanced (18.0)', 18.0),
              const SizedBox(width: 8),
              _buildPresetChip('Firm (24.0)', 24.0),
            ],
          ),
          const SizedBox(height: 8),

          // Precision Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF2563EB),
              inactiveTrackColor: const Color(0xFFE2E8F0),
              thumbColor: const Color(0xFF2563EB),
              overlayColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              trackHeight: 4,
            ),
            child: Slider(
              value: widget.sensitivityThreshold.clamp(8.0, 32.0),
              min: 8.0,
              max: 32.0,
              divisions: 24,
              label: '${widget.sensitivityThreshold.toStringAsFixed(1)} m/s²',
              onChanged: widget.onSensitivityChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, double value) {
    final isSelected = (widget.sensitivityThreshold - value).abs() < 1.0;
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onSensitivityChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}
