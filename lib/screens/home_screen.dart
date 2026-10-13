// ignore_for_file: dead_null_aware_expression

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/download_task.dart';
import '../services/download_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  final DownloadService _downloadService = DownloadService();
  late Box _settingsBox;
  
  List<DownloadTask> _tasks = [];
  String? _selectedDirectory;
  static const int _threads = 8;

  late final AnimationController _animController;
  late final Animation<double> _move1;
  late final Animation<double> _move2;
  late final Animation<double> _move3;

  bool _isPinkMode = true;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _initApp();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _move1 = Tween<double>(begin: 0.0, end: 80.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _move2 = Tween<double>(begin: 0.0, end: -90.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _move3 = Tween<double>(begin: 0.0, end: 100.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initApp() async {
    // فتح الصندوق بطريقة آمنة لضمان استرجاع البيانات المخزنة
    if (!Hive.isBoxOpen('reson_downloader_db')) {
      _settingsBox = await Hive.openBox('reson_downloader_db');
    } else {
      _settingsBox = Hive.box('reson_downloader_db');
    }
    
    // جلب الثيم المحفوظ
    String? savedTheme = _settingsBox.get('saved_theme_mode');
    if (savedTheme == 'dark') {
      _isPinkMode = false;
      _isDarkMode = true;
    } else if (savedTheme == 'light') {
      _isPinkMode = false;
      _isDarkMode = false;
    } else {
      _isPinkMode = true;
      _isDarkMode = false;
    }

    _loadSavedTasks();
    _getDefaultDirectory();
  }

  void _applyTheme(String mode) {
    setState(() {
      if (mode == 'pink') {
        _isPinkMode = true;
        _isDarkMode = false;
      } else if (mode == 'dark') {
        _isPinkMode = false;
        _isDarkMode = true;
      } else {
        _isPinkMode = false;
        _isDarkMode = false;
      }
    });
    _settingsBox.put('saved_theme_mode', mode);
  }

  void _loadSavedTasks() {
    List? saved = _settingsBox.get('tasks_history');
    if (saved != null) {
      setState(() {
        _tasks = saved.map((e) => DownloadTask.fromJson(Map<String, dynamic>.from(e))).toList();
        for (var task in _tasks) {
          if (task.status == DownloadStatus.downloading) {
            task.status = DownloadStatus.paused;
          }
        }
      });
    }
  }

  void _saveTasksToLocal() {
    List<Map<String, dynamic>> raw = _tasks.map((e) => e.toJson()).toList();
    _settingsBox.put('tasks_history', raw);
  }

  Future<void> _getDefaultDirectory() async {
    Directory? dir;
    if (Platform.isAndroid) {
      // إنشاء مسار خاص بالتطبيق داخل مجلد Downloads العام في الهاتف
      final downloadDir = Directory('/storage/emulated/0/Download/ResonDownloader');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      dir = downloadDir;
    } else {
      // المنصات الأخرى (سطح المكتب أو iOS)
      dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }

    setState(() {
      _selectedDirectory = dir!.path;
    });
  }

  Future<void> _pickDirectory() async {
    // إذا أراد المستخدم اختيار مجلد آخر يدوياً عبر واجهة النظام
    String? path = await FilePicker.getDirectoryPath();
    if (path != null) {
      setState(() => _selectedDirectory = path);
    }
  }

  

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (bytes.bitLength - 1) ~/ 10;
    if (i >= suffixes.length) i = suffixes.length - 1;
    double val = bytes / (1 << (i * 10));
    return '${val.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '0 KB/s';
    if (bytesPerSec > 1024 * 1024) {
      return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
  }

  String _formatTime(int seconds) {
    if (seconds <= 0 || seconds.isInfinite || seconds.isNaN) return 'قريباً...';
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;
    if (hours > 0) return '$hours س $minutes د';
    if (minutes > 0) return '$minutes د $secs ث';
    return '$secs ثانية';
  }

  void _addNewDownload() {
    if (_selectedDirectory == null) return;
    String url = _urlController.text.trim();
    if (url.isEmpty) return;

    String fileName = url.split('/').last.split('?').first;
    if (fileName.isEmpty) fileName = 'file_${DateTime.now().millisecondsSinceEpoch}.bin';
    String fullSavePath = '$_selectedDirectory/$fileName';

    final newTask = DownloadTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url,
      savePath: fullSavePath,
    );

    setState(() {
      _tasks.insert(0, newTask);
      _urlController.clear();
    });
    _saveTasksToLocal();

    _downloadService.startDownload(
      task: newTask,
      numThreads: _threads,
      onProgress: (updated) {
        setState(() {});
        _saveTasksToLocal();
      },
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> gradientColors = _isPinkMode
        ? [const Color(0xFFFFB6C1), const Color(0xFFFFC0CB), const Color(0xFFFFE4E1)]
        : (_isDarkMode
            ? [const Color(0xFF0F172A), const Color(0xFF1E293B), const Color(0xFF0F172A)]
            : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0), const Color(0xFFF1F5F9)]);

    final Color primaryTextColor = _isPinkMode 
        ? const Color(0xFF2A0813) 
        : (_isDarkMode ? Colors.white : const Color(0xFF1E293B));

    final Color secondaryTextColor = _isPinkMode 
        ? const Color(0xFF4A1020) 
        : (_isDarkMode ? Colors.white70 : const Color(0xFF475569));

    final Color mainButtonColor = _isPinkMode 
        ? const Color(0xFFE91E63) 
        : (_isDarkMode ? const Color(0xFF3B82F6) : const Color(0xFF475569));

    final Color cardBgColor = _isPinkMode 
        ? Colors.white.withOpacity(0.95) 
        : (_isDarkMode ? const Color(0xFF1E293B).withOpacity(0.85) : Colors.white.withOpacity(0.95));

    final Color borderColor = _isPinkMode 
        ? const Color(0xFFF48FB1) 
        : (_isDarkMode ? Colors.white24 : const Color(0xFFCBD5E1));

    final Color actionButtonBg = _isPinkMode 
        ? const Color(0xFFFFE4E9) 
        : (_isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    final Color actionButtonTextColor = _isPinkMode 
        ? const Color(0xFFC2185B) 
        : (_isDarkMode ? Colors.white : const Color(0xFF1E293B));

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 600;

          return Stack(
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
                        top: -30 + _move1.value,
                        right: -20 + (_move1.value * 0.3),
                        child: Container(
                          width: isMobile ? 180 : 260,
                          height: isMobile ? 180 : 260,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_isPinkMode ? Colors.pink.shade300 : (_isDarkMode ? Colors.blue.shade800 : Colors.blue.shade200)).withOpacity(0.4),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -40 + _move2.value,
                        left: -30 - (_move2.value * 0.3),
                        child: Container(
                          width: isMobile ? 200 : 290,
                          height: isMobile ? 200 : 290,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_isPinkMode ? Colors.purple.shade200 : (_isDarkMode ? Colors.indigo.shade800 : Colors.indigo.shade100)).withOpacity(0.35),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 150 + _move3.value,
                        left: -40 + (_move3.value * 0.4),
                        child: Container(
                          width: isMobile ? 150 : 220,
                          height: isMobile ? 150 : 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_isPinkMode ? Colors.pinkAccent : (_isDarkMode ? Colors.teal.shade800 : Colors.teal.shade100)).withOpacity(0.35),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
                child: Container(
                  color: _isPinkMode 
                      ? Colors.white.withOpacity(0.15)
                      : (_isDarkMode ? Colors.black.withOpacity(0.25) : Colors.white.withOpacity(0.2)),
                ),
              ),

              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.0 : 20.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome, 
                                color: primaryTextColor, 
                                size: isMobile ? 22 : 26,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Reson Downloader',
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: isMobile ? 16 : 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          PopupMenuButton<String>(
                            offset: const Offset(0, 40),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            color: _isDarkMode ? const Color(0xFF1E293B) : (_isPinkMode ? const Color(0xFFFFFBFC) : Colors.white),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'pink', 
                                child: Text('كيوت', style: TextStyle(color: _isPinkMode ? const Color(0xFFE91E63) : (_isDarkMode ? Colors.white : const Color(0xFF2A0813)), fontWeight: FontWeight.bold)),
                              ),
                              PopupMenuItem(
                                value: 'dark', 
                                child: Text('داكن', style: TextStyle(color: _isDarkMode ? Colors.blueAccent : (_isDarkMode ? Colors.white : const Color(0xFF2A0813)), fontWeight: FontWeight.bold)),
                              ),
                              PopupMenuItem(
                                value: 'light', 
                                child: Text('فاتح', style: TextStyle(color: _isDarkMode ? Colors.white70 : const Color(0xFF2A0813), fontWeight: FontWeight.bold)),
                              ),
                            ],
                            onSelected: (val) {
                              _applyTheme(val);
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor, width: 1.2),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.palette_outlined, size: 14, color: primaryTextColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isPinkMode ? 'وردي كيوت' : (_isDarkMode ? 'داكن' : 'فاتح'),
                                    style: TextStyle(
                                      fontSize: isMobile ? 11 : 12,
                                      fontWeight: FontWeight.bold,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isMobile ? 12 : 20),

                      Container(
                        padding: EdgeInsets.all(isMobile ? 12 : 16),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _urlController,
                              style: TextStyle(
                                color: primaryTextColor, 
                                fontSize: isMobile ? 13 : 14,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'الصق رابط التحميل هنا...',
                                hintStyle: TextStyle(
                                  color: secondaryTextColor.withOpacity(0.8),
                                  fontSize: isMobile ? 12 : 13,
                                ),
                                filled: true,
                                fillColor: _isPinkMode ? Colors.white : (_isDarkMode ? Colors.black.withOpacity(0.3) : Colors.white),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: isMobile ? 10 : 14),
                                prefixIcon: Icon(Icons.link_rounded, size: 18, color: primaryTextColor),
                              ),
                            ),
                            SizedBox(height: isMobile ? 8 : 12),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                SizedBox(
                                  width: isMobile ? constraints.maxWidth - 40 : 260,
                                  child: Text(
                                    'المسار: ${_selectedDirectory ?? "جاري تحديد المجلد..."}',
                                    style: TextStyle(
                                      color: secondaryTextColor, 
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _pickDirectory,
                                      icon: Icon(Icons.folder_open_rounded, size: 14, color: primaryTextColor),
                                      label: Text('المجلد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryTextColor)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: primaryTextColor,
                                        side: BorderSide(color: borderColor, width: 1.2),
                                        backgroundColor: cardBgColor,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    ElevatedButton.icon(
                                      onPressed: _addNewDownload,
                                      icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                                      label: const Text('تحميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: mainButtonColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        elevation: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isMobile ? 12 : 20),

                      Text(
                        'التحميلات النشطة',
                        style: TextStyle(
                          color: primaryTextColor, 
                          fontSize: isMobile ? 14 : 16, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Expanded(
                        child: _tasks.isEmpty
                            ? Center(
                                child: Text(
                                  'لا توجد تحميلات نشطة حالياً ✨',
                                  style: TextStyle(
                                    color: secondaryTextColor, 
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _tasks.length,
                                itemBuilder: (context, index) {
                                  final task = _tasks[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: EdgeInsets.all(isMobile ? 12 : 14),
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: borderColor, width: 1.2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                task.savePath.split('/').last,
                                                style: TextStyle(
                                                  color: primaryTextColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: isMobile ? 13 : 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            _buildStatusLabel(task.status, isMobile),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${_formatBytes(task.downloadedBytes)} / ${_formatBytes(task.totalBytes)}',
                                              style: TextStyle(
                                                color: secondaryTextColor, 
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '${(task.progress * 100).toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                color: primaryTextColor, 
                                                fontWeight: FontWeight.bold, 
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            value: task.progress,
                                            backgroundColor: borderColor.withOpacity(0.3),
                                            valueColor: AlwaysStoppedAnimation<Color>(mainButtonColor),
                                            minHeight: 7,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        if (task.status == DownloadStatus.downloading) ...[
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('السرعة: ${_formatSpeed(task.speedBytesPerSecond)}', style: TextStyle(color: primaryTextColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                              Text('المتبقي: ${_formatTime(task.remainingSeconds)}', style: TextStyle(color: secondaryTextColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: List.generate(task.threadProgress.length, (tIdx) {
                                              return Expanded(
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 1),
                                                  child: LinearProgressIndicator(
                                                    value: task.threadProgress[tIdx],
                                                    minHeight: 3.5,
                                                    backgroundColor: borderColor.withOpacity(0.3),
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      tIdx % 2 == 0 ? mainButtonColor : primaryTextColor.withOpacity(0.7),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ),
                                        ],
                                        const SizedBox(height: 6),

                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (task.status == DownloadStatus.downloading)
                                              TextButton.icon(
                                                onPressed: () {
                                                  _downloadService.pauseDownload(task);
                                                  setState(() {});
                                                  _saveTasksToLocal();
                                                },
                                                icon: Icon(Icons.pause_circle_rounded, size: 16, color: actionButtonTextColor),
                                                label: Text('إيقاف', style: TextStyle(color: actionButtonTextColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                                style: TextButton.styleFrom(
                                                  backgroundColor: actionButtonBg,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                ),
                                              ),
                                            if (task.status == DownloadStatus.paused || task.status == DownloadStatus.error)
                                              TextButton.icon(
                                                onPressed: () {
                                                  _downloadService.startDownload(
                                                    task: task,
                                                    numThreads: _threads,
                                                    onProgress: (t) {
                                                      setState(() {});
                                                      _saveTasksToLocal();
                                                    },
                                                  );
                                                },
                                                icon: Icon(Icons.play_circle_fill_rounded, size: 16, color: actionButtonTextColor),
                                                label: Text('استئناف', style: TextStyle(color: actionButtonTextColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                                style: TextButton.styleFrom(
                                                  backgroundColor: actionButtonBg,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                ),
                                              ),
                                            const SizedBox(width: 8),
                                            TextButton.icon(
                                              onPressed: () {
                                                _downloadService.cancelAndCleanDownload(task);
                                                setState(() {
                                                  _tasks.remove(task);
                                                });
                                                _saveTasksToLocal();
                                              },
                                              icon: Icon(Icons.delete_outline_rounded, size: 16, color: _isPinkMode ? const Color(0xFF880E4F) : (_isDarkMode ? Colors.redAccent : Colors.red.shade700)),
                                              label: Text('حذف', style: TextStyle(color: _isPinkMode ? const Color(0xFF880E4F) : (_isDarkMode ? Colors.redAccent : Colors.red.shade700), fontSize: 11, fontWeight: FontWeight.bold)),
                                              style: TextButton.styleFrom(
                                                backgroundColor: _isPinkMode ? const Color(0xFFFCE4EC) : (_isDarkMode ? Colors.red.withOpacity(0.15) : Colors.red.shade50),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusLabel(DownloadStatus status, bool isMobile) {
    String label = '';
    Color bgColor = const Color(0xFFFFE4E9);
    Color textColor = const Color(0xFFC2185B);

    switch (status) {
      case DownloadStatus.downloading:
        label = 'جاري التحميل';
        bgColor = _isPinkMode ? const Color(0xFFE91E63) : (_isDarkMode ? const Color(0xFF3B82F6) : Colors.blueAccent);
        textColor = Colors.white;
        break;
      case DownloadStatus.paused:
        label = 'متوقف مؤقتاً';
        bgColor = _isPinkMode ? const Color(0xFFF8BBD0) : (_isDarkMode ? const Color(0xFF334155) : Colors.orange.shade100);
        textColor = _isPinkMode ? const Color(0xFF880E4F) : (_isDarkMode ? Colors.white70 : Colors.orange.shade900);
        break;
      case DownloadStatus.completed:
        label = 'مكتمل ✨';
        bgColor = _isPinkMode ? const Color(0xFFC2185B) : (_isDarkMode ? Colors.green.shade700 : Colors.green);
        textColor = Colors.white;
        break;
      case DownloadStatus.error:
        label = 'خطأ';
        bgColor = Colors.red.shade700;
        textColor = Colors.white;
        break;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor, 
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label, 
        style: TextStyle(color: textColor, fontSize: isMobile ? 9 : 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}