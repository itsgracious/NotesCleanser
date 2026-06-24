import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note_photo.dart';
import '../services/scan_provider.dart';

class DetailScreen extends StatelessWidget {
  final NotePhoto notePhoto;

  const DetailScreen({super.key, required this.notePhoto});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<ScanProvider>(context);

    // Find the latest state of this photo in the provider
    final currentPhoto = provider.notePhotos.firstWhere(
      (p) => p.asset.id == notePhoto.asset.id,
      orElse: () => notePhoto,
    );

    final asset = currentPhoto.asset;
    final date = asset.createDateTime;
    final formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} "
        "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    final resolution = "${asset.width} × ${asset.height}";
    final confidencePercent = (currentPhoto.confidence * 100).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: const Color(0xFF151412), // Dark editorial background for image preview
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFFFFDF9),
        title: const Text(
          'Photo Inspection',
          style: TextStyle(color: Color(0xFFFFFDF9)),
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
            // Full Image View
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: FutureBuilder<File?>(
                  future: asset.file,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done &&
                        snapshot.data != null) {
                      return InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Hero(
                          tag: notePhoto.asset.id,
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
                  _buildMetadataRow('Date Taken', formattedDate, theme),
                  _buildMetadataRow('Resolution', resolution, theme),
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
                            currentPhoto.isSelected ? 'Will be permanently deleted' : 'Will be kept in gallery',
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
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: highlight ? theme.colorScheme.error : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
