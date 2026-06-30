# GHIAS Mobile: Autonomous Android Agent (Kairo & Astra)

GHIAS Mobile is a production-grade, hardened cross-platform AI client and autonomous Android agent framework. It integrates local/cloud LLMs (Astra) with a resilient programmatic operating system agent (Kairo) capable of executing multi-step goals directly on Android devices.

---

## 🚀 Key Architectural Subsystems

The codebase is structured under clean architecture guidelines separating native JNI integrations, core reasoning, and interaction layers:

```
[ User Goal ] ──► KairoRuntime ──► TaskPlanner (Goal Decomposer & Step Generator)
                       │
                       ▼
                 KairoExecutor ◄──► ScreenshotTimeline & ActionRecorder (Observability)
                       │
                       ├─► SelfHealingExecutor (A: Accessibility -> B: OCR -> C: Sibling Fallback)
                       │
                       ├─► KairoAccessibility (Hands / Gesture Click / Swipe / Launch)
                       │
                       ├─► ScreenUnderstandingService (Eyes / MediaProjection Capture & ML Kit OCR)
                       │
                       └─► ActionVerifier ──► FailureClassifier & RetryManager (Verification Loop)
```

### 1. Kairo Hands (Accessibility Layer)
*   **Path:** [lib/accessibility/](lib/accessibility) & [android/app/src/main/kotlin/com/ghias/mobile/KairoAccessibilityService.kt](android/app/src/main/kotlin/com/ghias/mobile/KairoAccessibilityService.kt)
*   Integrates Android's Accessibility APIs to retrieve recursive window layout hierarchies, inject gestures (taps and swiping scrolls), and launch target packages.

### 2. Kairo Eyes (Vision & OCR Layer)
*   **Path:** [lib/vision/](lib/vision) & [android/app/src/main/kotlin/com/ghias/mobile/ForegroundCaptureService.kt](android/app/src/main/kotlin/com/ghias/mobile/ForegroundCaptureService.kt)
*   Initializes a `VirtualDisplay` over a native `MediaProjection` foreground service (type: `mediaProjection` for Android 14 compatibility) to stream real-time screen frame buffers.
*   Performs local text recognition using Google Play Services ML Kit OCR, returning pixel bounding boxes and confidence scores.

### 3. Kairo Planner
*   **Path:** [lib/planner/](lib/planner)
*   Decomposes abstract user goals (e.g., *“Open calculator and compute 1+2”*) into concrete step-by-step programmatic actions (`StepType.launch`, `StepType.click`, `StepType.swipe`, `StepType.verify`).

### 4. Kairo Verifier
*   **Path:** [lib/verifier/](lib/verifier)
*   Verifies execution progress by evaluating if screen package names transitioned, text entries registered, or scroll positions shifted. Tags failures into descriptive categories (`nodeNotFound`, `appCrash`, `screenTimeout`, `permissionBlock`) and triggers exponential backoff retries.

### 5. Kairo Memory (Semantic Search Engine)
*   **Path:** [lib/agents/memory/](lib/agents/memory)
*   Utilizes a local pure-Dart Term Frequency-Inverse Document Frequency (TF-IDF) vectorizer and Cosine Similarity equations to retrieve relevant past task logs securely without cloud network dependencies.

### 6. Observability & Resiliency Upgrades
*   **Visual Debug Overlay:** A floating HUD displaying current steps, active gestures, target element counts, and real-time execution confidences.
*   **Action Recorder:** Persists step logs and confidence parameters to Hive.
*   **Screenshot Timeline:** Saves JPEG frames (`Step_XX_before.jpg`, `Step_XX_after.jpg`) to local storage for visual debugging.
*   **Self-Healing Actions:** Automatically recovers failed click actions by shifting coordinates from Accessibility Node centers to OCR bounding boxes or nearest sibling targets.
*   **Workflow Recorder:** Listens to user interactions (`TYPE_VIEW_CLICKED` / `TYPE_VIEW_TEXT_CHANGED` accessibility events) to save recorded demonstrations as macros.

---

## 🔒 Security Hardening

*   **Secure Storage:** Sensitive keys, OpenAI/Anthropic tokens, and session credentials are encrypted using `flutter_secure_storage` utilizing KeyStore on Android and Keychain on iOS.
*   **Private Listeners:** The local inference server binds strictly to the loopback target `127.0.0.1` instead of `0.0.0.0`, blocking unauthorized local network interception.

---

## 📱 Sideloading & First Device Run (HyperOS / Android 14)

Follow these steps to safely run the validation test suite on a connected physical device (e.g., Poco X6 Pro):

### 1. Build and Install
1.  Connect your Android device with **USB Debugging** active.
2.  Get dependencies and install the APK:
    ```bash
    flutter pub get
    flutter run lib/device_validation/validation_tests.dart
    ```

### 2. Configure System Permissions
1.  **Allow Restricted Settings (Android 13+ Security):**
    *   Go to **Settings** -> **Apps** -> **Manage Apps** -> **GHIAS Mobile**.
    *   Scroll to the bottom and tap **Allow restricted settings**, then authenticate.
2.  **Enable Accessibility Service:**
    *   Go to **Settings** -> **Additional Settings** -> **Accessibility** -> **Downloaded Apps**.
    *   Select **Kairo Accessibility Service** and toggle it **ON**.
3.  **Grant Screen Capture Authorization:**
    *   Open GHIAS Mobile.
    *   Activate the **Kairo Monitor/Eyes** switch.
    *   On the Android system popup warning, tap **Start Now**.

### 3. Run Automated Validation Tests
With the app active, the test runner executes the following suites:
1.  **Calculator Test:** Launches Calculator, clicks `1`, `+`, `2`, `=`, and verifies result `3`.
2.  **Settings Navigation Test:** Launches Android settings and clicks `Display`.
3.  **App Launch Test:** Verifies launch limits.
4.  **Text Entry Test:** Enters text in active input nodes.
5.  **Scroll Test:** Injects swipe gestures and verifies coordinate shifts.
6.  **Workflow Test:** Runs multi-step goal execution templates.
