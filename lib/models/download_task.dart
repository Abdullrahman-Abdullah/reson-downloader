enum DownloadStatus { downloading, paused, completed, error }

class DownloadTask {
  final String id;
  final String url;
  final String savePath;
  int totalBytes;
  int downloadedBytes;
  double progress;
  DownloadStatus status;
  String errorMessage;
  double speedBytesPerSecond;
  int remainingSeconds;
  List<double> threadProgress;

  DownloadTask({
    required this.id,
    required this.url,
    required this.savePath,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.progress = 0.0,
    this.status = DownloadStatus.downloading,
    this.errorMessage = '',
    this.speedBytesPerSecond = 0.0,
    this.remainingSeconds = 0,
    this.threadProgress = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'savePath': savePath,
        'totalBytes': totalBytes,
        'downloadedBytes': downloadedBytes,
        'progress': progress,
        'status': status.index,
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
        id: json['id'],
        url: json['url'],
        savePath: json['savePath'],
        totalBytes: json['totalBytes'] ?? 0,
        downloadedBytes: json['downloadedBytes'] ?? 0,
        progress: json['progress'] ?? 0.0,
        status: DownloadStatus.values[json['status'] ?? 0],
      );
}