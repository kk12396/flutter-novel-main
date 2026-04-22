import 'package:flutter/material.dart';
import 'pages/start_page.dart';
import 'services/log_service.dart';
import 'services/theme_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化设置服务
  await SettingsService().init();
  
  // 初始化服务 - 使用 Future.wait 并行初始化
  await Future.wait([
    LogService().init(),
    ThemeService().init(),
  ]);
  
  // 清理旧日志 - 不阻塞启动
  LogService().cleanOldLogs();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI小说生成器',
      debugShowCheckedModeBanner: false,
      theme: _themeService.lightTheme,
      darkTheme: _themeService.darkTheme,
      themeMode: _themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const StartPage(),
    );
  }
}
