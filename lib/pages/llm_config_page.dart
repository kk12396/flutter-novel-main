import 'package:flutter/material.dart';
import '../models/ai_config.dart';
import '../services/ai_config_service.dart';
import '../services/llm_service.dart';

class LLMConfigPage extends StatefulWidget {
  const LLMConfigPage({super.key});

  @override
  State<LLMConfigPage> createState() => _LLMConfigPageState();
}

class _LLMConfigPageState extends State<LLMConfigPage> {
  final AIConfigService _configService = AIConfigService();
  AIConfig _config = AIConfig.getDefaultConfig();
  bool _isLoading = false;
  bool _isOllamaLoading = false;
  String _testResult = '';
  List<String> _currentModels = [];
  int _selectedModelIndex = -1;

  static const List<int> _timeoutOptions = [30, 60, 90, 120, 150, 180, 210, 240, 270, 300];
  static const List<String> _providerTypes = ['openai', 'claude', 'gemini', 'ollama'];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await _configService.getConfig();
    setState(() {
      _config = config;
      _updateCurrentModels();
    });
  }

  void _updateCurrentModels() {
    final provider = _config.providers[_config.currentProvider];
    if (provider != null) {
      _currentModels = List<String>.from(provider.model);
      _selectedModelIndex = _currentModels.indexOf(_config.currentModel);
      if (_selectedModelIndex == -1 && _currentModels.isNotEmpty) {
        _selectedModelIndex = 0;
      }
    } else {
      _currentModels = [];
      _selectedModelIndex = -1;
    }
  }

  Future<void> _saveConfig() async {
    final currentProvider = _config.providers[_config.currentProvider];
    if (currentProvider != null) {
      final updatedProvider = currentProvider.copyWith(
        apiKey: currentProvider.apiKey,
        baseUrl: currentProvider.baseUrl,
      );
      final updatedProviders = Map<String, ProviderConfig>.from(_config.providers);
      updatedProviders[_config.currentProvider] = updatedProvider;
      
      final updatedConfig = AIConfig(
        currentProvider: _config.currentProvider,
        currentModel: _config.currentModel,
        providers: updatedProviders,
        timeoutSeconds: _config.timeoutSeconds,
      );
      
      await _configService.saveConfig(updatedConfig);
      setState(() => _config = updatedConfig);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已保存')),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _testResult = '';
    });

    try {
      final provider = _config.providers[_config.currentProvider];
      if (provider == null) {
        setState(() => _testResult = '连接失败: 供应商配置不存在');
        return;
      }

      // Ollama不需要API Key
      if (provider.type != 'ollama' && provider.apiKey.isEmpty) {
        setState(() => _testResult = '连接失败: 请输入API Key');
        return;
      }

      final success = await LLMService.testConnection(_config);
      setState(() => _testResult = success ? '连接成功' : '连接失败');
    } catch (e) {
      setState(() => _testResult = '连接失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onProviderChanged(String? value) async {
    if (value == null) return;
    
    final newProvider = _config.providers[value];
    if (newProvider == null) return;

    setState(() {
      _currentModels = [];
      _selectedModelIndex = -1;
    });

    List<String> models = List<String>.from(newProvider.model);

    if (value == 'ollama') {
      setState(() => _isOllamaLoading = true);
      models = await _configService.fetchOllamaModels(newProvider.baseUrl);
      setState(() => _isOllamaLoading = false);
    }

    String newModel = _config.currentModel;
    int newModelIndex = models.indexOf(newModel);
    
    if (models.isNotEmpty) {
      if (newModelIndex == -1 || value != _config.currentProvider) {
        newModel = models.first;
        newModelIndex = 0;
      }
    }

    final updatedProviders = Map<String, ProviderConfig>.from(_config.providers);
    updatedProviders[value] = newProvider.copyWith(model: models);

    setState(() {
      _config = AIConfig(
        currentProvider: value,
        currentModel: newModel,
        providers: updatedProviders,
        timeoutSeconds: _config.timeoutSeconds,
      );
      _currentModels = models;
      _selectedModelIndex = newModelIndex;
    });
  }

  void _onModelChanged(String? value) {
    if (value == null) return;
    final index = _currentModels.indexOf(value);
    if (index != -1) {
      setState(() {
        _config = AIConfig(
          currentProvider: _config.currentProvider,
          currentModel: value,
          providers: _config.providers,
          timeoutSeconds: _config.timeoutSeconds,
        );
        _selectedModelIndex = index;
      });
    }
  }

  void _updateProviderApiKey(String value) {
    final provider = _config.providers[_config.currentProvider];
    if (provider != null) {
      final updatedProviders = Map<String, ProviderConfig>.from(_config.providers);
      updatedProviders[_config.currentProvider] = provider.copyWith(apiKey: value);
      setState(() {
        _config = AIConfig(
          currentProvider: _config.currentProvider,
          currentModel: _config.currentModel,
          providers: updatedProviders,
          timeoutSeconds: _config.timeoutSeconds,
        );
      });
    }
  }

  void _updateProviderBaseUrl(String value) {
    final provider = _config.providers[_config.currentProvider];
    if (provider != null) {
      final updatedProviders = Map<String, ProviderConfig>.from(_config.providers);
      updatedProviders[_config.currentProvider] = provider.copyWith(baseUrl: value);
      setState(() {
        _config = AIConfig(
          currentProvider: _config.currentProvider,
          currentModel: _config.currentModel,
          providers: updatedProviders,
          timeoutSeconds: _config.timeoutSeconds,
        );
      });
    }
  }

  void _showAddProviderDialog() {
    final nameController = TextEditingController();
    final apiKeyController = TextEditingController();
    final baseUrlController = TextEditingController();
    String selectedType = 'openai';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加供应商'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '供应商名称',
                    hintText: '例如: My API',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: '类型'),
                  items: _providerTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    hintText: '可选',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: baseUrlController,
                  decoration: const InputDecoration(
                    labelText: '基础URL',
                    hintText: '例如: https://api.example.com/v1',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入供应商名称')),
                  );
                  return;
                }
                
                final key = nameController.text.toLowerCase().replaceAll(' ', '_');
                if (_config.providers.containsKey(key)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('供应商已存在')),
                  );
                  return;
                }

                final newProvider = ProviderConfig(
                  type: selectedType,
                  name: nameController.text,
                  apiKey: apiKeyController.text,
                  baseUrl: baseUrlController.text,
                  model: [],
                );

                final updatedProviders = Map<String, ProviderConfig>.from(_config.providers);
                updatedProviders[key] = newProvider;

                setState(() {
                  _config = AIConfig(
                    currentProvider: key,
                    currentModel: '',
                    providers: updatedProviders,
                    timeoutSeconds: _config.timeoutSeconds,
                  );
                  _currentModels = [];
                  _selectedModelIndex = -1;
                });

                Navigator.pop(context);
                _saveConfig();
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteProviderDialog() {
    if (_config.providers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少保留一个供应商')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除供应商'),
        content: Text('确定要删除 "${_config.providers[_config.currentProvider]?.name}" 吗?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedProviders = Map<String, ProviderConfig>.from(_config.providers);
              updatedProviders.remove(_config.currentProvider);
              
              final newProviderKey = updatedProviders.keys.first;
              final newProvider = updatedProviders[newProviderKey]!;
              final newModel = newProvider.model.isNotEmpty ? newProvider.model.first : '';

              setState(() {
                _config = AIConfig(
                  currentProvider: newProviderKey,
                  currentModel: newModel,
                  providers: updatedProviders,
                  timeoutSeconds: _config.timeoutSeconds,
                );
                _currentModels = List<String>.from(newProvider.model);
                _selectedModelIndex = newProvider.model.isNotEmpty ? 0 : -1;
              });

              Navigator.pop(context);
              _saveConfig();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddModelDialog() {
    final modelController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加模型'),
        content: TextField(
          controller: modelController,
          decoration: const InputDecoration(
            labelText: '模型名称',
            hintText: '例如: gpt-4',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (modelController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入模型名称')),
                );
                return;
              }

              final provider = _config.providers[_config.currentProvider];
              if (provider == null) return;

              if (provider.model.contains(modelController.text)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('模型已存在')),
                );
                return;
              }

              final newModels = List<String>.from(provider.model)..add(modelController.text);
              final updatedProviders = Map<String, ProviderConfig>.from(_config.providers);
              updatedProviders[_config.currentProvider] = provider.copyWith(model: newModels);

              setState(() {
                _config = AIConfig(
                  currentProvider: _config.currentProvider,
                  currentModel: modelController.text,
                  providers: updatedProviders,
                  timeoutSeconds: _config.timeoutSeconds,
                );
                _currentModels = newModels;
                _selectedModelIndex = newModels.length - 1;
              });

              Navigator.pop(context);
              _saveConfig();
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showDeleteModelDialog() {
    if (_currentModels.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除模型'),
        content: Text('确定要删除 "${_config.currentModel}" 吗?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final provider = _config.providers[_config.currentProvider];
              if (provider == null) return;

              final newModels = List<String>.from(provider.model)..remove(_config.currentModel);
              final updatedProviders = Map<String, ProviderConfig>.from(_config.providers);
              updatedProviders[_config.currentProvider] = provider.copyWith(model: newModels);

              final newModel = newModels.isNotEmpty ? newModels.first : '';

              setState(() {
                _config = AIConfig(
                  currentProvider: _config.currentProvider,
                  currentModel: newModel,
                  providers: updatedProviders,
                  timeoutSeconds: _config.timeoutSeconds,
                );
                _currentModels = newModels;
                _selectedModelIndex = newModels.isNotEmpty ? 0 : -1;
              });

              Navigator.pop(context);
              _saveConfig();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentProvider = _config.providers[_config.currentProvider];
    final isOllama = currentProvider?.type == 'ollama';

    return Scaffold(
      appBar: AppBar(
        title: const Text('LLM 配置'),
        backgroundColor: const Color(0xFF1890FF),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('供应商配置'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: '供应商',
                    value: _config.currentProvider,
                    items: _config.providers.keys.map((k) {
                      return DropdownMenuItem(value: k, child: Text(_config.providers[k]!.name));
                    }).toList(),
                    onChanged: _onProviderChanged,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _showAddProviderDialog,
                  icon: const Icon(Icons.add, color: Color(0xFF1890FF)),
                  tooltip: '添加供应商',
                ),
                IconButton(
                  onPressed: _showDeleteProviderDialog,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: '删除供应商',
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Ollama不需要API Key
            if (!isOllama) ...[
              _buildTextField(
                label: 'API Key',
                value: currentProvider?.apiKey ?? '',
                obscureText: false,
                onChanged: _updateProviderApiKey,
              ),
              const SizedBox(height: 16),
            ],
            _buildTextField(
              label: '基础URL',
              value: currentProvider?.baseUrl ?? '',
              onChanged: _updateProviderBaseUrl,
            ),
            const SizedBox(height: 16),
            if (_isOllamaLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _currentModels.isNotEmpty
                        ? _buildDropdown(
                            label: '模型',
                            value: _config.currentModel.isNotEmpty && _currentModels.contains(_config.currentModel)
                                ? _config.currentModel
                                : (_currentModels.isNotEmpty ? _currentModels.first : null),
                            items: _currentModels.map((m) {
                              return DropdownMenuItem(value: m, child: Text(m));
                            }).toList(),
                            onChanged: _onModelChanged,
                          )
                        : _buildTextField(
                            label: '模型',
                            value: _config.currentModel,
                            onChanged: (v) => setState(() {
                              _config = AIConfig(
                                currentProvider: _config.currentProvider,
                                currentModel: v,
                                providers: _config.providers,
                                timeoutSeconds: _config.timeoutSeconds,
                              );
                            }),
                          ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _showAddModelDialog,
                    icon: const Icon(Icons.add, color: Color(0xFF1890FF)),
                    tooltip: '添加模型',
                  ),
                  if (_currentModels.isNotEmpty)
                    IconButton(
                      onPressed: _showDeleteModelDialog,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: '删除模型',
                    ),
                ],
              ),
            const SizedBox(height: 16),
            _buildDropdown<int>(
              label: '请求超时时间',
              value: _timeoutOptions.contains(_config.timeoutSeconds) 
                  ? _config.timeoutSeconds 
                  : 120,
              items: _timeoutOptions.map((t) {
                return DropdownMenuItem(value: t, child: Text('$t 秒'));
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _config = AIConfig(
                      currentProvider: _config.currentProvider,
                      currentModel: _config.currentModel,
                      providers: _config.providers,
                      timeoutSeconds: v,
                    );
                  });
                }
              },
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _saveConfig,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1890FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('保存配置', style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: _isLoading ? null : _testConnection,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1890FF),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    _isLoading ? '测试中...' : '测试连接',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF1890FF)),
                  ),
                ),
              ],
            ),
            if (_testResult.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testResult.contains('成功')
                      ? const Color(0xFFF6FFED)
                      : const Color(0xFFFFF2F0),
                  border: Border.all(
                    color: _testResult.contains('成功')
                        ? const Color(0xFFB7EB8F)
                        : const Color(0xFFFFCCC7),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      _testResult.contains('成功') ? Icons.check_circle : Icons.error,
                      color: _testResult.contains('成功')
                          ? const Color(0xFF52C41A)
                          : const Color(0xFFFF4D4F),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_testResult)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0066CC),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    bool obscureText = false,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: value),
          obscureText: obscureText,
          onChanged: onChanged,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}
