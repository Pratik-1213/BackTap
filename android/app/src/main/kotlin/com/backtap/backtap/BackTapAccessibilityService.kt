package com.backtap.backtap

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.FingerprintGestureController
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityEvent

/**
 * BackTapAccessibilityService runs in the background as an Android Accessibility Service.
 *
 * Why an Accessibility Service?
 * 1. Global Action Execution: Only an Accessibility Service can execute system actions
 *    (GLOBAL_ACTION_TAKE_SCREENSHOT, GLOBAL_ACTION_LOCK_SCREEN, GLOBAL_ACTION_NOTIFICATIONS)
 *    when other applications are active on the screen without requiring root or screen-capture prompts.
 * 2. Background Persistence: Android maintains accessibility services continuously with high priority.
 * 3. Sensor & Hardware Integration: Houses the BackTapDetector and listens to Fingerprint gestures.
 */
class BackTapAccessibilityService : AccessibilityService(), BackTapListener {

    private val tag = "BackTapService"
    private lateinit var detector: BackTapDetector
    private lateinit var executor: ActionExecutor
    private lateinit var prefs: SharedPreferences

    // Configuration settings
    private var isServiceActive = true
    private var quadTapAction = "SCREENSHOT"  // 4 taps: Screenshot
    private var octaTapAction = "FLASHLIGHT"  // 8 taps: Flashlight
    private var sensitivityThreshold = 18.0f
    private var hapticsEnabled = true

    private var fingerprintCallback: FingerprintGestureController.FingerprintGestureCallback? = null

    companion object {
        const val PREFS_NAME = "BackTapPrefs"
        const val KEY_SERVICE_ACTIVE = "service_active"
        const val KEY_QUAD_TAP_ACTION = "quad_tap_action"
        const val KEY_OCTA_TAP_ACTION = "octa_tap_action"
        const val KEY_SENSITIVITY = "sensitivity_threshold"
        const val KEY_HAPTICS = "haptics_enabled"

        // Active singleton instance for checking status & manual test triggers
        var instance: BackTapAccessibilityService? = null
            private set

        // Hooks for Flutter EventChannels (calibration meter & gesture notification stream)
        var sensorSampleCallback: ((jerkSide: Float, jerkTotal: Float, isTap: Boolean) -> Unit)? = null
        var gestureTriggeredCallback: ((TapType, String) -> Unit)? = null

        fun isServiceRunning(): Boolean = instance != null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i(tag, "BackTap Accessibility Service connected")

        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        executor = ActionExecutor(this)
        detector = BackTapDetector(this, this)

        loadConfiguration()

        if (isServiceActive) {
            detector.startListening()
        }

        setupFingerprintGestureController()
    }

    /**
     * Connects to Android's FingerprintGestureController if supported by device hardware.
     */
    private fun setupFingerprintGestureController() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val controller = fingerprintGestureController
                if (controller.isGestureDetectionAvailable) {
                    fingerprintCallback = object : FingerprintGestureController.FingerprintGestureCallback() {
                        override fun onGestureDetected(gesture: Int) {
                            super.onGestureDetected(gesture)
                            Log.i(tag, "Native Fingerprint Gesture detected: $gesture")
                        }
                    }
                    controller.registerFingerprintGestureCallback(fingerprintCallback!!, null)
                }
            } catch (e: Exception) {
                Log.w(tag, "FingerprintGestureController not available on this device: ${e.message}")
            }
        }
    }

    /**
     * Reloads configuration preferences from SharedPreferences.
     */
    fun loadConfiguration() {
        if (!::prefs.isInitialized) {
            prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }

        isServiceActive = prefs.getBoolean(KEY_SERVICE_ACTIVE, true)
        quadTapAction = prefs.getString(KEY_QUAD_TAP_ACTION, "SCREENSHOT") ?: "SCREENSHOT"
        octaTapAction = prefs.getString(KEY_OCTA_TAP_ACTION, "FLASHLIGHT") ?: "FLASHLIGHT"
        sensitivityThreshold = prefs.getFloat(KEY_SENSITIVITY, 18.0f)
        hapticsEnabled = prefs.getBoolean(KEY_HAPTICS, true)

        if (::detector.isInitialized) {
            detector.sensitivityThreshold = sensitivityThreshold
            if (isServiceActive && !detector.isRunning()) {
                detector.startListening()
            } else if (!isServiceActive && detector.isRunning()) {
                detector.stopListening()
            }
        }
    }

    /**
     * Dispatches the corresponding action when a completed tap sequence is recognized.
     */
    override fun onSideTap(type: TapType) {
        if (!isServiceActive) return

        val actionToExecute = when (type) {
            TapType.QUAD_TAP -> quadTapAction
            TapType.OCTA_TAP -> octaTapAction
        }

        Log.i(tag, "Recognized $type -> Executing $actionToExecute")
        executor.executeAction(actionToExecute, this, hapticsEnabled)
        gestureTriggeredCallback?.invoke(type, actionToExecute)
    }

    override fun onSensorSample(jerkSide: Float, jerkTotal: Float, isTapPeak: Boolean) {
        sensorSampleCallback?.invoke(jerkSide, jerkTotal, isTapPeak)
    }

    /**
     * Executes manual test action from Flutter UI.
     */
    fun executeManualAction(actionId: String): Boolean {
        if (!::executor.isInitialized) {
            executor = ActionExecutor(this)
        }
        return executor.executeAction(actionId, this, hapticsEnabled)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Privacy preserved: No UI tree inspection or text harvesting
    }

    override fun onInterrupt() {
        Log.w(tag, "BackTap Accessibility Service interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::detector.isInitialized) {
            detector.stopListening()
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && fingerprintCallback != null) {
            try {
                fingerprintGestureController.unregisterFingerprintGestureCallback(fingerprintCallback)
            } catch (_: Exception) {}
        }
        instance = null
        Log.i(tag, "BackTap Accessibility Service destroyed")
    }
}
