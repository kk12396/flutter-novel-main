import 'package:flutter/material.dart';
import 'settings_service.dart';

/// 应用主题模式枚举
enum AppThemeMode {
  light,
  dark,
}

/// 主题管理服务
class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  AppThemeMode _currentMode = AppThemeMode.light;
  AppThemeMode get currentMode => _currentMode;

  bool get isDarkMode => _currentMode == AppThemeMode.dark;

  /// 初始化主题服务
  Future<void> init() async {
    await _loadTheme();
  }

  /// 切换主题
  void toggleTheme() {
    _currentMode = _currentMode == AppThemeMode.light ? AppThemeMode.dark : AppThemeMode.light;
    _saveTheme();
    notifyListeners();
  }

  /// 设置主题模式
  void setThemeMode(AppThemeMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      _saveTheme();
      notifyListeners();
    }
  }

  /// 从设置服务同步主题
  void syncFromSettings(bool isDark) {
    final newMode = isDark ? AppThemeMode.dark : AppThemeMode.light;
    if (_currentMode != newMode) {
      _currentMode = newMode;
      notifyListeners();
    }
  }

  /// 获取浅色主题
  ThemeData get lightTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1890FF),
      primary: const Color(0xFF1890FF),
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF0F2F5),
    cardTheme: const CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
        borderSide: BorderSide(color: Color(0xFF40A9FF)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1890FF),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF1890FF),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1890FF),
        side: const BorderSide(color: Color(0xFF1890FF)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1890FF),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Color(0xFF1890FF),
      unselectedLabelColor: Colors.black87,
      indicatorColor: Color(0xFF1890FF),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade300,
      thickness: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFE6F7FF),
      selectedColor: const Color(0xFF1890FF),
      labelStyle: const TextStyle(color: Color(0xFF096DD9)),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Colors.grey.shade800,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );

  /// 获取深色主题
  ThemeData get darkTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1890FF),
      primary: const Color(0xFF1890FF),
      brightness: Brightness.dark,
      surface: const Color(0xFF1F1F1F),
      background: const Color(0xFF141414),
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF141414),
    cardTheme: CardThemeData(
      elevation: 1,
      color: const Color(0xFF1F1F1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1F1F1F),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: Color(0xFF434343)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: Color(0xFF434343)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
        borderSide: BorderSide(color: Color(0xFF40A9FF)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1890FF),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF40A9FF),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF40A9FF),
        side: const BorderSide(color: Color(0xFF40A9FF)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1F1F1F),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Color(0xFF40A9FF),
      unselectedLabelColor: Colors.white70,
      indicatorColor: Color(0xFF40A9FF),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF434343),
      thickness: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF1890FF).withOpacity(0.2),
      selectedColor: const Color(0xFF1890FF),
      labelStyle: const TextStyle(color: Color(0xFF40A9FF)),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1F1F1F),
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: Colors.white70),
      titleLarge: TextStyle(color: Colors.white),
      titleMedium: TextStyle(color: Colors.white),
      titleSmall: TextStyle(color: Colors.white70),
    ),
  );

  /// 获取当前主题
  ThemeData get currentTheme => _currentMode == AppThemeMode.light ? lightTheme : darkTheme;

  /// 加载主题配置
  /// 优先从 SettingsService 读取，保持与 config.json 一致
  Future<void> _loadTheme() async {
    try {
      // 从设置服务读取主题配置
      final settingsService = SettingsService();
      _currentMode = settingsService.isDarkMode ? AppThemeMode.dark : AppThemeMode.light;
    } catch (e) {
      // 使用默认主题
    }
  }

  /// 保存主题配置
  /// 同步保存到 SettingsService，保持 config.json 一致性
  Future<void> _saveTheme() async {
    try {
      final settingsService = SettingsService();
      await settingsService.setDarkMode(_currentMode == AppThemeMode.dark);
    } catch (e) {
      // 忽略保存错误
    }
  }
}
