# NotesCleanser

NotesCleanser is a privacy-first, 100% on-device Flutter mobile application designed to scan your phone's photo gallery, identify handwritten notes, printed documents, whiteboards, and text screenshots using a TensorFlow Lite model, and allow you to review and permanently delete them to free up device storage.

## Features

- **100% On-Device Processing**: No image, thumbnail, pixel, or metadata is ever sent over the network. Runs completely local.
- **Fast Gallery Scanning**: Reads and processes assets in pages of 50 to avoid choking memory on large galleries.
- **Dynamic Label Resolution**: Parses `labels.txt` at runtime to match categories dynamically instead of using hardcoded assumptions.
- **Robust Image Classification**: Preprocesses native OS thumbnail bytes (224x224, float32, normalized to `[-1, 1]`) through a local TensorFlow Lite interpreter.
- **Comprehensive Review System**: Presents classified note-photos in a beautiful, responsive 3-column grid featuring confidence badges and checkboxes (selected by default).
- **Interactive Inspection**: Tap any photo to open a high-res inspection view containing file metadata (resolution, date taken) and toggle status.
- **Safe Deletion**: Deletes marked assets using the native OS media editor API (requiring explicit system permission confirmation).

## Project Structure

```text
lib/
├── main.dart             # App entry, warm-neutral Theme, and state injection
├── models/
│   └── note_photo.dart   # NotePhoto wrapper (AssetEntity, confidence, selection status)
├── services/
│   ├── note_classifier.dart # Loads TFLite model, preprocesses image, runs inference
│   └── scan_provider.dart   # Gallery scanner state machine, pagination, and deletion
└── screens/
    ├── home_screen.dart     # Homepage description, privacy cards, runtime permission checker
    ├── scanning_screen.dart # Realtime scanning progress tracker and canceller
    ├── results_screen.dart  # Responsive review grid with selection controls and deletion dialog
    └── detail_screen.dart   # Fullscreen inspector, metadata viewer, and inclusion switch
```

## Setup & Model Installation

The application expects the pre-trained TensorFlow Lite classification model and label text files to be located in the `assets/` folder of the project root:

1. **Model Path**: `assets/model_unquant.tflite`
2. **Labels Path**: `assets/labels.txt`

The `assets/labels.txt` should contain the labels line-by-line, e.g.:
```text
0 notes
1 not notes
```
*(The `NoteClassifier` parses this file dynamically at startup to identify which index maps to "notes").*

The files are registered in `pubspec.yaml` as assets:
```yaml
flutter:
  assets:
    - assets/model_unquant.tflite
    - assets/labels.txt
```

### Android Gradle Configuration

To support binary TensorFlow Lite operations and prevent compression of model assets (which causes loading errors):

1. **Gradle AAPT Options**: In `android/app/build.gradle.kts`, `aaptOptions` are configured to prevent compression of `.tflite` and `.lite` files:
   ```kotlin
   aaptOptions {
       noCompress("tflite")
       noCompress("lite")
   }
   ```
2. **Minimum SDK Version**: The `minSdk` is configured to `21` to satisfy the requirements of `tflite_flutter` and `photo_manager`.

## Running the Application

Ensure you have a Flutter environment set up (stable channel). You can run a health check on the environment using:
```bash
flutter doctor
```

### 1. Retrieve Packages
Fetch the required dependencies from pub.dev:
```bash
flutter pub get
```

### 2. Run the App
Connect a physical device or open a mobile emulator, and execute:
```bash
flutter run
```
*Note: Due to hardware-accelerated image analysis and local TensorFlow execution, running on a physical device is highly recommended for optimal performance.*
