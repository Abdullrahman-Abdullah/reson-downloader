// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'splash_screen.dart';

class ProblemScreen extends StatefulWidget {
  const ProblemScreen({super.key});

  @override
  State<ProblemScreen> createState() => _ProblemScreenState();
}

class _ProblemScreenState extends State<ProblemScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _move1, _move2, _move3, _move4;

  late final AnimationController _characterAnimController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _slideAnimation;

  bool _isChecking = false;
  String _problemType = 'maintenance';
  Timer? _countdownTimer;
  String _remainingTimeText = '';

  String _updateUrl =
      'https://play.google.com/store/apps/details?id=com.reson.downloader';
  String _supportUrl = 'https://wa.me/';

  late Box _settingsBox;
  String _savedTheme = 'light';

  @override
  void initState() {
    super.initState();
    _loadThemeAndConfig();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _move1 = Tween<double>(begin: 0.0, end: 50.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _move2 = Tween<double>(begin: 0.0, end: -60.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _move3 = Tween<double>(begin: 0.0, end: 70.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _move4 = Tween<double>(begin: 0.0, end: -50.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _characterAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.12, end: 1.18).animate(
      CurvedAnimation(
          parent: _characterAnimController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(
          parent: _characterAnimController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadThemeAndConfig() async {
    if (!Hive.isBoxOpen('reson_downloader_db')) {
      _settingsBox = await Hive.openBox('reson_downloader_db');
    } else {
      _settingsBox = Hive.box('reson_downloader_db');
    }

    String? theme = _settingsBox.get('saved_theme_mode');
    setState(() {
      _savedTheme = theme ?? 'light';
    });

    _fetchProblemConfig();
  }

  Future<void> _fetchProblemConfig() async {
    try {
      final docRef =
          FirebaseFirestore.instance.collection('app_settings').doc('config');
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        setState(() {
          _problemType = data['problem_type'] ?? 'maintenance';
          _updateUrl = data['update_url'] ?? _updateUrl;
          _supportUrl = data['support_url'] ?? _supportUrl;

          if (_problemType == 'maintenance') {
            final Timestamp? endTimestamp = data['maintenance_end_time'];
            if (endTimestamp != null) {
              _startRealCountdown(endTimestamp.toDate());
            } else {
              _startRealCountdown(DateTime.now().add(const Duration(hours: 2)));
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _startRealCountdown(DateTime endTime) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final difference = endTime.difference(DateTime.now());
      if (difference.isNegative) {
        setState(() => _remainingTimeText = "انتهت الصيانة تقريباً");
        timer.cancel();
      } else {
        setState(() {
          _remainingTimeText =
              "${difference.inHours.toString().padLeft(2, '0')}:${(difference.inMinutes % 60).toString().padLeft(2, '0')}:${(difference.inSeconds % 60).toString().padLeft(2, '0')}";
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _characterAnimController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _retryConnection() async {
    setState(() => _isChecking = true);
    try {
      final docRef =
          FirebaseFirestore.instance.collection('app_settings').doc('config');
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        bool isThereProblem = data['isthere_problem'] ?? true;

        if (!isThereProblem && mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const SplashScreen()));
        } else {
          setState(() {
            _problemType = data['problem_type'] ?? 'maintenance';
            _updateUrl = data['update_url'] ?? _updateUrl;
            _supportUrl = data['support_url'] ?? _supportUrl;
          });

          if (_problemType == 'maintenance') {
            final Timestamp? endTimestamp = data['maintenance_end_time'];
            if (endTimestamp != null) {
              _startRealCountdown(endTimestamp.toDate());
            }
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // التوافق الكامل مع مصفوفات الألوان والثيمات الثلاثة (pink, dark, light)
    final List<Color> gradientColors = _savedTheme == 'pink'
        ? [
            const Color(0xFFFFB6C1),
            const Color(0xFFFFC0CB),
            const Color(0xFFFFE4E1)
          ]
        : (_savedTheme == 'dark'
            ? [
                const Color(0xFF0F172A),
                const Color(0xFF1E293B),
                const Color(0xFF0F172A)
              ]
            : [
                const Color(0xFFF8FAFC),
                const Color(0xFFE2E8F0),
                const Color(0xFFF1F5F9)
              ]);

    final Color primaryTextColor = _savedTheme == 'pink'
        ? const Color(0xFF2A0813)
        : (_savedTheme == 'dark' ? Colors.white : const Color(0xFF1E293B));

    final Color secondaryTextColor = _savedTheme == 'pink'
        ? const Color(0xFF4A1020)
        : (_savedTheme == 'dark' ? Colors.white70 : const Color(0xFF475569));

    final Color cardFillColor = _savedTheme == 'pink'
        ? Colors.white.withOpacity(0.9)
        : (_savedTheme == 'dark'
            ? const Color(0xFF1E293B).withOpacity(0.85)
            : Colors.white.withOpacity(0.95));

    final Color cardBorderColor = _savedTheme == 'pink'
        ? const Color(0xFFF48FB1)
        : (_savedTheme == 'dark' ? Colors.white24 : const Color(0xFFCBD5E1));

    final BorderRadius cardRadius = BorderRadius.circular(20);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -50 + _move1.value,
                    right: -40 + (_move1.value * 0.5),
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_savedTheme == 'pink'
                                ? Colors.pink.shade300
                                : (_savedTheme == 'dark'
                                    ? Colors.blue.shade800
                                    : Colors.blue.shade200))
                            .withOpacity(_savedTheme == 'pink' ? 0.35 : 0.25),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -60 + _move2.value,
                    left: -50 - (_move2.value * 0.4),
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_savedTheme == 'pink'
                                ? Colors.purple.shade200
                                : (_savedTheme == 'dark'
                                    ? Colors.indigo.shade800
                                    : Colors.indigo.shade100))
                            .withOpacity(_savedTheme == 'pink' ? 0.3 : 0.2),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 150 + _move3.value,
                    left: -70 + (_move3.value * 0.6),
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_savedTheme == 'pink'
                                ? Colors.pinkAccent
                                : (_savedTheme == 'dark'
                                    ? Colors.teal.shade800
                                    : Colors.teal.shade100))
                            .withOpacity(_savedTheme == 'pink' ? 0.25 : 0.2),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
            child: Container(
              color: _savedTheme == 'pink'
                  ? Colors.white.withOpacity(0.15)
                  : (_savedTheme == 'dark'
                      ? Colors.black.withOpacity(0.25)
                      : Colors.white.withOpacity(0.2)),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cardFillColor,
                            border: Border.all(
                              color: cardBorderColor,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 15,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: ClipOval(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _characterAnimController,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(_slideAnimation.value, 0),
                                      child: Image.asset(
                                        'assets/images/cover.png',
                                        fit: BoxFit.cover,
                                        width: 130,
                                        height: 130,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const SizedBox(),
                                      ),
                                    );
                                  },
                                ),
                                AnimatedBuilder(
                                  animation: _characterAnimController,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset:
                                          Offset(-_slideAnimation.value, 12.0),
                                      child: Transform.scale(
                                        scale: _pulseAnimation.value,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Image.asset(
                                            'assets/images/image.png',
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Icon(
                                              _getIcon(),
                                              size: 50,
                                              color: primaryTextColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        _getTitle(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _getDescription(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: secondaryTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_problemType == 'maintenance' &&
                          _remainingTimeText.isNotEmpty)
                        Center(
                          child: Text(
                            _remainingTimeText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                      const SizedBox(height: 35),
                      _buildButtons(primaryTextColor, cardFillColor,
                          cardBorderColor, cardRadius),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon() {
    switch (_problemType) {
      case 'maintenance':
        return Icons.engineering;
      case 'update':
        return Icons.system_update;
      case 'banned':
        return Icons.block;
      case 'country_restricted':
        return Icons.public_off;
      case 'discontinued':
        return Icons.warning;
      default:
        return Icons.error;
    }
  }

  String _getTitle() {
    switch (_problemType) {
      case 'maintenance':
        return "التطبيق تحت الصيانة";
      case 'update':
        return "التطبيق يحتاج تحديث اجباري";
      case 'banned':
        return "لم يعد بإمكانك استخدام التطبيق";
      case 'country_restricted':
        return "لا يتوفر هذا التطبيق في بلدك";
      case 'discontinued':
        return "هذا التطبيق لم يعد متاح";
      default:
        return "تنبيه النظام";
    }
  }

  String _getDescription() {
    switch (_problemType) {
      case 'maintenance':
        return "نعمل على تحسين خدماتنا وتطوير التجربة، يرجى الانتظار قليلاً.";
      case 'update':
        return "تتوفر نسخة جديدة ومهمة من التطبيق لضمان استقرار العمل.";
      case 'banned':
        return "تم تقييد الوصول لحسابك أو حظرك من استخدام التطبيق.";
      case 'country_restricted':
        return "هذا التطبيق غير مدعوم في نطاقك الجغرافي الحالي.";
      case 'discontinued':
        return "تم إيقاف تشغيل هذا التطبيق بشكل نهائي.";
      default:
        return "نواجه مشكلة تقنية مؤقتة حالياً.";
    }
  }

  Widget _buildButtons(Color textColor, Color fillColor, Color borderColor,
      BorderRadius radius) {
    switch (_problemType) {
      case 'maintenance':
        return _isChecking
            ? const Center(child: CircularProgressIndicator())
            : SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _retryConnection,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text("إعادة المحاولة",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style:
                      _buttonStyle(fillColor, borderColor, radius, textColor),
                ),
              );

      case 'update':
        return SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => launchUrl(Uri.parse(_updateUrl),
                mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.download, size: 18),
            label: const Text("تحديث الآن",
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: _buttonStyle(fillColor, borderColor, radius, textColor),
          ),
        );

      case 'banned':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => launchUrl(Uri.parse(_supportUrl),
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.support, size: 18),
                label: const Text("التواصل مع الدعم",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: _buttonStyle(fillColor, borderColor, radius, textColor),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () => SystemNavigator.pop(),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: radius),
                  side: BorderSide(color: borderColor, width: 1.2),
                ),
                child: Text("خروج",
                    style: TextStyle(
                        color: textColor, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );

      case 'country_restricted':
        return SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => SystemNavigator.pop(),
            style: _buttonStyle(fillColor, borderColor, radius, textColor),
            child: const Text("خروج",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        );

      case 'discontinued':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => openAppSettings(),
                icon: const Icon(Icons.delete, size: 18),
                label: const Text("إلغاء تثبيت التطبيق",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: radius),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () => SystemNavigator.pop(),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: radius),
                  side: BorderSide(color: borderColor, width: 1.2),
                ),
                child: Text("إغلاق",
                    style: TextStyle(
                        color: textColor, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );

      default:
        return SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _retryConnection,
            style: _buttonStyle(fillColor, borderColor, radius, textColor),
            child: const Text("إعادة المحاولة",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
    }
  }

  ButtonStyle _buttonStyle(Color fillColor, Color borderColor,
      BorderRadius radius, Color textColor) {
    return ElevatedButton.styleFrom(
      backgroundColor: _savedTheme == 'pink'
          ? const Color(0xFFE91E63)
          : (_savedTheme == 'dark' ? const Color(0xFF3B82F6) : fillColor),
      foregroundColor: (_savedTheme == 'pink' || _savedTheme == 'dark')
          ? Colors.white
          : textColor,
      shadowColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: (_savedTheme == 'pink' || _savedTheme == 'dark')
              ? Colors.transparent
              : borderColor,
          width: 1.2,
        ),
      ),
    );
  }
}
