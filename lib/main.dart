import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/scan_provider.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(const NotesCleanserApp());
}

class NotesCleanserApp extends StatelessWidget {
  const NotesCleanserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ScanProvider(),
      child: MaterialApp(
        title: 'Notes Cleanser',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          // Warm-neutral palette setup
          scaffoldBackgroundColor: const Color(0xFFFDF5EC), // Match hero image background
          colorScheme: const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFFBAA9CF), // Lavender main color
            onPrimary: Color(0xFF1C1A17), // Near-black text on lavender
            secondary: Color(0xFF706B63), // Slate/brownish grey
            onSecondary: Color(0xFFFFFDF9),
            error: Color(0xFFC62828), // Elegant red for destructive actions
            onError: Color(0xFFFFFDF9),
            surface: Color(0xFFFFFDF9), // Warm white cards
            onSurface: Color(0xFF1C1A17),
            background: Color(0xFFFDF5EC), // Seamless background color
            onBackground: Color(0xFF1C1A17),
            surfaceVariant: Color(0xFFE6E2D8), // Soft warm grey for borders
          ),
          textTheme: const TextTheme(
            displayLarge: TextStyle(fontFamily: 'Outfit', color: Color(0xFF1C1A17), fontWeight: FontWeight.bold),
            displayMedium: TextStyle(fontFamily: 'Outfit', color: Color(0xFF1C1A17), fontWeight: FontWeight.bold),
            displaySmall: TextStyle(fontFamily: 'Outfit', color: Color(0xFF1C1A17), fontWeight: FontWeight.bold),
            headlineLarge: TextStyle(fontFamily: 'Outfit', color: Color(0xFF1C1A17), fontWeight: FontWeight.bold, fontSize: 32),
            headlineMedium: TextStyle(fontFamily: 'Outfit', color: Color(0xFF1C1A17), fontWeight: FontWeight.w600, fontSize: 24),
            headlineSmall: TextStyle(fontFamily: 'Outfit', color: Color(0xFF1C1A17), fontWeight: FontWeight.w600, fontSize: 20),
            titleLarge: TextStyle(fontFamily: 'Outfit', color: Color(0xFF1C1A17), fontWeight: FontWeight.w600, fontSize: 18),
            titleMedium: TextStyle(fontFamily: 'Outfit', color: Color(0xFF706B63), fontWeight: FontWeight.w500, fontSize: 16),
            bodyLarge: TextStyle(fontFamily: 'Inter', color: Color(0xFF1C1A17), fontSize: 16, height: 1.5),
            bodyMedium: TextStyle(fontFamily: 'Inter', color: Color(0xFF706B63), fontSize: 14, height: 1.4),
            labelLarge: TextStyle(fontFamily: 'Inter', color: Color(0xFF1C1A17), fontWeight: FontWeight.w600, fontSize: 14),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFFFFFDF9),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE6E2D8), width: 1),
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: const Color(0xFFFFFDF9),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: const Color(0xFFFDF5EC),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Color(0xFF1C1A17)),
            titleTextStyle: TextStyle(
              fontFamily: 'Outfit',
              color: Color(0xFF1C1A17),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          buttonTheme: const ButtonThemeData(
            buttonColor: Color(0xFF1C1A17),
            textTheme: ButtonTextTheme.primary,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
