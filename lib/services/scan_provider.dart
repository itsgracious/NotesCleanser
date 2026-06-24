import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/note_photo.dart';
import 'note_classifier.dart';
import 'notification_service.dart';

class ScanProvider extends ChangeNotifier {
  final NoteClassifier _classifier = NoteClassifier();

  static const double confidenceThreshold = 0.5;

  final List<NotePhoto> _notePhotos = [];
  bool _isScanning = false;
  int _scannedCount = 0;
  int _totalCount = 0;
  int _notesCount = 0;
  bool _isCancelled = false;

  List<NotePhoto> get notePhotos {
    _notePhotos.sort((a, b) => b.confidence.compareTo(a.confidence));
    return _notePhotos;
  }
  bool get isScanning => _isScanning;
  int get scannedCount => _scannedCount;
  int get totalCount => _totalCount;
  int get notesCount => _notesCount;
  bool get isCancelled => _isCancelled;

  bool get isClassifierInitialized => _classifier.isInitialized;

  /// Calculates the total storage size that will be reclaimed by deleting selected notes
  int get selectedReclaimSize {
    return _notePhotos
        .where((p) => p.isSelected)
        .fold(0, (sum, photo) => sum + photo.sizeBytes);
  }

  /// Formats the reclaimable space into a human-readable string
  String get formattedSelectedReclaimSize {
    final int bytes = selectedReclaimSize;
    if (bytes <= 0) return "0 B";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
  }

  /// Initialize the classifier service once
  Future<void> initializeClassifier() async {
    if (!_classifier.isInitialized) {
      await _classifier.initialize();
    }
  }

  /// Starts the gallery scan process
  Future<void> startScan({List<AssetPathEntity>? selectedAlbums}) async {
    _isScanning = true;
    _isCancelled = false;
    _scannedCount = 0;
    _notesCount = 0;
    _totalCount = 0;
    _notePhotos.clear();
    notifyListeners();

    try {
      // Ensure classifier is initialized
      await initializeClassifier();

      List<AssetPathEntity> albumsToScan = [];

      if (selectedAlbums == null || selectedAlbums.isEmpty) {
        // Retrieve list of paths/albums
        final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
          type: RequestType.image,
        );

        if (paths.isEmpty) {
          _isScanning = false;
          notifyListeners();
          return;
        }

        // Find the primary album containing all photos
        final AssetPathEntity allPhotosAlbum = paths.firstWhere(
          (path) => path.isAll,
          orElse: () => paths.first,
        );
        albumsToScan.add(allPhotosAlbum);
      } else {
        albumsToScan.addAll(selectedAlbums);
      }

      // Calculate total count across all selected albums
      for (final album in albumsToScan) {
        _totalCount += await album.assetCountAsync;
      }
      notifyListeners();

      // Show initial notification
      await NotificationService.updateProgress(0, _totalCount);

      int notificationUpdateCounter = 0;
      final Set<String> processedAssetIds = {};

      for (final album in albumsToScan) {
        if (_isCancelled) break;

        final int albumCount = await album.assetCountAsync;
        int page = 0;
        const int pageSize = 50;

        while (page * pageSize < albumCount) {
          if (_isCancelled) break;

          // Paginate internally in batches of 50 so it doesn't choke on large galleries
          final List<AssetEntity> assets = await album.getAssetListPaged(
            page: page,
            size: pageSize,
          );

          // Process assets in concurrent batches of 8 to saturate CPU cores and overlap I/O latency
          const int concurrencyLimit = 8;
          for (int i = 0; i < assets.length; i += concurrencyLimit) {
            if (_isCancelled) break;

            final List<AssetEntity> chunk = assets.sublist(
              i,
              (i + concurrencyLimit > assets.length) ? assets.length : i + concurrencyLimit,
            );

            int scannedInChunk = 0;

            await Future.wait(chunk.map((asset) async {
              if (_isCancelled) return;

              // Avoid double-processing if an asset belongs to multiple checked albums
              if (processedAssetIds.contains(asset.id)) {
                scannedInChunk++;
                return;
              }
              processedAssetIds.add(asset.id);

              try {
                // Fetch thumbnail of size 224x224 directly from the native OS with 60% quality optimization
                final Uint8List? thumbBytes = await asset.thumbnailDataWithOption(
                  const ThumbnailOption(
                    size: ThumbnailSize(224, 224),
                    quality: 60,
                  ),
                );

                if (thumbBytes != null && !_isCancelled) {
                  final double confidence = await _classifier.classify(thumbBytes);
                  if (confidence >= confidenceThreshold && !_isCancelled) {
                    // Fetch original file size asynchronously
                    final File? file = await asset.originFile;
                    final int sizeBytes = file != null ? await file.length() : 0;

                    if (!_isCancelled) {
                      _notePhotos.add(NotePhoto(
                        asset: asset,
                        confidence: confidence,
                        isSelected: true, // Selected by default
                        sizeBytes: sizeBytes,
                      ));
                      _notesCount++;
                    }
                  }
                }
              } catch (e) {
                print('Error classifying photo ${asset.id}: $e');
              }

              scannedInChunk++;
            }));

            _scannedCount += scannedInChunk;
            notifyListeners();

            // Update notifications every 16 images to prevent notification engine throttling
            notificationUpdateCounter += scannedInChunk;
            if (notificationUpdateCounter >= 16) {
              notificationUpdateCounter = 0;
              await NotificationService.updateProgress(_scannedCount, _totalCount);
            }
          }

          page++;
          // Give time for UI threads to execute smoothly
          await Future.delayed(Duration.zero);
        }
      }

      // Finish or stop service
      if (!_isCancelled) {
        await NotificationService.updateProgress(_scannedCount, _totalCount, isComplete: true);
      } else {
        await NotificationService.stopService();
      }
    } catch (e) {
      print('Scan process error: $e');
      await NotificationService.stopService();
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Cancels the ongoing scan
  void cancelScan() {
    _isCancelled = true;
    _isScanning = false;
    NotificationService.stopService();
    notifyListeners();
  }

  /// Toggles individual photo selection
  void toggleSelection(NotePhoto notePhoto) {
    notePhoto.isSelected = !notePhoto.isSelected;
    notifyListeners();
  }

  /// Explicitly sets individual selection
  void setSelection(NotePhoto notePhoto, bool isSelected) {
    notePhoto.isSelected = isSelected;
    notifyListeners();
  }

  /// Toggles selection for all note photos
  void selectAll(bool isSelected) {
    for (final photo in _notePhotos) {
      photo.isSelected = isSelected;
    }
    notifyListeners();
  }

  /// Permanently deletes the selected photos from the gallery
  /// Returns the number of successfully deleted photos.
  Future<int> deleteSelectedPhotos() async {
    final List<NotePhoto> selectedPhotos =
        _notePhotos.where((p) => p.isSelected).toList();

    if (selectedPhotos.isEmpty) return 0;

    final List<String> ids = selectedPhotos.map((p) => p.asset.id).toList();

    try {
      // PhotoManager handles triggering the system delete prompt
      final List<String> deletedIds = await PhotoManager.editor.deleteWithIds(ids);

      // Remove successfully deleted items from the list
      _notePhotos.removeWhere((photo) => deletedIds.contains(photo.asset.id));
      _notesCount = _notePhotos.length;
      notifyListeners();

      return deletedIds.length;
    } catch (e) {
      print('Error deleting assets: $e');
      return 0;
    }
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }
}

