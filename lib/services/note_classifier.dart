import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Decodes, resizes, and normalizes image bytes to a Float32List input tensor.
/// This runs in a background isolate to prevent blocking the UI thread.
Float32List preprocessImage(Uint8List imageBytes) {
  // Decode image using specialized decoder if possible to speed up
  img.Image? decoded;
  if (imageBytes.length > 2 && imageBytes[0] == 0xFF && imageBytes[1] == 0xD8) {
    decoded = img.JpegDecoder().decode(imageBytes);
  } else if (imageBytes.length > 4 && imageBytes[0] == 0x89 && imageBytes[1] == 0x50 && imageBytes[2] == 0x4E && imageBytes[3] == 0x47) {
    decoded = img.PngDecoder().decode(imageBytes);
  } else {
    decoded = img.decodeImage(imageBytes);
  }

  if (decoded == null) {
    throw ArgumentError('Failed to decode image bytes.');
  }

  // Resize image to 224x224 if it isn't already
  img.Image resized = decoded;
  if (decoded.width != 224 || decoded.height != 224) {
    resized = img.copyResize(decoded, width: 224, height: 224);
  }

  // Model input is 224x224 RGB image, float32, normalized to [-1, 1]
  // Shape: [1, 224, 224, 3]
  final input = Float32List(1 * 224 * 224 * 3);
  var pixelIndex = 0;

  for (var y = 0; y < 224; y++) {
    for (var x = 0; x < 224; x++) {
      final pixel = resized.getPixel(x, y);
      // Normalize: (pixel / 127.5) - 1.0
      input[pixelIndex++] = (pixel.r / 127.5) - 1.0;
      input[pixelIndex++] = (pixel.g / 127.5) - 1.0;
      input[pixelIndex++] = (pixel.b / 127.5) - 1.0;
    }
  }

  return input;
}

class NoteClassifier {
  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  List<String> _labels = [];
  int _notesIndex = 0;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Loads the TFLite model and labels.txt once at startup
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Load the interpreter options with multi-threading (4 threads for Snapdragon performance cores)
      final options = InterpreterOptions()..threads = 4;
      
      // 2. Load the interpreter from assets
      _interpreter = await Interpreter.fromAsset(
        'assets/model_unquant.tflite',
        options: options,
      );

      // 3. Wrap interpreter in IsolateInterpreter to offload inference
      _isolateInterpreter = await IsolateInterpreter.create(
        address: _interpreter!.address,
      );

      // 4. Load and parse labels
      final labelsString = await rootBundle.loadString('assets/labels.txt');
      _labels = labelsString
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      // Dynamic label matching (don't hardcode index assumptions)
      _notesIndex = 0; // Default fallback
      for (int i = 0; i < _labels.length; i++) {
        final label = _labels[i].toLowerCase();
        // A line can be e.g. "0 notes" or "1 not notes"
        final parts = label.split(' ');
        final labelText = parts.length > 1 ? parts.sublist(1).join(' ').trim() : label;
        
        // Exact match for 'notes' (and not 'not notes')
        if (labelText == 'notes') {
          _notesIndex = i;
          break;
        }
      }
      
      _isInitialized = true;
    } catch (e) {
      rethrow;
    }
  }

  /// Classifies a photo's image bytes and returns the "notes" confidence score [0.0, 1.0]
  Future<double> classify(Uint8List imageBytes) async {
    if (!_isInitialized || _interpreter == null || _isolateInterpreter == null) {
      throw StateError('NoteClassifier has not been initialized. Call initialize() first.');
    }

    // 1. Offload image decoding, resizing, and pixel normalization to a background isolate
    final Float32List input = await Isolate.run(() => preprocessImage(imageBytes));

    // 2. Output is 2-class softmax array: [1, 2]
    final output = List<double>.filled(1 * 2, 0.0).reshape([1, 2]);

    try {
      // 3. Run the model asynchronously in the background isolate interpreter
      await _isolateInterpreter!.run(input.reshape([1, 224, 224, 3]), output);

      // Return the notes class confidence
      final double notesConfidence = output[0][_notesIndex];
      return notesConfidence;
    } catch (e) {
      rethrow;
    }
  }

  /// Properly disposes the interpreter when no longer needed
  void dispose() {
    _isolateInterpreter?.close();
    _isolateInterpreter = null;
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}

