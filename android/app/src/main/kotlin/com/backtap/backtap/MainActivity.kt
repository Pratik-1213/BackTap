package com.backtap.backtap

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity acts as the bridge between Flutter and the Android native subsystem.
 *
 * It hosts:
 * 1. MethodChannel "com.backtap.app/channel":
 *    - Accessibility service status & settings launcher
 *    - Battery optimization exemption prompts
 *    - Action test execution
 *    - Saving / loading preferences
 * 2. EventChannel "com.backtap.app/sensor_stream":
 *    - Streams real-time jerk values for the live calibration studio meter
 * 3. EventChannel "com.backtap.app/gesture_stream":
 *    - Streams completed gesture notifications (4x Tap and 8x Tap) to the Flutter UI
 */
class MainActivity : FlutterActivity() {

    private val methodChannelName = "com.backtap.app/channel"
    private val sensorEventChannelName = "com.backtap.app/sensor_stream"
    private val gestureEventChannelName = "com.backtap.app/gesture_stream"

    private var localDetector: BackTapDetector? = null
    private var actionExecutor: ActionExecutor? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        actionExecutor = ActionExecutor(this)

        // MethodChannel for commands, settings, and permission queries
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityServiceEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(true)
                }
                "isBatteryOptimizationIgnored" -> {
                    result.success(isBatteryOptimizationIgnored())
                }
                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(true)
                }
                "isServiceRunning" -> {
                    result.success(BackTapAccessibilityService.isServiceRunning())
                }
                "updateSettings" -> {
                    val quadTapAction = call.argument<String>("quadTapAction") ?: "SCREENSHOT"
                    val octaTapAction = call.argument<String>("octaTapAction") ?: "FLASHLIGHT"
                    val sensitivity = call.argument<Double>("sensitivity")?.toFloat() ?: 18.0f
                    val haptics = call.argument<Boolean>("haptics") ?: true
                    val active = call.argument<Boolean>("active") ?: true

                    saveSettings(quadTapAction, octaTapAction, sensitivity, haptics, active)
                    BackTapAccessibilityService.instance?.loadConfiguration()
                    localDetector?.sensitivityThreshold = sensitivity
                    result.success(true)
                }
                "getSettings" -> {
                    result.success(getStoredSettings())
                }
                "testAction" -> {
                    val actionId = call.argument<String>("actionId") ?: "SCREENSHOT"
                    val service = BackTapAccessibilityService.instance
                    val executed = if (service != null) {
                        service.executeManualAction(actionId)
                    } else {
                        actionExecutor?.executeAction(actionId, null, true) ?: false
                    }
                    result.success(executed)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // EventChannel for real-time sensor calibration visualization
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, sensorEventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    // Hook into background service callback if active
                    BackTapAccessibilityService.sensorSampleCallback = { jerkSide, jerkTotal, isTap ->
                        runOnUiThread {
                            events?.success(
                                mapOf(
                                    "jerkSide" to jerkSide.toDouble(),
                                    "jerkTotal" to jerkTotal.toDouble(),
                                    "isTap" to isTap
                                )
                            )
                        }
                    }

                    // Also run local detector if service is not active so user can calibrate within the app
                    if (!BackTapAccessibilityService.isServiceRunning()) {
                        val currentSensitivity = getStoredSensitivity()
                        localDetector = BackTapDetector(this@MainActivity, object : BackTapListener {
                            override fun onSideTap(type: TapType) {
                                // Handled in gesture stream
                            }

                            override fun onSensorSample(jerkSide: Float, jerkTotal: Float, isTapPeak: Boolean) {
                                runOnUiThread {
                                    events?.success(
                                        mapOf(
                                            "jerkSide" to jerkSide.toDouble(),
                                            "jerkTotal" to jerkTotal.toDouble(),
                                            "isTap" to isTapPeak
                                        )
                                    )
                                }
                            }
                        })
                        localDetector?.sensitivityThreshold = currentSensitivity
                        localDetector?.startListening()
                    }
                }

                override fun onCancel(arguments: Any?) {
                    BackTapAccessibilityService.sensorSampleCallback = null
                    localDetector?.stopListening()
                    localDetector = null
                }
            }
        )

        // EventChannel for detected gesture triggers
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, gestureEventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    BackTapAccessibilityService.gestureTriggeredCallback = { type, action ->
                        runOnUiThread {
                            events?.success(
                                mapOf(
                                    "type" to type.name,
                                    "action" to action
                                )
                            )
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    BackTapAccessibilityService.gestureTriggeredCallback = null
                }
            }
        )
    }

    /**
     * Checks if BackTap's AccessibilityService is enabled in Android system settings.
     */
    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedComponentName = ComponentName(this, BackTapAccessibilityService::class.java)
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)

        while (colonSplitter.hasNext()) {
            val componentNameString = colonSplitter.next()
            val enabledComponent = ComponentName.unflattenFromString(componentNameString)
            if (enabledComponent != null && enabledComponent == expectedComponentName) {
                return true
            }
        }
        return false
    }

    /**
     * Deep-links directly to the Android Accessibility settings screen.
     */
    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    /**
     * Checks if the app is exempt from Android Doze battery optimization.
     */
    private fun isBatteryOptimizationIgnored(): Boolean {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    /**
     * Requests battery optimization exemption so the sensor listener runs uninterrupted.
     */
    private fun requestIgnoreBatteryOptimizations() {
        try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        } catch (e: Exception) {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        }
    }

    private fun saveSettings(
        quadTap: String,
        octaTap: String,
        sensitivity: Float,
        haptics: Boolean,
        active: Boolean
    ) {
        val prefs = getSharedPreferences(BackTapAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(BackTapAccessibilityService.KEY_QUAD_TAP_ACTION, quadTap)
            .putString(BackTapAccessibilityService.KEY_OCTA_TAP_ACTION, octaTap)
            .putFloat(BackTapAccessibilityService.KEY_SENSITIVITY, sensitivity)
            .putBoolean(BackTapAccessibilityService.KEY_HAPTICS, haptics)
            .putBoolean(BackTapAccessibilityService.KEY_SERVICE_ACTIVE, active)
            .apply()
    }

    private fun getStoredSensitivity(): Float {
        val prefs = getSharedPreferences(BackTapAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getFloat(BackTapAccessibilityService.KEY_SENSITIVITY, 18.0f)
    }

    private fun getStoredSettings(): Map<String, Any> {
        val prefs = getSharedPreferences(BackTapAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE)
        return mapOf(
            "quadTapAction" to (prefs.getString(BackTapAccessibilityService.KEY_QUAD_TAP_ACTION, "SCREENSHOT") ?: "SCREENSHOT"),
            "octaTapAction" to (prefs.getString(BackTapAccessibilityService.KEY_OCTA_TAP_ACTION, "FLASHLIGHT") ?: "FLASHLIGHT"),
            "sensitivity" to prefs.getFloat(BackTapAccessibilityService.KEY_SENSITIVITY, 18.0f).toDouble(),
            "haptics" to prefs.getBoolean(BackTapAccessibilityService.KEY_HAPTICS, true),
            "active" to prefs.getBoolean(BackTapAccessibilityService.KEY_SERVICE_ACTIVE, true)
        )
    }

    override fun onDestroy() {
        super.onDestroy()
        localDetector?.stopListening()
        localDetector = null
    }
}
