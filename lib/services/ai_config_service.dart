import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/ai_config.dart';
import 'package:http/http.dart' as http;

class AIConfigService {
  static final AIConfigService _instance = AIConfigService._internal();
  factory AIConfigService() => _instance;
  AIConfigService._internal();

  AIConfig? _config;
  bool _loaded = false;

  Future<AIConfig> getConfig() async {
    if (_loaded) {
      return _config ?? AIConfig.getDefaultConfig();
    }
    await _loadConfig();
    return _config ?? AIConfig.getDefaultConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _config = AIConfig.fromJson(json);
      } else {
        _config = AIConfig.getDefaultConfig();
      }
    } catch (e) {
      _config = AIConfig.getDefaultConfig();
    }
    _loaded = true;
  }

  Future<void> saveConfig(AIConfig config) async {
    try {
      final file = await _getConfigFile();
      final content = const JsonEncoder.withIndent('  ').convert(config.toJson());
      await file.writeAsString(content);
      _config = config;
    } catch (e) {
      throw Exception('保存配置失败: $e');
    }
  }

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
        return File('${novelDir.path}/ai_config.json');
      } catch (e) {
        // 降级到应用私有目录
        final appDocDir = await getApplicationDocumentsDirectory();
        return File('${appDocDir.path}/ai_config.json');
      }
    } else {
      // Windows 和其他平台使用当前目录
      return File('${Directory.current.path}/ai_config.json');
    }
  }

  Future<List<String>> fetchOllamaModels(String baseUrl) async {
    try {
      final url = Uri.parse('$baseUrl/api/tags');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List?) ?? [];
        return models.map((m) => m['name']?.toString() ?? '').where((m) => m.isNotEmpty).toList();
      }
    } catch (e) {
      // 忽略错误
    }
    return [];
  }

  void reset() {
    _loaded = false;
    _config = null;
  }
}
