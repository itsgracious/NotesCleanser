import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/scan_provider.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    
    // Pre-initialize NoteClassifier in the background while displaying the loading GIF
    Future.wait([
      Provider.of<ScanProvider>(context, listen: false).initializeClassifier().catchError((e) {
        print('Error pre-initializing NoteClassifier: $e');
      }),
      Future.delayed(const Duration(milliseconds: 5000)),
    ]).then((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFBAA9CF), // Target lavender background color matching GIF
      body: SafeArea(
        child: Stack(
          children: [
            // Center Loading GIF
            Center(
              child: Image.asset(
                'assets/loading.webp',
                width: 800,
                height: 800,
                fit: BoxFit.contain,
              ),
            ),
            // Bottom "NotesCleanser" Brand Text
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Notes Cleanser',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 28,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C1A17), // Near-black text
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '100% PRIVATE • ON-DEVICE CLEANING',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1A17).withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
