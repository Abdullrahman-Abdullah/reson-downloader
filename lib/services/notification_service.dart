import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initNotification() async {
    if (_isInitialized) return;

    // الإشعارات المحلية تعمل بكفاءة عالية على أندرويد و iOS، 
    // أما على ويندوز فقد تحتاج لتوافقية خاصة، لذا نجعلها آمنة تماماً.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _isInitialized = true;
      return;
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    try {
      await _notificationsPlugin.initialize(initializationSettings);
      await requestPermission();
      _isInitialized = true;
    } catch (e) {
      debugPrint('تعذر تهيئة الإشعارات: $e');
    }
  }

  Future<void> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.requestNotificationsPermission();
        }
      }
    } catch (e) {
      debugPrint('تعذر طلب الصلاحية: $e');
    }
  }

  Future<void> showNotification({required String title, required String body}) async {
    // على ويندوز، نقوم بطباعة الإشعار في الكونسول لتجنب الانهيار، أو يمكنك تركها لاحقاً لإشعارات سطح المكتب
    if (Platform.isWindows) {
      debugPrint('🔔 [إشعار ويندوز]: $title - $body');
      return;
    }

    try {
      if (!_isInitialized) {
        await initNotification();
      }

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'reson_downloader_channel',
        'تنزيلات ريزون',
        channelDescription: 'إشعارات متابعة حالة التحميل',
        importance: Importance.max,
        priority: Priority.high,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _notificationsPlugin.show(
        0,
        title,
        body,
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('تعذر إظهار الإشعار: $e');
    }
  }

  Future<void> showDownloadComplete(String fileName) async {
    await showNotification(
      title: '✅ اكتمل التحميل بنجاح',
      body: 'تم حفظ الملف في: $fileName',
    );
  }

  Future<void> showDownloadError(String error) async {
    await showNotification(
      title: '❌ خطأ في التحميل',
      body: 'حدثت مشكلة: $error',
    );
  }
}