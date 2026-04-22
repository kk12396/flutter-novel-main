import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

/// 应用设置配置
class AppSettings {
  final int baseDelaySeconds;      // 基础延迟秒数
  final int randomDelaySeconds;    // 随机延迟秒数
  final bool isDarkMode;           // 是否深色主题

  AppSettings({
    this.baseDelaySeconds = 30,
    this.randomDelaySeconds = 10,
    this.isDarkMode = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'baseDelaySeconds': baseDelaySeconds,
      'randomDelaySeconds': randomDelaySeconds,
      'isDarkMode': isDarkMode,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      baseDelaySeconds: json['baseDelaySeconds'] ?? 30,
      randomDelaySeconds: json['randomDelaySeconds'] ?? 10,
      isDarkMode: json['isDarkMode'] ?? false,
    );
  }

  AppSettings copyWith({
    int? baseDelaySeconds,
    int? randomDelaySeconds,
    bool? isDarkMode,
  }) {
    return AppSettings(
      baseDelaySeconds: baseDelaySeconds ?? this.baseDelaySeconds,
      randomDelaySeconds: randomDelaySeconds ?? this.randomDelaySeconds,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }

  /// 获取实际延迟时间（基础 + 随机）
  int getActualDelaySeconds() {
    final random = Random();
    return baseDelaySeconds + random.nextInt(randomDelaySeconds + 1);
  }
}

/// 设置管理服务
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  AppSettings _settings = AppSettings();
  AppSettings get settings => _settings;

  bool get isDarkMode => _settings.isDarkMode;
  int get baseDelaySeconds => _settings.baseDelaySeconds;
  int get randomDelaySeconds => _settings.randomDelaySeconds;

  /// 初始化设置
  Future<void> init() async {
    await _loadSettings();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _settings = AppSettings.fromJson(json);
      }
    } catch (e) {
      // 使用默认设置
      _settings = AppSettings();
    }
  }

  /// 保存设置
  Future<void> saveSettings(AppSettings settings) async {
    try {
      final file = await _getConfigFile();
      final content = const JsonEncoder.withIndent('  ').convert(settings.toJson());
      await file.writeAsString(content);
      _settings = settings;
    } catch (e) {
      throw Exception('保存设置失败: $e');
    }
  }

  /// 更新基础延迟
  Future<void> setBaseDelay(int seconds) async {
    final newSettings = _settings.copyWith(baseDelaySeconds: seconds);
    await saveSettings(newSettings);
  }

  /// 更新随机延迟
  Future<void> setRandomDelay(int seconds) async {
    final newSettings = _settings.copyWith(randomDelaySeconds: seconds);
    await saveSettings(newSettings);
  }

  /// 切换主题
  Future<void> toggleTheme() async {
    final newSettings = _settings.copyWith(isDarkMode: !_settings.isDarkMode);
    await saveSettings(newSettings);
  }

  /// 设置主题模式
  Future<void> setDarkMode(bool isDark) async {
    final newSettings = _settings.copyWith(isDarkMode: isDark);
    await saveSettings(newSettings);
  }

  /// 获取配置文件路径
  Future<File> _getConfigFile() async {
    // Android: 优先使用外部存储根目录，失败则使用应用私有目录
    // Windows: 使用当前目录
    if (Platform.isAndroid) {
      // 首先尝试外部存储根目录
      final novelDir = Directory('/storage/emulated/0/novelgenerator');
      try {
        if (!await novelDir.exists()) {
          await novelDir.create(recursive: true);
        }
        // 测试写入权限
        final testFile = File('${novelDir.path}/.test');
        await testFile.writeAsString('test');
        await testFile.delete();
        return File('${novelDir.path}/config.json');
      } catch (e) {
        // 降级到应用私有目录
        final appDocDir = await getApplicationDocumentsDirectory();
        return File('${appDocDir.path}/config.json');
      }
    } else {
      // Windows 和其他平台使用当前目录
      return File('${Directory.current.path}/config.json');
    }
  }
}
