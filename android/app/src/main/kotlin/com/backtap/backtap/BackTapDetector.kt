package com.backtap.backtap

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Supported multi-tap gesture types recognized on the side button / chassis.
 */
enum class TapType {
    QUAD_TAP, // 4 quick taps: Triggers Screenshot
    OCTA_TAP  // 8 quick taps: Triggers Flashlight toggle
}

/**
 * Callback interface to communicate detected taps and real-time sensor metrics
 * back to the AccessibilityService and Flutter UI.
 */
interface BackTapListener {
    /**
     * Fired when a completed gesture (4 taps or 8 taps) is recognized.
     */
    fun onSideTap(type: TapType)

    /**
     * Fired on every raw accelerometer tick to feed the live calibration visualizer.
     * @param jerkSide Instantaneous jerk along the X-axis (side-to-side force)
     * @param jerkTotal 3D Euclidean magnitude of jerk
     * @param isTapPeak True if the current reading qualifies as an impulse peak
     */
    fun onSensorSample(jerkSide: Float, jerkTotal: Float, isTapPeak: Boolean)
}

/**
 * BackTapDetector handles physical tap recognition using an Adaptive Peak-Filter Algorithm.
 *
 * How it works:
 * 1. Monitors the raw accelerometer values (TYPE_ACCELEROMETER) at game rate (~50-100Hz).
 * 2. Calculates the jerk derivative (rate of change of acceleration): Δa = a(t) - a(t-1).
 * 3. Side fingerprint/power button taps produce distinct lateral impulses predominantly
 *    along the X-axis (perpendicular to the phone's right chassis).
 * 4. Checks that jerkSide >= sensitivityThreshold and verifies lateral dominance over total jerk
 *    to prevent accidental triggers caused by walking, waving, or pocket movement.
 * 5. Applies a 100ms refractory lockout to eliminate mechanical ringing of the phone body.
 * 6. Implements a multi-tap state machine distinguishing 4 taps (screenshot) from 8 taps (torch).
 */
class BackTapDetector(
    private val context: Context,
    private val listener: BackTapListener
) : SensorEventListener {

    // Sensor service & accelerometer reference
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val accelerometer: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val handler = Handler(Looper.getMainLooper())

    private var isListening = false

    // Previous sensor readings to compute first derivative (jerk)
    private var lastX = 0f
    private var lastY = 0f
    private var lastZ = 0f
    private var hasPreviousReading = false

    // Configurable sensitivity threshold (lower = lighter touch, higher = firmer tap)
    // Default: 18.0 m/s^2 per tick
    var sensitivityThreshold: Float = 18.0f

    // Timestamp of the last recognized peak to prevent resonant double-counting
    private var lastPeakTime = 0L
    private val debounceLockoutMs = 100L // 100ms refractory period

    // Multi-tap state tracking
    private var tapCount = 0
    private var lastTapTime = 0L

    /**
     * Runnable for 4-tap grace period:
     * When 4 taps are completed, we wait 380ms. If the user stops tapping,
     * QUAD_TAP (Screenshot) is fired. If the user continues tapping towards 8 taps,
     * this runnable is cancelled.
     */
    private val quadTapTimeoutRunnable = Runnable {
        if (tapCount == 4) {
            listener.onSideTap(TapType.QUAD_TAP)
        }
        tapCount = 0
    }

    /**
     * Resets tap count if the user pauses longer than the inter-tap window.
     */
    private val resetTapCountRunnable = Runnable {
        tapCount = 0
    }

    /**
     * Starts listening to accelerometer sensor events.
     * Returns true if the sensor was registered successfully.
     */
    fun startListening(): Boolean {
        if (isListening || accelerometer == null) return false
        hasPreviousReading = false
        tapCount = 0
        val registered = sensorManager.registerListener(
            this,
            accelerometer,
            SensorManager.SENSOR_DELAY_GAME
        )
        isListening = registered
        return registered
    }

    /**
     * Unregisters sensor listeners and cleans up pending timers.
     */
    fun stopListening() {
        if (!isListening) return
        handler.removeCallbacks(quadTapTimeoutRunnable)
        handler.removeCallbacks(resetTapCountRunnable)
        sensorManager.unregisterListener(this)
        isListening = false
        hasPreviousReading = false
        tapCount = 0
    }

    fun isRunning(): Boolean = isListening

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.sensor.type != Sensor.TYPE_ACCELEROMETER) return

        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]
        val now = System.currentTimeMillis()

        // Seed the initial readings
        if (!hasPreviousReading) {
            lastX = x
            lastY = y
            lastZ = z
            hasPreviousReading = true
            return
        }

        // Calculate delta acceleration (first derivative / jerk)
        val deltaX = x - lastX
        val deltaY = y - lastY
        val deltaZ = z - lastZ

        lastX = x
        lastY = y
        lastZ = z

        // Calculate side-to-side force (X-axis) and total 3D jerk
        val jerkSide = abs(deltaX)
        val jerkTotal = sqrt((deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ).toDouble()).toFloat()

        // Dominance ratio ensures the impact is predominantly lateral
        val sideDominance = if (jerkTotal > 0.001f) jerkSide / jerkTotal else 0f

        // Candidate peak criteria: high lateral force with directional dominance
        val isTapCandidate = (jerkSide >= sensitivityThreshold && sideDominance >= 0.30f) ||
                (jerkTotal >= sensitivityThreshold * 1.25f && jerkSide >= sensitivityThreshold * 0.65f)

        // Broadcast current sample to Flutter calibration UI
        listener.onSensorSample(jerkSide, jerkTotal, isTapCandidate)

        // Evaluate candidate against refractory lockout
        if (isTapCandidate && (now - lastPeakTime) > debounceLockoutMs) {
            lastPeakTime = now
            handleSideTapPeak(now)
        }
    }

    /**
     * Manages multi-tap progression through taps 1 through 8.
     */
    private fun handleSideTapPeak(now: Long) {
        handler.removeCallbacks(resetTapCountRunnable)

        val elapsed = now - lastTapTime
        lastTapTime = now

        when {
            tapCount == 0 -> {
                // First tap in sequence
                tapCount = 1
                handler.postDelayed(resetTapCountRunnable, 480L)
            }
            tapCount in 1..2 -> {
                // Taps 2 and 3 within acceptable rhythm (90ms - 520ms)
                if (elapsed in 90L..520L) {
                    tapCount++
                    handler.postDelayed(resetTapCountRunnable, 480L)
                } else {
                    tapCount = 1
                    handler.postDelayed(resetTapCountRunnable, 480L)
                }
            }
            tapCount == 3 -> {
                // 4th tap reached!
                if (elapsed in 90L..520L) {
                    tapCount = 4
                    // Start grace window (380ms). If no further taps arrive, fire 4-tap action.
                    handler.postDelayed(quadTapTimeoutRunnable, 380L)
                } else {
                    tapCount = 1
                    handler.postDelayed(resetTapCountRunnable, 480L)
                }
            }
            tapCount in 4..6 -> {
                // User is tapping past 4 taps: cancel screenshot and count towards 8 taps
                handler.removeCallbacks(quadTapTimeoutRunnable)
                if (elapsed in 90L..520L) {
                    tapCount++
                    handler.postDelayed(resetTapCountRunnable, 480L)
                } else {
                    tapCount = 1
                    handler.postDelayed(resetTapCountRunnable, 480L)
                }
            }
            tapCount == 7 -> {
                handler.removeCallbacks(quadTapTimeoutRunnable)
                if (elapsed in 90L..520L) {
                    // 8th tap reached! Immediately trigger OCTA_TAP (Flashlight)
                    tapCount = 0
                    listener.onSideTap(TapType.OCTA_TAP)
                } else {
                    tapCount = 1
                    handler.postDelayed(resetTapCountRunnable, 480L)
                }
            }
            else -> {
                tapCount = 1
                handler.postDelayed(resetTapCountRunnable, 480L)
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Sensor accuracy updates (no action needed)
    }
}
