import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // لجلب حالة الصيانة من قاعدة البيانات
import 'home_screen.dart';
import 'problem_screen.dart'; // استدعاء ملف واجهة المشاكل الجديد

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isChecking = true;
  bool _showChoice = false;
  bool _showSuccessScreen = false;
  String? _selectedLegend;
  late Box _settingsBox;
  
  String _savedTheme = 'light';

  int _countdownSeconds = 3;
  bool _isButtonEnabled = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkAppStartup();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkAppStartup() async {
    if (!Hive.isBoxOpen('reson_downloader_db')) {
      _settingsBox = await Hive.openBox('reson_downloader_db');
    } else {
      _settingsBox = Hive.box('reson_downloader_db');
    }
    
    // 1. فحص ما إذا كان هناك مشكلة أو صيانة عامة مسجلة في قاعدة البيانات قبل الدخول
    try {
      final docSnapshot = await FirebaseFirestore.instance.collection('app_settings').doc('config').get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        bool isThereProblem = data['isthere_problem'] ?? false;
        if (isThereProblem && mounted) {
          // التوجيه لواجهة المشاكل الجديدة التي أرسلتها
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProblemScreen()),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint("خطأ في فحص حالة النظام: $e");
    }

    // 2. فحص المظهر المخزن مسبقاً، وإذا لم يوجد يتم ضبطه على الوضع الفاتح الافتراضي
    String? theme = _settingsBox.get('saved_theme_mode');
    if (theme == null) {
      theme = 'light';
      _settingsBox.put('saved_theme_mode', 'light');
    }
    
    // محاكاة فحص التحديثات
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _savedTheme = theme!;
      if (_settingsBox.get('saved_theme_mode') == null || theme == 'light') {
        if (_settingsBox.get('legend_chosen') == true) {
          _isChecking = false;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
          return;
        }
      }
    });

    bool hasChosenLegend = _settingsBox.get('legend_chosen', defaultValue: false);

    setState(() {
      if (!hasChosenLegend) {
        _savedTheme = 'light';
        _showChoice = true;
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        return;
      }
      _isChecking = false;
    });
  }

  void _saveLegendChoice(String legend) {
    String themeMode = (legend == 'messi') ? 'pink' : 'dark';
    _settingsBox.put('saved_theme_mode', themeMode);
    _settingsBox.put('legend_chosen', true);
    
    setState(() {
      _selectedLegend = legend;
      _showChoice = false;
      _showSuccessScreen = true;
      _savedTheme = themeMode;
    });

    _startCountdown();
  }

  void _startCountdown() {
    setState(() {
      _countdownSeconds = 3;
      _isButtonEnabled = false;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds > 1) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        setState(() {
          _countdownSeconds = 0;
          _isButtonEnabled = true;
        });
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> gradientColors = _savedTheme == 'pink'
        ? [const Color(0xFFFFB6C1), const Color(0xFFFFC0CB), const Color(0xFFFFE4E1)]
        : (_savedTheme == 'dark'
            ? [const Color(0xFF0F172A), const Color(0xFF1E293B), const Color(0xFF0F172A)]
            : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0), const Color(0xFFF1F5F9)]);

    final Color primaryTextColor = _savedTheme == 'pink'
        ? const Color(0xFF2A0813)
        : (_savedTheme == 'dark' ? Colors.white : const Color(0xFF1E293B));

    if (_isChecking) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome, color: _savedTheme == 'pink' ? const Color(0xFFE91E63) : (_savedTheme == 'dark' ? Colors.blueAccent : Colors.black87), size: 52),
                const SizedBox(height: 20),
                Text(
                  'جاري فحص التحديثات والتحقق من النظام...',
                  style: TextStyle(color: primaryTextColor, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                CircularProgressIndicator(color: _savedTheme == 'pink' ? const Color(0xFFE91E63) : (_savedTheme == 'dark' ? Colors.blueAccent : Colors.black87)),
              ],
            ),
          ),
        ),
      );
    }

    if (_showChoice) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                bool isDesktop = constraints.maxWidth >= 700;

                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sports_soccer, color: _savedTheme == 'dark' ? Colors.amber : Colors.orangeAccent, size: 32),
                        const SizedBox(height: 16),
                        Text(
                          'من هو المفضل لديك؟',
                          style: TextStyle(color: primaryTextColor, fontSize: 24, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        isDesktop
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildLegendCard(
                                    name: 'ليونيل ميسي',
                                    playerAssetPath: 'assets/images/messistand.png',
                                    bgAssetPath: 'assets/images/bg_messi.jpg',
                                    onTap: () => _saveLegendChoice('messi'),
                                    isDesktop: true,
                                  ),
                                  const SizedBox(width: 30),
                                  _buildLegendCard(
                                    name: 'كريستيانو رونالدو',
                                    playerAssetPath: 'assets/images/ronaldo.png',
                                    bgAssetPath: 'assets/images/bg_ronaldo.jpg',
                                    onTap: () => _saveLegendChoice('ronaldo'),
                                    isDesktop: true,
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildLegendCard(
                                    name: 'ليونيل ميسي',
                                    playerAssetPath: 'assets/images/messistand.png',
                                    bgAssetPath: 'assets/images/bg_messi.jpg',
                                    onTap: () => _saveLegendChoice('messi'),
                                    isDesktop: false,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildLegendCard(
                                    name: 'كريستيانو رونالدو',
                                    playerAssetPath: 'assets/images/ronaldo.png',
                                    bgAssetPath: 'assets/images/bg_ronaldo.jpg',
                                    onTap: () => _saveLegendChoice('ronaldo'),
                                    isDesktop: false,
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    if (_showSuccessScreen) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 140,
                      width: 140,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          _selectedLegend == 'messi' 
                              ? 'assets/images/messi.png' 
                              : 'assets/images/ronaldo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _selectedLegend == 'messi' ? 'لقد اخترت ميسي ' : 'تم اختيار الأسطورة رونالدو ',
                      style: TextStyle(color: primaryTextColor, fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _selectedLegend == 'messi' 
                          ? 'لذا تم تطبيق الثيم الوردي بناءً على شخصيتك 🌸' 
                          : 'لقد تم تطبيق الثيم الداكن الفخم بناءً على اختيارك الأسطوري ⚡',
                      style: TextStyle(color: primaryTextColor.withOpacity(0.8), fontSize: 15, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 35),
                    ElevatedButton.icon(
                      onPressed: _isButtonEnabled
                          ? () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const HomeScreen()),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: Text(
                        _isButtonEnabled
                            ? 'الانتقال إلى الصفحة الرئيسية'
                            : 'الانتقال إلى الصفحة الرئيسية ($_countdownSeconds)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedLegend == 'messi' ? const Color(0xFFE91E63) : const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.withOpacity(0.4),
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      body: SizedBox.shrink(),
    );
  }

  Widget _buildLegendCard({
    required String name,
    required String playerAssetPath,
    required String bgAssetPath,
    required VoidCallback onTap,
    required bool isDesktop,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isDesktop ? 300 : double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _savedTheme == 'pink' ? Colors.white.withOpacity(0.9) : (_savedTheme == 'dark' ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _savedTheme == 'light' ? Colors.black12 : Colors.white24, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: isDesktop ? 220 : 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      bgAssetPath,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      color: Colors.black.withOpacity(0.3),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Image.asset(
                        playerAssetPath,
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: TextStyle(
                color: _savedTheme == 'light' ? const Color(0xFF1E293B) : Colors.white, 
                fontSize: 18, 
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}