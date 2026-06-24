import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

class PdfScannerService {
  // Course code regex pattern: e.g. MAT 302, CS101, PHY_201
  static final RegExp _courseCodeRegex = RegExp(r'[a-zA-Z]{2,4}\s*[-_]?\s*\d{3}', caseSensitive: false);

  // Note-related keywords in filename
  static const List<String> _noteKeywords = [
    'notes', 'chapter', 'chap', 'lecture', 'lect', 'syllabus', 
    'assignment', 'assign', 'exam', 'test', 'homework', 'slide', 
    'slides', 'presentation', 'course', 'module', 'unit', 'study', 
    'material', 'question', 'paper', 'ppt'
  ];

  // Government documents and certificate rules to bypass/ignore
  static const List<BlacklistRule> _blacklistRules = [
    // Exact match rules (case-insensitive) - preventing false positives like "financial" or "syntax"
    BlacklistRule('nia', 'exact'),
    BlacklistRule('pan', 'exact'),
    BlacklistRule('dl', 'exact'),
    BlacklistRule('cv', 'exact'),
    BlacklistRule('tax', 'exact'),
    BlacklistRule('rc', 'exact'),
    BlacklistRule('itr', 'exact'),
    BlacklistRule('uid', 'exact'),
    BlacklistRule('epic', 'exact'),
    BlacklistRule('sslc', 'exact'),
    BlacklistRule('hsc', 'exact'),
    BlacklistRule('cbse', 'exact'),
    BlacklistRule('icse', 'exact'),
    BlacklistRule('nios', 'exact'),

    // Starts with match rules (prefix check on filename tokens)
    BlacklistRule('cert', 'startsWith'),
    BlacklistRule('visa', 'startsWith'),
    BlacklistRule('bill', 'startsWith'),
    BlacklistRule('govt', 'startsWith'),
    BlacklistRule('govern', 'startsWith'),
    BlacklistRule('nation', 'startsWith'),
    BlacklistRule('offic', 'startsWith'),

    // Contains match rules (safe because these are highly specific document keywords)
    BlacklistRule('aadhaar', 'contains'),
    BlacklistRule('aadhar', 'contains'),
    BlacklistRule('adhaar', 'contains'),
    BlacklistRule('eadhaar', 'contains'),
    BlacklistRule('eaadhaar', 'contains'),
    BlacklistRule('uidai', 'contains'),
    BlacklistRule('passport', 'contains'),
    BlacklistRule('license', 'contains'),
    BlacklistRule('licence', 'contains'),
    BlacklistRule('driving', 'contains'),
    BlacklistRule('voter', 'contains'),
    BlacklistRule('election', 'contains'),
    BlacklistRule('ration', 'contains'),
    BlacklistRule('certificate', 'contains'),
    BlacklistRule('degree', 'contains'),
    BlacklistRule('diploma', 'contains'),
    BlacklistRule('transcript', 'contains'),
    BlacklistRule('marksheet', 'contains'),
    BlacklistRule('marklist', 'contains'),
    BlacklistRule('scorecard', 'contains'),
    BlacklistRule('gradecard', 'contains'),
    BlacklistRule('gradesheet', 'contains'),
    BlacklistRule('resume', 'contains'),
    BlacklistRule('invoice', 'contains'),
    BlacklistRule('receipt', 'contains'),
    BlacklistRule('ticket', 'contains'),
    BlacklistRule('boarding', 'contains'),
    BlacklistRule('salary', 'contains'),
    BlacklistRule('payslip', 'contains'),
    BlacklistRule('pay_slip', 'contains'),
    BlacklistRule('insurance', 'contains'),
    BlacklistRule('policy', 'contains'),
    BlacklistRule('admitcard', 'contains'),
    BlacklistRule('admit', 'contains'),
    BlacklistRule('hallticket', 'contains'),
    BlacklistRule('offerletter', 'contains'),
    BlacklistRule('offer_letter', 'contains'),
    BlacklistRule('contract', 'contains'),
  ];

  /// Checks if the file path indicates it is a blacklisted document (Aadhaar, certificate, etc.).
  static bool isBlacklisted(String filePath) {
    final filename = filePath.split(Platform.pathSeparator).last.toLowerCase();
    
    // Remove typical extensions
    final nameWithoutExt = filename.replaceAll(RegExp(r'\.(pdf|jpe?g|png)$'), '');
    
    // Split into tokens using non-alphanumeric characters
    final tokens = nameWithoutExt.split(RegExp(r'[^a-zA-Z0-9]')).where((t) => t.isNotEmpty).toList();
    
    for (final rule in _blacklistRules) {
      for (final token in tokens) {
        if (rule.type == 'exact') {
          if (token == rule.keyword) return true;
        } else if (rule.type == 'startsWith') {
          if (token.startsWith(rule.keyword)) return true;
        } else if (rule.type == 'contains') {
          if (token.contains(rule.keyword)) return true;
        }
      }
    }
    
    // Fallback: direct contains on full filename for contains rules only
    for (final rule in _blacklistRules) {
      if (rule.type == 'contains' && filename.contains(rule.keyword)) {
        return true;
      }
    }
    
    return false;
  }

  /// Scans high-yield directories for PDF files.
  /// Returns a list of PDF File objects.
  static Future<List<File>> locatePdfFiles() async {
    final List<File> pdfFiles = [];
    final List<String> targetPaths = [];

    if (Platform.isAndroid) {
      // High-yield Android directories specified by the user
      const List<String> androidDirs = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents',
        '/storage/emulated/0/Android/media/com.google.android.apps.docs',
        '/storage/emulated/0/CamScanner',
        '/storage/emulated/0/Adobe Scan',
        '/storage/emulated/0/Microsoft Lens',
      ];
      targetPaths.addAll(androidDirs);
    } else if (Platform.isIOS) {
      // iOS public/accessible documents directory
      try {
        final docDir = await getApplicationDocumentsDirectory();
        targetPaths.add(docDir.path);
      } catch (e) {
        print('Error getting iOS application documents directory: $e');
      }
    }

    for (final path in targetPaths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        try {
          await _scanDirectory(dir, pdfFiles, currentDepth: 0, maxDepth: 3);
        } catch (e) {
          print('Error scanning directory $path: $e');
        }
      }
    }

    return pdfFiles;
  }

  /// Recursively lists files in a directory up to maxDepth.
  static Future<void> _scanDirectory(Directory dir, List<File> pdfFiles, {required int currentDepth, required int maxDepth}) async {
    if (currentDepth > maxDepth) return;

    try {
      final List<FileSystemEntity> entities = dir.listSync(followLinks: false);
      for (final entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          pdfFiles.add(entity);
        } else if (entity is Directory) {
          // Skip hidden directories (starting with .)
          final dirName = entity.path.split(Platform.pathSeparator).last;
          if (!dirName.startsWith('.')) {
            await _scanDirectory(entity, pdfFiles, currentDepth: currentDepth + 1, maxDepth: maxDepth);
          }
        }
      }
    } catch (e) {
      // Directory listing might fail due to access permissions
      print('Access denied to directory ${dir.path}: $e');
    }
  }

  /// Checks if the filename indicates it is a note.
  static bool hasNoteKeywords(String filePath) {
    if (isBlacklisted(filePath)) return false;

    // Get the base filename (e.g. MAT 302.pdf)
    final filename = filePath.split(Platform.pathSeparator).last;
    final lowerName = filename.toLowerCase();
    
    // Check course code regex
    if (_courseCodeRegex.hasMatch(lowerName)) {
      return true;
    }

    // Check keywords
    for (final keyword in _noteKeywords) {
      if (lowerName.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  /// Renders Page 1 of a PDF file to a JPEG image of size 224x224.
  /// Returns the image bytes or null if rendering fails.
  static Future<Uint8List?> renderPageOne(String filePath) async {
    PdfDocument? document;
    PdfPage? page;
    try {
      document = await PdfDocument.openFile(filePath);
      if (document.pagesCount > 0) {
        page = await document.getPage(1);
        final pageImage = await page.render(
          width: 224,
          height: 224,
          format: PdfPageImageFormat.jpeg,
        );
        return pageImage?.bytes;
      }
    } catch (e) {
      print('Error rendering PDF page: $e');
    } finally {
      await page?.close();
      await document?.close();
    }
    return null;
  }

  /// Returns the number of pages in a PDF file.
  /// Returns 0 if reading fails.
  static Future<int> getPageCount(String filePath) async {
    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(filePath);
      return document.pagesCount;
    } catch (e) {
      print('Error getting PDF page count: $e');
    } finally {
      await document?.close();
    }
    return 0;
  }
}

class BlacklistRule {
  final String keyword;
  final String type; // 'exact', 'startsWith', 'contains'

  const BlacklistRule(this.keyword, this.type);
}
