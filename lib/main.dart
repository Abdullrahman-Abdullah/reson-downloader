// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart'; // إضافة مكتبة الفايربيس
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  
  // تهيئة Firebase الأساسية
  await Firebase.initializeApp();

  final notificationService = NotificationService();
  await notificationService.initNotification();

  runApp(const ResonDownloaderApp());
}

class ResonDownloaderApp extends StatelessWidget {
  const ResonDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Reson Downloader',
      theme: ThemeData.dark(useMaterial3: true),
      home: const SplashScreen(),
    );
  }
}