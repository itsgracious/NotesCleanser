# Notes Cleanser

Notes Cleanser is a premium, privacy-first, 100% on-device Flutter mobile application designed to scan your phone's photo gallery and PDF documents, identify handwritten notes, printed documents, whiteboards, and text screenshots using a TensorFlow Lite model, and allow you to review and permanently delete them to free up device storage.

## Features

- **100% On-Device Processing**: No image, PDF, thumbnail, pixel, or metadata is ever sent over the network. Runs completely local.
- **Selective Folder & Album Scanning**: Pick specific folders or albums (WhatsApp, Screenshots, Downloads, Camera, etc.) from an elegant custom bottom sheet to run targeted scans.
- **Hybrid PDF Document Scanning**: Automatically scans key PDF directories (Downloads, Documents, CamScanner, WhatsApp, etc.). Features:
  - **Fallback Rasterization**: Rasterizes first page of PDFs to feed into TFLite image classifier.
  - **Course Code Regex Pattern Matching**: Matches course codes (e.g. `CS101`, `MAT_302`) in filenames for instant matches.
- **Safety Exclusions & Government Document Bypass**:
  - **Page-Count Filter**: Automatically ignores and bypasses all PDFs containing 2 pages or fewer (safeguarding short government IDs, receipts, and PAN cards).
  - **Token-Based Blacklist**: Advanced filename token checking bypasses official documents matching keywords (e.g. `aadhaar`, `nia`, `marksheet`, `license`, `certificate`).
- **Interactive Scan Pause & Resume**: Replace generic cancel with a full pause option. Pause freezes scanning background loops. Presents options to **Resume**, **Review** (partially scanned notes), or **Cancel** (discard all). Intercepts the Android hardware back button to trigger the pause overlay.
- **Advanced Sorting & Filtering**:
  - **Sorting**: Order scanned files by Model Confidence, Date (Newer/Older), and Size (Greater/Lower) with background caching.
  - **Date Filters**: Filter files by All Time, Today, Last 7 Days, Last 30 Days, or Custom Date Range.
  - **Smooth Date Picker**: Uses an accessible bottom-sheet date selector with Start Date and End Date cards linked to focused, native calendar views.
- **Tactile Touch Physics (`BouncyTap`)**: Applied a custom scale-animation widget to all buttons, lists, and checkboxes for tactile haptic feedback.
- **Glassmorphic Redesign & Animated Progress**:
  - **Sweeping Progress Ring**: Displays an active rotating 60 FPS sweep gradient indicator mimicking scanning radar.
  - **Translucent Navigation Panels**: Features blurred glassmorphic header and action bars on the Results screen.
- **Storage Reclamation Analytics**: Real-time calculation of byte sizes (`originFile.length()`) to display total reclaimable memory (KB, MB, GB) before deleting.
- **On-Device Notifications**: Sends updates via Android Foreground Services to show active scan progress in the system tray.

## Project Structure

```text
lib/
├── main.dart                 # App entry, warm-neutral Theme, and state injection
├── models/
│   └── note_photo.dart       # NotePhoto wrapper (AssetEntity/File, confidence, sizeBytes, cached dateTime)
├── services/
│   ├── note_classifier.dart  # Loads TFLite model, preprocesses image, runs inference
│   ├── pdf_scanner_service.dart # Handles local PDF file scans, blacklists, and regex rules
│   ├── scan_provider.dart    # Scanning state machine, pagination, pause/resume, and deletion
│   └── notification_service.dart # Handles Android Foreground Service progress updates
├── widgets/
│   └── bouncy_tap.dart       # Reusable tactile touch physics widget
└── screens/
    ├── home_screen.dart      # Homepage description, privacy cards, album bottom sheet
    ├── scanning_screen.dart  # Realtime radar progress tracker, pause/resume overlay
    ├── results_screen.dart   # Glassmorphic review grid, custom sorting, date picker sheet
    ├── detail_screen.dart    # Fullscreen image/PDF inspector, metadata, and selection toggle
    └── splash_screen.dart    # Seamless WebP logo blend, TFLite preloading
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

## Running the Application

### 1. Retrieve Packages
Fetch the required dependencies from pub.dev:
```bash
flutter pub get
```

### 2. Run the App
Connect a physical device or open a mobile emulator, and execute:
```bash
flutter run --release
```
*Note: Due to hardware-accelerated image analysis and local TensorFlow execution, running on a physical device in release mode is highly recommended for optimal performance.*
