import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/note_photo.dart';
import 'note_classifier.dart';
import 'notification_service.dart';
import 'pdf_scanner_service.dart';

enum ScanType { images, pdfs }
enum SortOption { modelScore, dateNewer, dateOlder, sizeGreater, sizeLower }
enum DateFilterOption { allTime, today, last7Days, last30Days, custom }

class ScanProvider extends ChangeNotifier {
  final NoteClassifier _classifier = NoteClassifier();

  ScanType _scanType = ScanType.images;
  ScanType get scanType => _scanType;

  static const double confidenceThreshold = 0.5;

  final List<NotePhoto> _notePhotos = [];
  bool _isScanning = false;
  int _scannedCount = 0;
  int _totalCount = 0;
  int _notesCount = 0;
  bool _isCancelled = false;
  bool _isPaused = false;

  bool get isPaused => _isPaused;

  SortOption _sortOption = SortOption.modelScore;
  DateFilterOption _dateFilterOption = DateFilterOption.allTime;
  DateTimeRange? _customDateRange;

  SortOption get sortOption => _sortOption;
  DateFilterOption get dateFilterOption => _dateFilterOption;
  DateTimeRange? get customDateRange => _customDateRange;

  void setSortOption(SortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  void setDateFilterOption(DateFilterOption option, {DateTimeRange? customRange}) {
    _dateFilterOption = option;
    if (option == DateFilterOption.custom) {
      _customDateRange = customRange;
    } else {
      _customDateRange = null;
    }
    notifyListeners();
  }

  List<NotePhoto> get notePhotos {
    final now = DateTime.now();
    List<NotePhoto> results = _notePhotos.where((photo) {
      switch (_dateFilterOption) {
        case DateFilterOption.allTime:
          return true;
        case DateFilterOption.today:
          final todayStart = DateTime(now.year, now.month, now.day);
          return photo.dateTime.isAfter(todayStart);
        case DateFilterOption.last7Days:
          final limit = now.subtract(const Duration(days: 7));
          return photo.dateTime.isAfter(limit);
        case DateFilterOption.last30Days:
          final limit = now.subtract(const Duration(days: 30));
          return photo.dateTime.isAfter(limit);
        case DateFilterOption.custom:
          if (_customDateRange == null) return true;
          final start = _customDateRange!.start;
          final end = _customDateRange!.end.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
          return photo.dateTime.isAfter(start) && photo.dateTime.isBefore(end);
      }
    }).toList();

    switch (_sortOption) {
      case SortOption.modelScore:
        results.sort((a, b) => b.confidence.compareTo(a.confidence));
        break;
      case SortOption.dateNewer:
        results.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        break;
      case SortOption.dateOlder:
        results.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        break;
      case SortOption.sizeGreater:
        results.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
        break;
      case SortOption.sizeLower:
        results.sort((a, b) => a.sizeBytes.compareTo(b.sizeBytes));
        break;
    }

    return results;
  }
  bool get isScanning => _isScanning;
  int get scannedCount => _scannedCount;
  int get totalCount => _totalCount;
  int get notesCount => _notesCount;
  bool get isCancelled => _isCancelled;

  bool get isClassifierInitialized => _classifier.isInitialized;

  /// Calculates the total storage size that will be reclaimed by deleting selected notes
  int get selectedReclaimSize {
    return notePhotos
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

  /// Starts the PDF document scan process
  Future<void> startPdfScan() async {
    _scanType = ScanType.pdfs;
    _isScanning = true;
    _isCancelled = false;
    _isPaused = false;
    _scannedCount = 0;
    _notesCount = 0;
    _totalCount = 0;
    _notePhotos.clear();
    _sortOption = SortOption.modelScore;
    _dateFilterOption = DateFilterOption.allTime;
    _customDateRange = null;
    notifyListeners();

    try {
      // Ensure classifier is initialized
      await initializeClassifier();

      // Locate PDF files in target directories
      final List<File> pdfFiles = await PdfScannerService.locatePdfFiles();
      _totalCount = pdfFiles.length;
      notifyListeners();

      if (_totalCount == 0) {
        _isScanning = false;
        notifyListeners();
        return;
      }

      // Show initial notification
      await NotificationService.updateProgress(0, _totalCount);

      int notificationUpdateCounter = 0;

      for (final file in pdfFiles) {
        if (_isCancelled) break;

        // Non-blocking pause check
        while (_isPaused && !_isCancelled) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (_isCancelled) break;

        try {
          final String path = file.path;
          if (PdfScannerService.isBlacklisted(path)) {
            _scannedCount++;
            notifyListeners();
            continue;
          }

          // Ignore all PDFs under 3 pages (2 pages or fewer) completely to protect personal/govt documents and certificates
          final int pageCount = await PdfScannerService.getPageCount(path);
          if (pageCount < 3) {
            _scannedCount++;
            notifyListeners();
            continue;
          }

          final String name = path.split(Platform.pathSeparator).last;
          final int sizeBytes = await file.length();
          final DateTime lastModified = await file.lastModified();


          // Hybrid classification: name heuristics first
          if (PdfScannerService.hasNoteKeywords(path)) {
            // Render thumbnail for display
            final Uint8List? thumbBytes = await PdfScannerService.renderPageOne(path);
            if (!_isCancelled) {
              _notePhotos.add(NotePhoto(
                confidence: 1.0,
                isSelected: true,
                sizeBytes: sizeBytes,
                dateTime: lastModified,
                isPdf: true,
                filePath: path,
                displayName: name,
                pdfThumbnail: thumbBytes,
              ));
              _notesCount++;
            }
          } else {
            // Fallback: render Page 1 and run TFLite classification
            final Uint8List? thumbBytes = await PdfScannerService.renderPageOne(path);
            if (thumbBytes != null && !_isCancelled) {
              final double confidence = await _classifier.classify(thumbBytes);
              if (confidence >= confidenceThreshold && !_isCancelled) {
                _notePhotos.add(NotePhoto(
                  confidence: confidence,
                  isSelected: true,
                  sizeBytes: sizeBytes,
                  dateTime: lastModified,
                  isPdf: true,
                  filePath: path,
                  displayName: name,
                  pdfThumbnail: thumbBytes,
                ));
                _notesCount++;
              }
            }
          }
        } catch (e) {
          print('Error classifying PDF ${file.path}: $e');
        }

        _scannedCount++;
        notifyListeners();

        // Update notifications every 5 documents to prevent notification engine throttling
        notificationUpdateCounter++;
        if (notificationUpdateCounter >= 5) {
          notificationUpdateCounter = 0;
          await NotificationService.updateProgress(_scannedCount, _totalCount);
        }

        // Give time for UI threads to execute smoothly
        await Future.delayed(Duration.zero);
      }

      // Finish or stop service
      if (!_isCancelled) {
        await NotificationService.updateProgress(_scannedCount, _totalCount, isComplete: true);
      } else {
        await NotificationService.stopService();
      }
    } catch (e) {
      print('PDF Scan process error: $e');
      await NotificationService.stopService();
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Starts the gallery scan process
  Future<void> startScan({List<AssetPathEntity>? selectedAlbums}) async {
    _scanType = ScanType.images;
    _isScanning = true;
    _isCancelled = false;
    _isPaused = false;

    _scannedCount = 0;
    _notesCount = 0;
    _totalCount = 0;
    _notePhotos.clear();
    _sortOption = SortOption.modelScore;
    _dateFilterOption = DateFilterOption.allTime;
    _customDateRange = null;
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

            // Non-blocking pause check
            while (_isPaused && !_isCancelled) {
              await Future.delayed(const Duration(milliseconds: 100));
            }
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
                // Skip if blacklisted by filename title (Aadhaar, certificates, etc.)
                if (asset.title != null && PdfScannerService.isBlacklisted(asset.title!)) {
                  scannedInChunk++;
                  return;
                }
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
                        dateTime: asset.createDateTime,
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
    _isPaused = false;
    _isScanning = false;
    NotificationService.stopService();
    notifyListeners();
  }

  /// Pauses the ongoing scan
  void pauseScan() {
    if (_isScanning) {
      _isPaused = true;
      notifyListeners();
    }
  }

  /// Resumes the ongoing scan
  void resumeScan() {
    _isPaused = false;
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

  /// Toggles selection for all currently visible (filtered) note photos
  void selectAll(bool isSelected) {
    for (final photo in notePhotos) {
      photo.isSelected = isSelected;
    }
    notifyListeners();
  }

  /// Permanently deletes the selected photos or PDF files
  /// Returns the number of successfully deleted items.
  Future<int> deleteSelectedPhotos() async {
    final List<NotePhoto> selectedPhotos =
        notePhotos.where((p) => p.isSelected).toList();

    if (selectedPhotos.isEmpty) return 0;

    if (_scanType == ScanType.pdfs) {
      int deletedCount = 0;
      final List<NotePhoto> toRemove = [];
      for (final photo in selectedPhotos) {
        if (photo.isPdf && photo.filePath != null) {
          try {
            final file = File(photo.filePath!);
            if (await file.exists()) {
              await file.delete();
            }
            toRemove.add(photo);
            deletedCount++;
          } catch (e) {
            print('Error deleting PDF file ${photo.filePath}: $e');
          }
        }
      }
      _notePhotos.removeWhere((photo) => toRemove.contains(photo));
      _notesCount = _notePhotos.length;
      notifyListeners();
      return deletedCount;
    } else {
      final List<String> ids = selectedPhotos
          .where((p) => p.asset != null)
          .map((p) => p.asset!.id)
          .toList();

      if (ids.isEmpty) return 0;

      try {
        // PhotoManager handles triggering the system delete prompt
        final List<String> deletedIds = await PhotoManager.editor.deleteWithIds(ids);

        // Remove successfully deleted items from the list
        _notePhotos.removeWhere((photo) => photo.asset != null && deletedIds.contains(photo.asset!.id));
        _notesCount = _notePhotos.length;
        notifyListeners();

        return deletedIds.length;
      } catch (e) {
        print('Error deleting assets: $e');
        return 0;
      }
    }
  }


  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }
}

