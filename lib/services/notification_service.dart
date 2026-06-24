import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'scan_channel';
  static const String _channelName = 'Gallery Scan Progress';
  static const String _channelDescription =
      'Displays the progress of Note Cleanser scanning.';

  /// Initializes the local notifications plugin and registers the channel.
  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    // Call initialize with named argument
    await _notificationsPlugin.initialize(
      settings: initializationSettings,
    );

    // Create the channel on Android
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      );
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  /// Starts or updates the foreground service notification with scanning progress.
  static Future<void> updateProgress(int progress, int max, {bool isComplete = false}) async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    if (isComplete) {
      // Display a brief, complete message with all-named arguments
      await androidPlugin.startForegroundService(
        id: 888,
        title: 'Scan Complete',
        body: 'Gallery scan completed. Found all note photos.',
        notificationDetails: const AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          showProgress: false,
          ongoing: false,
          onlyAlertOnce: true,
        ),
      );
      // Automatically stop the foreground service shortly after to clean up the status bar
      Future.delayed(const Duration(seconds: 4), () {
        stopService();
      });
      return;
    }

    // Otherwise, show active progress bar with all-named arguments
    await androidPlugin.startForegroundService(
      id: 888,
      title: 'Scanning Gallery...',
      body: '$progress / $max photos analyzed',
      notificationDetails: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low, // Prevent sound/popups on updates
        priority: Priority.low,
        showProgress: true,
        maxProgress: max,
        progress: progress,
        ongoing: true,
        onlyAlertOnce: true, // Prevent continuous vibrations/chimes
      ),
    );
  }

  /// Explicitly halts the foreground service and dismisses the progress notification.
  static Future<void> stopService() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.stopForegroundService();
  }
}
