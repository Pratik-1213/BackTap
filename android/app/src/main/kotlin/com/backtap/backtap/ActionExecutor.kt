package com.backtap.backtap

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/**
 * ActionExecutor centralizes system action execution for BackTap.
 *
 * Supported Actions:
 * - SCREENSHOT: Global screenshot capture via AccessibilityService (API 28+)
 * - FLASHLIGHT: Hardware torch toggle via CameraManager
 * - LOCK_SCREEN: Global screen lock (API 28+)
 * - NOTIFICATIONS: Pulls down system notification shade
 * - HOME / BACK / RECENTS: System navigation actions
 * - MUTE_VOLUME: Audio volume toggle
 * - Haptics: Tactile feedback confirmation on recognized gestures
 */
class ActionExecutor(private val context: Context) {

    private val tag = "ActionExecutor"
    private var isTorchOn = false
    private val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    // Vibrator instance with compatibility across Android 12+ (VibratorManager) and older versions
    private val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
        vibratorManager.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    }

    init {
        // Track torch status changes from other system apps (e.g., Quick Settings tile)
        try {
            cameraManager.registerTorchCallback(object : CameraManager.TorchCallback() {
                override fun onTorchModeChanged(cameraId: String, enabled: Boolean) {
                    super.onTorchModeChanged(cameraId, enabled)
                    isTorchOn = enabled
                }
            }, null)
        } catch (e: Exception) {
            Log.e(tag, "Failed to register torch callback: ${e.message}")
        }
    }

    /**
     * Executes the requested action by string ID.
     * @param actionId Action identifier (e.g., "SCREENSHOT", "FLASHLIGHT")
     * @param service Active AccessibilityService instance for global actions
     * @param hapticsEnabled Whether to trigger a tactile vibration confirmation
     */
    fun executeAction(actionId: String, service: AccessibilityService?, hapticsEnabled: Boolean): Boolean {
        if (hapticsEnabled) {
            vibrateFeedback()
        }

        return when (actionId.uppercase()) {
            "SCREENSHOT" -> {
                if (service != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_TAKE_SCREENSHOT)
                } else {
                    Log.w(tag, "Screenshot requires active AccessibilityService on Android 9+ (API 28)")
                    false
                }
            }
            "FLASHLIGHT" -> {
                toggleFlashlight()
            }
            "LOCK_SCREEN" -> {
                if (service != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_LOCK_SCREEN)
                } else {
                    false
                }
            }
            "NOTIFICATIONS" -> {
                service?.performGlobalAction(AccessibilityService.GLOBAL_ACTION_NOTIFICATIONS) ?: false
            }
            "HOME" -> {
                service?.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME) ?: false
            }
            "BACK" -> {
                service?.performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK) ?: false
            }
            "RECENTS" -> {
                service?.performGlobalAction(AccessibilityService.GLOBAL_ACTION_RECENTS) ?: false
            }
            "MUTE_VOLUME" -> {
                try {
                    audioManager.adjustVolume(AudioManager.ADJUST_TOGGLE_MUTE, AudioManager.FLAG_SHOW_UI)
                    true
                } catch (e: Exception) {
                    Log.e(tag, "Error muting volume: ${e.message}")
                    false
                }
            }
            else -> {
                Log.w(tag, "Unknown action: $actionId")
                false
            }
        }
    }

    /**
     * Toggles the phone's rear LED camera torch.
     */
    fun toggleFlashlight(): Boolean {
        return try {
            val cameraId = getCameraWithFlash() ?: return false
            isTorchOn = !isTorchOn
            cameraManager.setTorchMode(cameraId, isTorchOn)
            true
        } catch (e: Exception) {
            Log.e(tag, "Error toggling flashlight: ${e.message}")
            false
        }
    }

    /**
     * Finds the camera ID that supports flashlight.
     */
    private fun getCameraWithFlash(): String? {
        return try {
            cameraManager.cameraIdList.firstOrNull { id ->
                val characteristics = cameraManager.getCameraCharacteristics(id)
                characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Emits a crisp, short tactile vibration (55ms).
     */
    private fun vibrateFeedback() {
        try {
            vibrator?.let {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    it.vibrate(VibrationEffect.createOneShot(55, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    it.vibrate(55)
                }
            }
        } catch (e: Exception) {
            Log.e(tag, "Vibration failed: ${e.message}")
        }
    }
}
