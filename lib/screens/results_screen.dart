import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/scan_provider.dart';
import '../models/note_photo.dart';
import 'detail_screen.dart';
import '../widgets/bouncy_tap.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  void _showDeleteConfirmation(BuildContext context, ScanProvider provider) {
    final theme = Theme.of(context);
    final selectedCount = provider.notePhotos.where((p) => p.isSelected).length;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Delete $selectedCount Photos?',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'This will permanently delete $selectedCount photos from your gallery and reclaim ${provider.formattedSelectedReclaimSize} of storage space. This can\'t be undone.',
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                
                // Show a loading/progress indicator during native deletion
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final deletedCount = await provider.deleteSelectedPhotos();
                
                if (deletedCount > 0) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Successfully deleted $deletedCount photos.'),
                      backgroundColor: theme.colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: const Text('No photos were deleted.'),
                      backgroundColor: theme.colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
              child: Text(
                'Delete',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<ScanProvider>(context);
    final notePhotos = provider.notePhotos;
    final totalCount = notePhotos.length;
    final selectedCount = notePhotos.where((p) => p.isSelected).length;
    final allSelected = totalCount > 0 && selectedCount == totalCount;

    return Scaffold(
      body: totalCount == 0
          ? SafeArea(child: _buildEmptyState(context, theme))
          : Stack(
              children: [
                // 1. Grid View (rendered first as bottom layer so it scrolls under overlays)
                Positioned.fill(
                  child: GridView.builder(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 115, // Custom top bar spacing
                      bottom: MediaQuery.of(context).padding.bottom + 95, // Custom bottom bar spacing
                      left: 12,
                      right: 12,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: totalCount,
                    itemBuilder: (context, index) {
                      final photo = notePhotos[index];
                      return _GridItem(photo: photo, provider: provider);
                    },
                  ),
                ),

                // 2. Custom Glassmorphic Header Navigation Bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 8,
                          bottom: 12,
                          left: 12,
                          right: 20,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.background.withOpacity(0.85),
                          border: Border(
                            bottom: BorderSide(
                              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Review Notes',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$selectedCount of $totalCount selected',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      provider.selectAll(!allSelected);
                                    },
                                    style: TextButton.styleFrom(
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      allSelected ? 'Deselect all' : 'Select all',
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        color: theme.colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Custom Glassmorphic Deletion Action Bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 16,
                          bottom: MediaQuery.of(context).padding.bottom + 16,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.background.withOpacity(0.85),
                          border: Border(
                            top: BorderSide(
                              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                        ),
                        child: BouncyTap(
                          onTap: selectedCount > 0
                              ? () => _showDeleteConfirmation(context, provider)
                              : null,
                          child: ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              disabledBackgroundColor: selectedCount > 0
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.surfaceVariant,
                              disabledForegroundColor: selectedCount > 0
                                  ? theme.colorScheme.onError
                                  : theme.colorScheme.secondary.withOpacity(0.5),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.delete_sweep_rounded,
                                  color: selectedCount > 0
                                      ? theme.colorScheme.onError
                                      : theme.colorScheme.secondary.withOpacity(0.5),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  selectedCount > 0
                                      ? 'Delete $selectedCount photos (${provider.formattedSelectedReclaimSize})'
                                      : 'Delete $selectedCount photos',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: selectedCount > 0
                                        ? theme.colorScheme.onError
                                        : theme.colorScheme.secondary.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.done_all_rounded,
            size: 80,
            color: theme.colorScheme.secondary.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Your gallery is clean',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'No note photos, documents, or whiteboards were found.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Return Home',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridItem extends StatelessWidget {
  final NotePhoto photo;
  final ScanProvider provider;

  const _GridItem({required this.photo, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confidencePercent = (photo.confidence * 100).toInt();

    return Stack(
      children: [
        // 1. Thumbnail Image (Interactive with scale bounce & hero transition)
        Positioned.fill(
          child: BouncyTap(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => DetailScreen(notePhoto: photo),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FutureBuilder<Uint8List?>(
                future: photo.asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.data != null) {
                    return Hero(
                      tag: photo.asset.id,
                      child: Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                      ),
                    );
                  }
                  return Container(
                    color: theme.colorScheme.surfaceVariant,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        
        // 2. Selection Border Highlight
        if (photo.isSelected)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 3,
                  ),
                ),
              ),
            ),
          ),

        // 3. Confidence Score Badge
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$confidencePercent%',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // 4. Custom Top-Right Checkbox Widget (with bouncy press animation)
        Positioned(
          top: 4,
          right: 4,
          child: BouncyTap(
            onTap: () {
              provider.toggleSelection(photo);
            },
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: photo.isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface.withOpacity(0.8),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: photo.isSelected ? theme.colorScheme.primary : const Color(0xFFC6C2B8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: photo.isSelected
                    ? Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: theme.colorScheme.onPrimary,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
