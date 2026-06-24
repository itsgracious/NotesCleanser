import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/scan_provider.dart';
import 'results_screen.dart';

class ScanningScreen extends StatefulWidget {
  final List<AssetPathEntity>? selectedAlbums;

  const ScanningScreen({super.key, this.selectedAlbums});

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen> {
  @override
  void initState() {
    super.initState();
    // Start scanning gallery when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ScanProvider>(context, listen: false);
      provider.startScan(selectedAlbums: widget.selectedAlbums).then((_) {
        if (mounted && !provider.isCancelled) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const ResultsScreen(),
            ),
          );
        }
      });
    });
  }

  void _handleCancelPressed(ScanProvider scanProvider) {
    if (scanProvider.notesCount > 0) {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          final theme = Theme.of(context);
          return AlertDialog(
            title: Text(
              'Cancel Scanning?',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Notes Cleanser has already found ${scanProvider.notesCount} note photos. Would you like to review and delete them, or discard this scan?',
              style: theme.textTheme.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Close dialog
                  scanProvider.cancelScan();
                  Navigator.of(context).pop(); // Go back to Home
                },
                child: Text(
                  'Discard',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Close dialog
                  scanProvider.cancelScan(); // Stop scan loop
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const ResultsScreen(),
                    ),
                  );
                },
                child: Text(
                  'Review Notes',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else {
      scanProvider.cancelScan();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scanProvider = Provider.of<ScanProvider>(context);

    // Calculate progress fraction
    final total = scanProvider.totalCount;
    final scanned = scanProvider.scannedCount;
    final progress = total > 0 ? (scanned / total).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Scanning Animation / Icon
              Center(
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: SweepingProgressIndicator(progress: progress),
                      ),
                      // Inner Icon
                      Icon(
                        Icons.photo_library_outlined,
                        size: 44,
                        color: theme.colorScheme.onSurface,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Text(
                'Analyzing Gallery',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Notes Cleanser is scanning your photos on-device to detect handwritten notes, documents, and screenshots.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Progress Numbers Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                     children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progress',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$scanned of $total photos',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: theme.colorScheme.surfaceVariant,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Notes Counter Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.colorScheme.surfaceVariant,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.document_scanner_outlined,
                                  size: 18,
                                  color: theme.colorScheme.onSurface,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${scanProvider.notesCount} note photos found',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Cancel Button
              OutlinedButton(
                onPressed: () => _handleCancelPressed(scanProvider),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  side: BorderSide(color: theme.colorScheme.surfaceVariant, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Cancel Scan',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SweepingProgressIndicator extends StatefulWidget {
  final double progress;
  const SweepingProgressIndicator({super.key, required this.progress});

  @override
  State<SweepingProgressIndicator> createState() => _SweepingProgressIndicatorState();
}

class _SweepingProgressIndicatorState extends State<SweepingProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _SweepPainter(
            sweepAngle: _controller.value * 2 * 3.14159,
            progress: widget.progress,
            primaryColor: theme.colorScheme.primary,
            borderColor: theme.colorScheme.surfaceVariant,
          ),
        );
      },
    );
  }
}

class _SweepPainter extends CustomPainter {
  final double sweepAngle;
  final double progress;
  final Color primaryColor;
  final Color borderColor;

  _SweepPainter({
    required this.sweepAngle,
    required this.progress,
    required this.primaryColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 6) / 2;

    // 1. Draw background circle
    final bgPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;
    canvas.drawCircle(center, radius, bgPaint);

    // 2. Draw static progress arc
    final progressPaint = Paint()
      ..color = primaryColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      progress * 2 * 3.14159,
      false,
      progressPaint,
    );

    // 3. Draw animated sweep glow (radar style)
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          primaryColor.withOpacity(0.0),
          primaryColor,
        ],
        stops: const [0.75, 1.0],
        transform: GradientRotation(sweepAngle - 3.14159 / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      sweepAngle - 3.14159 / 2 - (3.14159 / 3), // sweep a 60 degree arc
      3.14159 / 3,
      false,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SweepPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle || oldDelegate.progress != progress;
  }
}

