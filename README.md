# BackTap 📱⚡

A powerful Flutter and native Android application designed specifically for devices with a **side-mounted fingerprint sensor and power button**. It enables multi-tap gestures exclusively for **4x Tap** and **8x Tap** to trigger core system functionalities across any active application.

---

## 🌟 The Two Configured Gesture Options

1. **Tap 4 Times (4x Tap)**:
   - Configured by default to instantly capture a **System Screenshot** (`GLOBAL_ACTION_TAKE_SCREENSHOT`).
2. **Tap 8 Times (8x Tap)**:
   - Configured by default to toggle the **Flashlight / Torch** (`CameraManager.setTorchMode`).

---

## ⚙️ How the 4x and 8x Tap State Machine Works

```
Tap 1 ──> Tap 2 ──> Tap 3 ──> Tap 4 reached
                                 │
              ┌──────────────────┴──────────────────┐
        (User stops tapping)                  (User keeps tapping)
              │                                     │
        Wait 380ms grace                      Tap 5 ──> Tap 6 ──> Tap 7 ──> Tap 8 reached
              │                                                                │
        📸 Take Screenshot                                              🔦 Toggle Flashlight
```

- When you tap 4 times and stop, the app triggers a **Screenshot** after a 380ms grace window.
- When you tap continuously up to 8 times, the 4-tap trigger is automatically canceled and the 8th tap instantly toggles the **Flashlight**!
- Any accidental 1, 2, or 3 taps simply reset without triggering any action.

---

## 🚀 Running on Your Device

```powershell
flutter run
```

1. Open **SideTap**.
2. Tap **Open Accessibility Settings** and ensure **SideTap** is turned ON.
3. Tap **4 times quickly** on the side fingerprint/power button to take a screenshot.
4. Tap **8 times quickly** on the side fingerprint/power button to toggle the flashlight!
