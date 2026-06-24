import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';

class NotePhoto {
  final AssetEntity? asset;
  final double confidence;
  bool isSelected;
  final int sizeBytes;
  final DateTime dateTime;

  // PDF-specific properties
  final bool isPdf;
  final String? filePath;
  final String? displayName;
  final Uint8List? pdfThumbnail;

  NotePhoto({
    this.asset,
    required this.confidence,
    this.isSelected = true,
    this.sizeBytes = 0,
    required this.dateTime,
    this.isPdf = false,
    this.filePath,
    this.displayName,
    this.pdfThumbnail,
  });
}
