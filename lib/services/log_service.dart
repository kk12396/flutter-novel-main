import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  File? _logFile;
  final _lock = Object();

  Future<void> init() async {
    Directory logDir;
    
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final exePath = Platform.resolvedExecutable;
      final exeDir = File(exePath).parent;
      logDir = Directory('${exeDir.path}/logs');
    } else if (Platform.isAndroid) {
      final appDir = await getExternalStorageDirectory();
      logDir = Directory('${appDir!.path}/logs');
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      logDir = Directory('${appDir.path}/logs');
    }
    
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    
    final dateStr = _formatDateForFileName(DateTime.now());
    _logFile = File('${logDir.path}/app_$dateStr.log');
    
    await log('=== 应用程序启动 ===');
  }

  // 获取日志文件路径
  String? get logFilePath => _logFile?.path;

  // 记录日志（带时间戳）
  Future<void> log(String message, {String level = 'INFO'}) async {
    final timestamp = _formatTimestamp(DateTime.now());
    final logLine = '[$timestamp] [$level] $message\n';
    
    // 同时输出到控制台
    print(logLine.trim());
    
    // 写入文件
    if (_logFile != null) {
      try {
        await _logFile!.writeAsString(logLine, mode: FileMode.append, flush: true);
      } catch (e) {
        print('[$timestamp] [ERROR] 写入日志失败: $e');
      }
    }
  }

  // 记录错误
  Future<void> error(String message, [dynamic error, StackTrace? stackTrace]) async {
    final buffer = StringBuffer();
    buffer.write(message);
    
    if (error != null) {
      buffer.write('\n错误详情: $error');
    }
    
    if (stackTrace != null) {
      buffer.write('\n堆栈跟踪:\n$stackTrace');
    }
    
    await log(buffer.toString(), level: 'ERROR');
  }

  // 记录警告
  Future<void> warning(String message) async {
    await log(message, level: 'WARN');
  }

  // 记录调试信息
  Future<void> debug(String message) async {
    await log(message, level: 'DEBUG');
  }

  // 记录API请求
  Future<void> apiRequest(String provider, String model, String prompt) async {
    final promptPreview = prompt.length > 100 ? '${prompt.substring(0, 100)}...' : prompt;
    await log('API请求 [$provider] 模型: $model, 提示词: $promptPreview', level: 'API');
  }

  // 记录API响应
  Future<void> apiResponse(String provider, String response, {int? statusCode, int? durationMs}) async {
    final responsePreview = response.length > 200 ? '${response.substring(0, 200)}...' : response;
    final statusInfo = statusCode != null ? '状态码: $statusCode, ' : '';
    final durationInfo = durationMs != null ? '耗时: ${durationMs}ms' : '';
    await log('API响应 [$provider] $statusInfo$durationInfo\n内容: $responsePreview', level: 'API');
  }

  // 记录API错误
  Future<void> apiError(String provider, String error, {String? request}) async {
    final buffer = StringBuffer();
    buffer.write('API错误 [$provider]: $error');
    if (request != null) {
      buffer.write('\n请求内容: $request');
    }
    await log(buffer.toString(), level: 'ERROR');
  }

  // 格式化时间戳
  String _formatTimestamp(DateTime dt) {
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} ${_pad(dt.hour)}:${_pad(dt.minute)}:${_pad(dt.second)}.${_pad(dt.millisecond, 3)}';
  }

  // 格式化日期（用于文件名）
  String _formatDateForFileName(DateTime dt) {
    return '${dt.year}${_pad(dt.month)}${_pad(dt.day)}';
  }

  String _pad(int n, [int width = 2]) {
    return n.toString().padLeft(width, '0');
  }

  // 读取最近日志
  Future<String> readRecentLogs({int lines = 100}) async {
    if (_logFile == null || !await _logFile!.exists()) {
      return '暂无日志';
    }
    
    try {
      final content = await _logFile!.readAsString();
      final allLines = content.split('\n');
      if (allLines.length <= lines) {
        return content;
      }
      return allLines.sublist(allLines.length - lines).join('\n');
    } catch (e) {
      return '读取日志失败: $e';
    }
  }

  // 清理旧日志（保留最近7天）
  Future<void> cleanOldLogs() async {
    Directory logDir;
    
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final exePath = Platform.resolvedExecutable;
      final exeDir = File(exePath).parent;
      logDir = Directory('${exeDir.path}/logs');
    } else if (Platform.isAndroid) {
      final appDir = await getExternalStorageDirectory();
      logDir = Directory('${appDir!.path}/logs');
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      logDir = Directory('${appDir.path}/logs');
    }
    
    if (!await logDir.exists()) return;

    final now = DateTime.now();
    final files = await logDir.list().toList();
    
    for (final file in files.whereType<File>()) {
      try {
        final stat = await file.stat();
        final age = now.difference(stat.modified);
        if (age.inDays > 7) {
          await file.delete();
        }
      } catch (e) {
        // 忽略删除错误
      }
    }
  }
}
