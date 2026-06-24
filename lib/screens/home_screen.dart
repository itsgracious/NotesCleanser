import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'scanning_screen.dart';
import '../widgets/bouncy_tap.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _permissionDenied = false;

  Future<void> _handleScanPressed() async {

    // Request permission to access photos using photo_manager's built-in extension
    final PermissionState state = await PhotoManager.requestPermissionExtend();

    if (state.isAuth || state.hasAccess) {
      setState(() {
        _permissionDenied = false;
      });
      // Show Bottom Sheet to select folders
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return _FolderSelectionSheet(
              onStartScan: (selectedAlbums) {
                Navigator.of(context).pop(); // Close bottom sheet
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ScanningScreen(selectedAlbums: selectedAlbums),
                  ),
                );
              },
            );
          },
        );
      }
    } else {
      setState(() {
        _permissionDenied = true;
      });
    }
  }

  Future<void> _handleScanPdfPressed() async {
    // Request manageExternalStorage for Android 11+, falling back to storage for older versions
    PermissionStatus status = await Permission.manageExternalStorage.request();
    if (status.isDenied || status.isPermanentlyDenied || status.isRestricted) {
      status = await Permission.storage.request();
    }

    if (status.isGranted) {
      setState(() {
        _permissionDenied = false;
      });
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ScanningScreen(isPdfScan: true),
          ),
        );
      }
    } else {
      setState(() {
        _permissionDenied = true;
      });
    }
  }

  void _openSettings() {

    PhotoManager.openSetting();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFDF5EC),
          image: DecorationImage(
            image: AssetImage('assets/home_hero.png'),
            alignment: Alignment.topCenter,
            fit: BoxFit.fitWidth,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 3), // Push the controls to the bottom to let the illustration shine
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Notes Cleanser',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontSize: 30,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Reclaim storage by scanning your photo gallery to identify and delete temporary notes, document screenshots, and whiteboard photos.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                              height: 1.45,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          // Integrated Privacy Callout
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  color: theme.colorScheme.primary,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '100% Private on-device scanning. No images ever leave your device.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_permissionDenied) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.error.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Storage / Gallery Access Required',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            color: theme.colorScheme.error,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'To scan files and photos, please enable access in settings.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: _openSettings,
                                    icon: const Icon(Icons.settings_outlined, size: 14),
                                    label: const Text('Open Settings'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: theme.colorScheme.error,
                                      side: BorderSide(color: theme.colorScheme.error),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          BouncyTap(
                            onTap: _handleScanPressed,
                            child: ElevatedButton(
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                disabledBackgroundColor: theme.colorScheme.primary,
                                disabledForegroundColor: theme.colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.search_rounded),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Scan Gallery',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: theme.colorScheme.onPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          BouncyTap(
                            onTap: _handleScanPdfPressed,
                            child: ElevatedButton(
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                disabledBackgroundColor: theme.colorScheme.surfaceVariant,
                                disabledForegroundColor: theme.colorScheme.onSurface,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: theme.colorScheme.primary.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.document_scanner_outlined, color: theme.colorScheme.onSurface),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Scan Documents (PDFs)',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderSelectionSheet extends StatefulWidget {
  final ValueChanged<List<AssetPathEntity>?> onStartScan;

  const _FolderSelectionSheet({required this.onStartScan});

  @override
  State<_FolderSelectionSheet> createState() => _FolderSelectionSheetState();
}

class _FolderSelectionSheetState extends State<_FolderSelectionSheet> {
  late Future<List<Map<String, dynamic>>> _albumsFuture;
  final Set<String> _selectedAlbumIds = {};

  @override
  void initState() {
    super.initState();
    _albumsFuture = _loadAlbumsWithCounts();
  }

  Future<List<Map<String, dynamic>>> _loadAlbumsWithCounts() async {
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
    );

    final List<Map<String, dynamic>> results = [];
    for (final album in albums) {
      final int count = await album.assetCountAsync;
      if (count > 0) {
        results.add({
          'album': album,
          'count': count,
        });
      }
    }

    // Sort to place "All" first, then sort remaining folders by image count descending
    results.sort((a, b) {
      final albumA = a['album'] as AssetPathEntity;
      final albumB = b['album'] as AssetPathEntity;
      if (albumA.isAll) return -1;
      if (albumB.isAll) return 1;
      return (b['count'] as int).compareTo(a['count'] as int);
    });

    // Auto-select "All" album initially
    if (results.isNotEmpty) {
      final allAlbum = results.firstWhere(
        (r) => (r['album'] as AssetPathEntity).isAll,
        orElse: () => results.first,
      );
      _selectedAlbumIds.add((allAlbum['album'] as AssetPathEntity).id);
    }

    return results;
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
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _albumsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox(
              height: 250,
              child: Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              ),
            );
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'No folders found with images.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            );
          }

          final items = snapshot.data!;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pull Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Folders to Clean',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Folder list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final album = item['album'] as AssetPathEntity;
                    final count = item['count'] as int;
                    final isSelected = _selectedAlbumIds.contains(album.id);

                    // Choose matching folder icons
                    IconData iconData = Icons.folder_outlined;
                    if (album.isAll) {
                      iconData = Icons.photo_library_outlined;
                    } else {
                      final nameLower = album.name.toLowerCase();
                      if (nameLower.contains('whatsapp')) {
                        iconData = Icons.chat_bubble_outline_rounded;
                      } else if (nameLower.contains('screenshot')) {
                        iconData = Icons.screenshot_rounded;
                      } else if (nameLower.contains('camera')) {
                        iconData = Icons.camera_alt_outlined;
                      } else if (nameLower.contains('download')) {
                        iconData = Icons.download_for_offline_outlined;
                      }
                    }

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            if (album.isAll) {
                              // If checking "All", clear everything else
                              _selectedAlbumIds.clear();
                              _selectedAlbumIds.add(album.id);
                            } else {
                              // If checking folder, deselect "All"
                              _selectedAlbumIds.removeWhere((id) {
                                final found = items.firstWhere(
                                  (i) => (i['album'] as AssetPathEntity).id == id,
                                );
                                return (found['album'] as AssetPathEntity).isAll;
                              });
                              _selectedAlbumIds.add(album.id);
                            }
                          } else {
                            _selectedAlbumIds.remove(album.id);
                          }
                        });
                      },
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          iconData,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      title: Text(
                        album.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text('$count photos'),
                      activeColor: theme.colorScheme.primary,
                      checkColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              // Action scan button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: BouncyTap(
                  onTap: _selectedAlbumIds.isEmpty
                      ? null
                      : () {
                          final selectedAlbums = items
                              .where((i) => _selectedAlbumIds.contains((i['album'] as AssetPathEntity).id))
                              .map((i) => i['album'] as AssetPathEntity)
                              .toList();
                          widget.onStartScan(selectedAlbums);
                        },
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      disabledBackgroundColor: _selectedAlbumIds.isEmpty
                          ? theme.colorScheme.surfaceVariant
                          : theme.colorScheme.primary,
                      disabledForegroundColor: _selectedAlbumIds.isEmpty
                          ? theme.colorScheme.secondary.withOpacity(0.5)
                          : theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Scan Selected Folders',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _selectedAlbumIds.isEmpty
                            ? theme.colorScheme.secondary.withOpacity(0.5)
                            : theme.colorScheme.onPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

