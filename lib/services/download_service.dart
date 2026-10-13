import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../models/download_task.dart';
import 'notification_service.dart';

class DownloadService {
  late final Dio _dio;
  final NotificationService _notificationService = NotificationService();
  final Map<String, CancelToken> _activeTokens = {};
  final Map<String, bool> _isTaskPaused = {};

  DownloadService() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 45),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ResonDownloader/2.0',
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
      ),
    );

    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      return client;
    };
  }

  void pauseDownload(DownloadTask task) {
    _isTaskPaused[task.id] = true;
    _activeTokens[task.id]?.cancel('paused');
    _activeTokens.remove(task.id);
    task.status = DownloadStatus.paused;
    task.speedBytesPerSecond = 0.0;
    task.remainingSeconds = 0;
  }

  void cancelAndCleanDownload(DownloadTask task) {
    _isTaskPaused[task.id] = false;
    _activeTokens[task.id]?.cancel('cancelled');
    _activeTokens.remove(task.id);

    try {
      final file = File(task.savePath);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  Future<void> startDownload({
    required DownloadTask task,
    required int numThreads,
    required Function(DownloadTask updatedTask) onProgress,
  }) async {
    final cancelToken = CancelToken();
    _activeTokens[task.id] = cancelToken;
    _isTaskPaused[task.id] = false;

    try {
      task.status = DownloadStatus.downloading;
      onProgress(task);

      int fileSize = task.totalBytes;

      if (fileSize <= 0) {
        Response headResponse = await _dio.head(
          task.url,
          cancelToken: cancelToken,
          options: Options(
              followRedirects: true, validateStatus: (status) => status! < 500),
        );

        fileSize = int.parse(
          headResponse.headers.value(Headers.contentLengthHeader) ?? '0',
        );

        if (fileSize <= 0) {
          throw Exception('حجم الملف غير معروف أو الرابط لا يدعم التحميل.');
        }
        task.totalBytes = fileSize;
      }

      final file = File(task.savePath);
      if (file.existsSync() && task.downloadedBytes == 0) {
        task.downloadedBytes = file.lengthSync();
      }

      if (task.threadProgress.length != numThreads) {
        task.threadProgress = List.filled(numThreads, 0.0);
      }

      if (!file.existsSync()) {
        final raf = await file.open(mode: FileMode.write);
        await raf.truncate(fileSize);
        await raf.close();
      }

      int chunkSize = (fileSize / numThreads).ceil();
      List<Future> futures = [];
      List<int> downloadedBytesPerThread = List.filled(numThreads, 0);

      int existingBytes = task.downloadedBytes;

      // تهيئة البيانات الأولية للخيوط عند الاستئناف لمنع أي تذبذب
      for (int i = 0; i < numThreads; i++) {
        int start = i * chunkSize;
        int currentThreadDownloaded = 0;
        if (existingBytes > start) {
          currentThreadDownloaded = (existingBytes - start).clamp(0, chunkSize);
        }
        downloadedBytesPerThread[i] = currentThreadDownloaded;
      }

      int lastBytes = task.downloadedBytes;
      DateTime lastTime = DateTime.now();

      for (int i = 0; i < numThreads; i++) {
        int start = i * chunkSize;
        int end =
            (i == numThreads - 1) ? fileSize - 1 : (start + chunkSize - 1);
        int actualStart = start + downloadedBytesPerThread[i];
        if (actualStart > end) continue;

        final threadIndex = i;
        futures.add(
          _downloadChunk(
            url: task.url,
            start: actualStart,
            end: end,
            outputPath: task.savePath,
            cancelToken: cancelToken,
            onProgress: (receivedChunkBytes) {
              // حساب ما تم تنزيله في هذا الخيط بشكل تراكمي وثابت
              downloadedBytesPerThread[threadIndex] =
                  (existingBytes > start ? (existingBytes - start) : 0) +
                      receivedChunkBytes;

              // التجميع الإجمالي الحقيقي لجميع الخيوط (يمنع رجوع العداد ويهدئ التذبذب)
              int totalReceived =
                  downloadedBytesPerThread.reduce((a, b) => a + b);
              task.downloadedBytes = totalReceived.clamp(0, fileSize);
              task.progress = (task.downloadedBytes / fileSize).clamp(0.0, 1.0);

              int chunkTotalSize = (end - start) + 1;
              if (chunkTotalSize > 0) {
                task.threadProgress[threadIndex] =
                    (downloadedBytesPerThread[threadIndex] / chunkTotalSize)
                        .clamp(0.0, 1.0);
              }

              // حساب السرعة والوقت المتبقي بدقة مستقرة
              final now = DateTime.now();
              final diffInMs = now.difference(lastTime).inMilliseconds;
              if (diffInMs > 500) {
                final bytesDelta = task.downloadedBytes - lastBytes;
                if (bytesDelta >= 0) {
                  task.speedBytesPerSecond = (bytesDelta / (diffInMs / 1000));

                  if (task.speedBytesPerSecond > 0) {
                    final remainingBytes = fileSize - task.downloadedBytes;
                    task.remainingSeconds =
                        (remainingBytes / task.speedBytesPerSecond).ceil();
                  }
                }
                lastBytes = task.downloadedBytes;
                lastTime = now;
              }

              onProgress(task);
            },
          ),
        );
      }

      await Future.wait(futures);

      if (!cancelToken.isCancelled) {
        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        task.speedBytesPerSecond = 0.0;
        task.remainingSeconds = 0;
        task.threadProgress = task.threadProgress.map((e) => 1.0).toList();
        _notificationService.showDownloadComplete(task.savePath);
      }
      onProgress(task);
    } catch (e) {
      _activeTokens.remove(task.id);
      bool isPaused = _isTaskPaused[task.id] ?? false;
      if (isPaused) {
        task.status = DownloadStatus.paused;
      } else {
        print('error $e');
        task.status = DownloadStatus.error;
        task.errorMessage = e.toString();
      }
      onProgress(task);
    } finally {
      _activeTokens.remove(task.id);
    }
  }

  Future<void> _downloadChunk({
    required String url,
    required int start,
    required int end,
    required String outputPath,
    required CancelToken cancelToken,
    required Function(int received) onProgress,
  }) async {
    RandomAccessFile? raf;
    try {
      Response<ResponseBody> response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          headers: {'range': 'bytes=$start-$end'},
          responseType: ResponseType.stream,
          followRedirects: true,
        ),
        cancelToken: cancelToken,
      );

      final file = File(outputPath);
      raf = await file.open(mode: FileMode.write);
      await raf.setPosition(start);

      int received = 0;
      await for (var chunk in response.data!.stream) {
        if (cancelToken.isCancelled) break;
        await raf.writeFrom(chunk);
        received += chunk.length;
        onProgress(received);
      }
    } catch (e) {
      if (cancelToken.isCancelled ||
          (e is DioException && CancelToken.isCancel(e))) {
        return;
      }
      rethrow;
    } finally {
      await raf?.close();
    }
  }
}
