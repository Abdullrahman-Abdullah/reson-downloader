import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1), // تحديث البيانات كل ساعة
    ));

    // القيم الافتراضية محلياً في حال انقطاع الإنترنت
    await _remoteConfig.setDefaults({
      'is_under_maintenance': false,
      'min_required_version': '1.0.0',
      'maintenance_message': 'التطبيق تحت الصيانة حالياً، عودوا قريباً! ✨',
    });

    try {
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      print('خطأ في جلب بيانات Remote Config: $e');
    }
  }

  bool get isUnderMaintenance => _remoteConfig.getBool('is_under_maintenance');
  String get minRequiredVersion => _remoteConfig.getString('min_required_version');
  String get maintenanceMessage => _remoteConfig.getString('maintenance_message');
}