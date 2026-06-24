import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/scan_provider.dart';
import '../models/note_photo.dart';
import 'detail_screen.dart';
import '../widgets/bouncy_tap.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showMLWarningDialog();
    });
  }

  void _showMLWarningDialog() {
    final theme = Theme.of(context);
    final provider = Provider.of<ScanProvider>(context, listen: false);
    if (provider.notePhotos.isEmpty) return; // Don't show if there are no notes scanned

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.error,
                size: 28,
              ),
              const SizedBox(width: 10),
              const Text('Review Results'),
            ],
          ),
          content: const Text(
            'Please review all scanned documents carefully to check if they are notes or not. '
            'Since machine learning models can make mistakes, some of your personal certificates, IDs, or other non-note documents might be listed.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'I Understand',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, ScanProvider provider) {
    final theme = Theme.of(context);
    final selectedCount = provider.notePhotos.where((p) => p.isSelected).length;
    final isPdf = provider.scanType == ScanType.pdfs;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            isPdf ? 'Delete $selectedCount Documents?' : 'Delete $selectedCount Photos?',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: isPdf
                      ? 'This will permanently delete $selectedCount PDF files from your storage and reclaim ${provider.formattedSelectedReclaimSize} of storage space. This can\'t be undone.'
                      : 'This will permanently delete $selectedCount photos from your gallery and reclaim ${provider.formattedSelectedReclaimSize} of storage space. This can\'t be undone.',
                ),
                TextSpan(
                  text: '\n\nWarning: Please ensure no critical government IDs (e.g. Aadhaar, PAN), certificates, or personal documents are included in the selection.',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
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
                      content: Text(isPdf ? 'Successfully deleted $deletedCount documents.' : 'Successfully deleted $deletedCount photos.'),
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
                      content: Text(isPdf ? 'No documents were deleted.' : 'No photos were deleted.'),
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
      body: provider.notesCount == 0
          ? SafeArea(child: _buildEmptyState(context, theme))
          : Stack(
              children: [
                // 1. Grid View (rendered first as bottom layer so it scrolls under overlays)
                Positioned.fill(
                  child: totalCount == 0
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 150.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.filter_list_off_rounded,
                                  size: 60,
                                  color: theme.colorScheme.secondary.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No matching results',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try changing your date filter.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 235, // Custom top bar spacing
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
                            Container(
                              margin: const EdgeInsets.only(left: 12, right: 12, bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.error.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: theme.colorScheme.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Please review selected files carefully to ensure no government documents, certificates, or personal IDs (like Aadhaar, PAN) are deleted.',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.error,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Sort & Filter Selector Row
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildSortDropdown(context, theme, provider),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildDateFilterDropdown(context, theme, provider),
                                  ),
                                ],
                              ),
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
                                      ? 'Delete $selectedCount ${provider.scanType == ScanType.pdfs ? 'documents' : 'photos'} (${provider.formattedSelectedReclaimSize})'
                                      : 'Delete $selectedCount ${provider.scanType == ScanType.pdfs ? 'documents' : 'photos'}',
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
    final provider = Provider.of<ScanProvider>(context, listen: false);
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
            provider.scanType == ScanType.pdfs
                ? 'No note PDF documents were found in high-yield folders.'
                : 'No note photos, documents, or whiteboards were found.',
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

  Widget _buildSortDropdown(BuildContext context, ThemeData theme, ScanProvider provider) {
    String label = 'Confidence';
    IconData icon = Icons.analytics_rounded;
    switch (provider.sortOption) {
      case SortOption.modelScore:
        label = 'Confidence';
        icon = Icons.analytics_rounded;
        break;
      case SortOption.dateNewer:
        label = 'Newest First';
        icon = Icons.calendar_today_rounded;
        break;
      case SortOption.dateOlder:
        label = 'Oldest First';
        icon = Icons.calendar_today_rounded;
        break;
      case SortOption.sizeGreater:
        label = 'Largest First';
        icon = Icons.storage_rounded;
        break;
      case SortOption.sizeLower:
        label = 'Smallest First';
        icon = Icons.storage_rounded;
        break;
    }

    return BouncyTap(
      onTap: () {},
      child: PopupMenuButton<SortOption>(
        initialValue: provider.sortOption,
        onSelected: (SortOption option) {
          provider.setSortOption(option);
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
          const PopupMenuItem<SortOption>(
            value: SortOption.modelScore,
            child: Row(
              children: [
                Icon(Icons.analytics_rounded, size: 18),
                SizedBox(width: 8),
                Text('Confidence'),
              ],
            ),
          ),
          const PopupMenuItem<SortOption>(
            value: SortOption.dateNewer,
            child: Row(
              children: [
                Icon(Icons.arrow_downward_rounded, size: 18),
                SizedBox(width: 8),
                Text('Newest First'),
              ],
            ),
          ),
          const PopupMenuItem<SortOption>(
            value: SortOption.dateOlder,
            child: Row(
              children: [
                Icon(Icons.arrow_upward_rounded, size: 18),
                SizedBox(width: 8),
                Text('Oldest First'),
              ],
            ),
          ),
          const PopupMenuItem<SortOption>(
            value: SortOption.sizeGreater,
            child: Row(
              children: [
                Icon(Icons.storage_rounded, size: 18),
                SizedBox(width: 8),
                Text('Largest First'),
              ],
            ),
          ),
          const PopupMenuItem<SortOption>(
            value: SortOption.sizeLower,
            child: Row(
              children: [
                Icon(Icons.storage_rounded, size: 18),
                SizedBox(width: 8),
                Text('Smallest First'),
              ],
            ),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.surfaceVariant,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: theme.colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Icon(Icons.arrow_drop_down_rounded, color: theme.colorScheme.secondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterDropdown(BuildContext context, ThemeData theme, ScanProvider provider) {
    String label = 'All Time';
    IconData icon = Icons.date_range_rounded;
    switch (provider.dateFilterOption) {
      case DateFilterOption.allTime:
        label = 'All Time';
        break;
      case DateFilterOption.today:
        label = 'Today';
        break;
      case DateFilterOption.last7Days:
        label = 'Last 7 Days';
        break;
      case DateFilterOption.last30Days:
        label = 'Last 30 Days';
        break;
      case DateFilterOption.custom:
        if (provider.customDateRange != null) {
          final start = provider.customDateRange!.start;
          final end = provider.customDateRange!.end;
          final startStr = "${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${(start.year % 100).toString().padLeft(2, '0')}";
          final endStr = "${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${(end.year % 100).toString().padLeft(2, '0')}";
          label = "$startStr - $endStr";
        } else {
          label = 'Custom...';
        }
        break;
    }

    return BouncyTap(
      onTap: () {},
      child: PopupMenuButton<DateFilterOption>(
        initialValue: provider.dateFilterOption,
        onSelected: (DateFilterOption option) async {
          if (option == DateFilterOption.custom) {
            _showCustomDateRangeSheet(context, theme, provider);
          } else {
            provider.setDateFilterOption(option);
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<DateFilterOption>>[
          const PopupMenuItem<DateFilterOption>(
            value: DateFilterOption.allTime,
            child: Row(
              children: [
                Icon(Icons.date_range_rounded, size: 18),
                SizedBox(width: 8),
                Text('All Time'),
              ],
            ),
          ),
          const PopupMenuItem<DateFilterOption>(
            value: DateFilterOption.today,
            child: Row(
              children: [
                Icon(Icons.today_rounded, size: 18),
                SizedBox(width: 8),
                Text('Today'),
              ],
            ),
          ),
          const PopupMenuItem<DateFilterOption>(
            value: DateFilterOption.last7Days,
            child: Row(
              children: [
                Icon(Icons.calendar_view_week_rounded, size: 18),
                SizedBox(width: 8),
                Text('Last 7 Days'),
              ],
            ),
          ),
          const PopupMenuItem<DateFilterOption>(
            value: DateFilterOption.last30Days,
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 18),
                SizedBox(width: 8),
                Text('Last 30 Days'),
              ],
            ),
          ),
          const PopupMenuItem<DateFilterOption>(
            value: DateFilterOption.custom,
            child: Row(
              children: [
                Icon(Icons.edit_calendar_rounded, size: 18),
                SizedBox(width: 8),
                Text('Custom Range...'),
              ],
            ),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.surfaceVariant,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: theme.colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Icon(Icons.arrow_drop_down_rounded, color: theme.colorScheme.secondary),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomDateRangeSheet(BuildContext context, ThemeData theme, ScanProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _CustomDateRangeSheet(provider: provider);
      },
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
    final heroTag = photo.isPdf
        ? (photo.filePath ?? photo.displayName ?? 'pdf_${photo.hashCode}')
        : photo.asset!.id;

    Widget thumbnailWidget;
    if (photo.isPdf) {
      thumbnailWidget = photo.pdfThumbnail != null
          ? Image.memory(
              photo.pdfThumbnail!,
              fit: BoxFit.cover,
            )
          : Container(
              color: theme.colorScheme.surfaceVariant,
              child: Center(
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 40,
                  color: theme.colorScheme.error,
                ),
              ),
            );
    } else {
      thumbnailWidget = FutureBuilder<Uint8List?>(
        future: photo.asset!.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
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
      );
    }

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
              child: Hero(
                tag: heroTag,
                child: thumbnailWidget,
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

        // 3. PDF Label Badge (Top-Left)
        if (photo.isPdf)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'PDF',
                style: TextStyle(
                  color: theme.colorScheme.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // 4. Filename overlay (Bottom)
        if (photo.isPdf && photo.displayName != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Text(
                photo.displayName!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

        // 5. Confidence Score Badge (Only for TFLite evaluated items, if not keyword-matched at 100%)
        if (!photo.isPdf || photo.confidence < 1.0)
          Positioned(
            bottom: photo.isPdf ? 20 : 8, // shift up for PDF name overlay
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

        // 6. Custom Checkbox Widget (Top-Right)
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

class _CustomDateRangeSheet extends StatefulWidget {
  final ScanProvider provider;
  const _CustomDateRangeSheet({required this.provider});

  @override
  State<_CustomDateRangeSheet> createState() => _CustomDateRangeSheetState();
}

class _CustomDateRangeSheetState extends State<_CustomDateRangeSheet> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final currentRange = widget.provider.customDateRange;
    _startDate = currentRange?.start ?? DateTime.now().subtract(const Duration(days: 7));
    _endDate = currentRange?.end ?? DateTime.now();
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${(date.year % 100).toString().padLeft(2, '0')}";
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: _endDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Select Custom Date Range',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: BouncyTap(
                  onTap: _selectStartDate,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.surfaceVariant,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'START DATE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDate(_startDate),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BouncyTap(
                  onTap: _selectEndDate,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.surfaceVariant,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'END DATE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDate(_endDate),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          BouncyTap(
            onTap: () {
              widget.provider.setDateFilterOption(
                DateFilterOption.custom,
                customRange: DateTimeRange(start: _startDate, end: _endDate),
              );
              Navigator.of(context).pop();
            },
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor: theme.colorScheme.primary,
                disabledForegroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Apply Filter',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

