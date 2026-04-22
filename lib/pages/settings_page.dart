import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _settingsService = SettingsService();
  late int _baseDelay;
  late int _randomDelay;
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _baseDelay = _settingsService.baseDelaySeconds;
    _randomDelay = _settingsService.randomDelaySeconds;
    _isDarkMode = _settingsService.isDarkMode;
  }

  Future<void> _saveSettings() async {
    final newSettings = AppSettings(
      baseDelaySeconds: _baseDelay,
      randomDelaySeconds: _randomDelay,
      isDarkMode: _isDarkMode,
    );
    await _settingsService.saveSettings(newSettings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFFF0F0F0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('系统设置'),
        backgroundColor: const Color(0xFF1890FF),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 主题设置
            _buildSectionTitle('外观设置'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: const Color(0xFF1890FF),
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '深色主题',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '切换应用的浅色/深色主题',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isDarkMode,
                    onChanged: (value) {
                      setState(() {
                        _isDarkMode = value;
                      });
                      _saveSettings();
                      // 同步更新主题服务
                      ThemeService().syncFromSettings(value);
                    },
                    activeColor: const Color(0xFF1890FF),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 自动续写设置
            _buildSectionTitle('自动续写设置'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '请求间隔时间',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '自动续写时每次请求之间的基础等待时间，避免API请求过于频繁',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '基础延迟: ${_baseDelay}秒',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            Slider(
                              value: _baseDelay.toDouble(),
                              min: 10,
                              max: 240,
                              divisions: 23,
                              label: '${_baseDelay}秒',
                              onChanged: (value) {
                                setState(() {
                                  _baseDelay = value.round();
                                });
                              },
                              onChangeEnd: (_) => _saveSettings(),
                              activeColor: const Color(0xFF1890FF),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    '随机延迟范围',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '在基础延迟上增加的随机时间范围，使请求间隔更加自然',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '随机延迟: 0-${_randomDelay}秒',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            Slider(
                              value: _randomDelay.toDouble(),
                              min: 0,
                              max: 60,
                              divisions: 12,
                              label: '${_randomDelay}秒',
                              onChanged: (value) {
                                setState(() {
                                  _randomDelay = value.round();
                                });
                              },
                              onChangeEnd: (_) => _saveSettings(),
                              activeColor: const Color(0xFF1890FF),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1890FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: const Color(0xFF1890FF),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '实际延迟时间 = ${_baseDelay}秒 + (0~${_randomDelay}秒随机)',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 关于
            _buildSectionTitle('关于'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.book,
                        color: const Color(0xFF1890FF),
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI 小说生成器',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '版本 1.1.0',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '基于大语言模型的智能小说创作工具，支持多种AI提供商。',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
    );
  }
}
