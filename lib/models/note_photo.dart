import 'package:photo_manager/photo_manager.dart';

class NotePhoto {
  final AssetEntity asset;
  final double confidence;
  bool isSelected;
  final int sizeBytes;

  NotePhoto({
    required this.asset,
    required this.confidence,
    this.isSelected = true,
    this.sizeBytes = 0,
  });
}
