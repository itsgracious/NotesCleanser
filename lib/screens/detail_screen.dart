import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdfx/pdfx.dart';
import '../models/note_photo.dart';
import '../services/scan_provider.dart';

class DetailScreen extends StatefulWidget {
  final NotePhoto notePhoto;

  const DetailScreen({super.key, required this.notePhoto});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  PdfController? _pdfController;

  @override
  void initState() {
    super.initState();
    if (widget.notePhoto.isPdf && widget.notePhoto.filePath != null) {
      _pdfController = PdfController(
        document: PdfDocument.openFile(widget.notePhoto.filePath!),
      );
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<ScanProvider>(context);

    // Find the latest state of this item in the provider
    final currentPhoto = provider.notePhotos.firstWhere(
      (p) => p.isPdf
          ? p.filePath == widget.notePhoto.filePath
          : p.asset?.id == widget.notePhoto.asset?.id,
      orElse: () => widget.notePhoto,
    );

    final isPdf = currentPhoto.isPdf;
    String formattedDate = "N/A";
    String resolution = "N/A";
    String fileSizeStr = "0 KB";

    // Format file size
    final int bytes = currentPhoto.sizeBytes;
    if (bytes < 1024) {
      fileSizeStr = "$bytes B";
    } else if (bytes < 1024 * 1024) {
      fileSizeStr = "${(bytes / 1024).toStringAsFixed(1)} KB";
    } else {
      fileSizeStr = "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    }

    if (!isPdf && currentPhoto.asset != null) {
      final asset = currentPhoto.asset!;
      final date = asset.createDateTime;
      formattedDate =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} "
          "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
      resolution = "${asset.width} × ${asset.height}";
    } else if (isPdf && currentPhoto.filePath != null) {
      try {
        final file = File(currentPhoto.filePath!);
        final date = file.lastModifiedSync();
        formattedDate =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} "
            "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
      } catch (e) {
        print('Error reading file modification date: $e');
      }
    }

    final confidencePercent = (currentPhoto.confidence * 100).toStringAsFixed(1);
    final heroTag = isPdf
        ? (currentPhoto.filePath ?? currentPhoto.displayName ?? 'pdf_${currentPhoto.hashCode}')
        : currentPhoto.asset!.id;

    return Scaffold(
      backgroundColor: const Color(0xFF151412), // Dark editorial background for image preview
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFFFFDF9),
        title: Text(
          isPdf ? 'Document Inspection' : 'Photo Inspection',
          style: const TextStyle(color: Color(0xFFFFFDF9)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFFFFDF9)),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Preview Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: isPdf
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _pdfController != null
                            ? PdfView(
                                controller: _pdfController!,
                                scrollDirection: Axis.vertical,
                              )
                            : widget.notePhoto.pdfThumbnail != null
                                ? Hero(
                                    tag: heroTag,
                                    child: Image.memory(
                                      widget.notePhoto.pdfThumbnail!,
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                : const Center(
                                    child: Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
                                  ),
                      )
                    : FutureBuilder<File?>(
                        future: currentPhoto.asset!.file,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done &&
                              snapshot.data != null) {
                            return InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 4.0,
                              child: Hero(
                                tag: heroTag,
                                child: Image.file(
                                  snapshot.data!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            );
                          }
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFFFDF9),
                            ),
                          );
                        },
                      ),
              ),
            ),
            // Bottom Info & Controls Sheet
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFFFFDF9), // Warm white cards background
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Detection Metadata',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Metadata Info Table
                  _buildMetadataRow('Classification', 'Notes', theme),
                  _buildMetadataRow('Model Confidence', '$confidencePercent%', theme, highlight: true),
                  _buildMetadataRow('File Size', fileSizeStr, theme),
                  if (!isPdf) _buildMetadataRow('Resolution', resolution, theme),
                  _buildMetadataRow(isPdf ? 'Last Modified' : 'Date Taken', formattedDate, theme),
                  if (isPdf && currentPhoto.displayName != null)
                    _buildMetadataRow('Filename', currentPhoto.displayName!, theme),
                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFE6E2D8)),
                  const SizedBox(height: 12),
                  // Pending Deletion Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mark for Deletion',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: currentPhoto.isSelected ? theme.colorScheme.error : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentPhoto.isSelected
                                ? 'Will be permanently deleted'
                                : isPdf
                                    ? 'Will be kept in storage'
                                    : 'Will be kept in gallery',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      Switch(
                        value: currentPhoto.isSelected,
                        activeColor: theme.colorScheme.onError,
                        activeTrackColor: theme.colorScheme.error,
                        inactiveThumbColor: theme.colorScheme.secondary,
                        inactiveTrackColor: theme.colorScheme.surfaceVariant,
                        onChanged: (value) {
                          provider.setSelection(currentPhoto, value);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value, ThemeData theme, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: highlight ? theme.colorScheme.error : theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
