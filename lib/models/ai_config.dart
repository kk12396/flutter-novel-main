import 'dart:convert';
import 'dart:io';

class ProviderConfig {
  final String type;
  final String name;
  final String apiKey;
  final String baseUrl;
  final List<String> model;

  ProviderConfig({
    required this.type,
    required this.name,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'name': name,
      'api_key': apiKey,
      'base_url': baseUrl,
      'model': model,
    };
  }

  factory ProviderConfig.fromJson(Map<String, dynamic> json) {
    return ProviderConfig(
      type: json['type'] ?? 'openai',
      name: json['name'] ?? '',
      apiKey: json['api_key'] ?? '',
      baseUrl: json['base_url'] ?? '',
      model: (json['model'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  ProviderConfig copyWith({
    String? type,
    String? name,
    String? apiKey,
    String? baseUrl,
    List<String>? model,
  }) {
    return ProviderConfig(
      type: type ?? this.type,
      name: name ?? this.name,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? List<String>.from(this.model),
    );
  }
}

class AIConfig {
  final String currentProvider;
  final String currentModel;
  final Map<String, ProviderConfig> providers;
  final int timeoutSeconds;

  AIConfig({
    required this.currentProvider,
    required this.currentModel,
    required this.providers,
    this.timeoutSeconds = 120,
  });

  Map<String, dynamic> toJson() {
    return {
      'current_provider': currentProvider,
      'current_model': currentModel,
      'providers': providers.map((k, v) => MapEntry(k, v.toJson())),
      'timeout_seconds': timeoutSeconds,
    };
  }

  factory AIConfig.fromJson(Map<String, dynamic> json) {
    final providersMap = (json['providers'] as Map<String, dynamic>?) ?? {};
    return AIConfig(
      currentProvider: json['current_provider'] ?? 'openrouter',
      currentModel: json['current_model'] ?? 'stepfun/step-3.5-flash:free',
      providers: providersMap.map((k, v) => MapEntry(k, ProviderConfig.fromJson(v))),
      timeoutSeconds: json['timeout_seconds'] ?? 120,
    );
  }

  static AIConfig getDefaultConfig() {
    return AIConfig(
      currentProvider: 'openrouter',
      currentModel: 'nvidia/nemotron-3-super-120b-a12b:free',
      providers: {
        'openrouter': ProviderConfig(
          type: 'openai',
          name: 'OpenRouter',
          apiKey: '',
          baseUrl: 'https://openrouter.ai/api/v1',
          model: [
            'nvidia/nemotron-3-super-120b-a12b:free',
            'minimax/minimax-m2.5:free',
            'stepfun/step-3.5-flash:free',
            'arcee-ai/trinity-large-preview:free',
            'arcee-ai/trinity-mini:free',
            'z-ai/glm-4.5-air:free',
          ],
        ),
        'openai': ProviderConfig(
          type: 'openai',
          name: 'OpenAI',
          apiKey: '',
          baseUrl: 'https://api.openai.com/v1',
          model: ['gpt-4', 'gpt-4-turbo', 'gpt-3.5-turbo'],
        ),
        'ollama': ProviderConfig(
          type: 'ollama',
          name: 'Ollama',
          apiKey: '',
          baseUrl: 'http://localhost:11434',
          model: [],
        ),
        'claude': ProviderConfig(
          type: 'claude',
          name: 'Claude',
          apiKey: '',
          baseUrl: 'https://api.anthropic.com',
          model: ['claude-3-opus-20240229', 'claude-3-sonnet-20240229', 'claude-3-haiku-20240307'],
        ),
        'gemini': ProviderConfig(
          type: 'gemini',
          name: 'Gemini',
          apiKey: '',
          baseUrl: 'https://generativelanguage.googleapis.com/v1',
          model: ['gemini-pro', 'gemini-pro-vision'],
        ),
        'deepseek': ProviderConfig(
          type: 'openai',
          name: 'DeepSeek',
          apiKey: '',
          baseUrl: 'https://api.deepseek.com/v1',
          model: ['deepseek-chat', 'deepseek-coder'],
        ),
        'zhipu': ProviderConfig(
          type: 'openai',
          name: '智谱',
          apiKey: '',
          baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
          model: ['glm-4', 'glm-4-flash', 'glm-3-turbo'],
        ),
        'qwen': ProviderConfig(
          type: 'openai',
          name: '通义千问',
          apiKey: '',
          baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
          model: ['qwen-turbo', 'qwen-plus', 'qwen-max'],
        ),
        'moonshot': ProviderConfig(
          type: 'openai',
          name: 'Kimi',
          apiKey: '',
          baseUrl: 'https://api.moonshot.cn/v1',
          model: ['moonshot-v1-8k', 'moonshot-v1-32k', 'moonshot-v1-128k'],
        ),
        'doubao': ProviderConfig(
          type: 'openai',
          name: '豆包',
          apiKey: '',
          baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
          model: ['doubao-pro-4k', 'doubao-pro-32k', 'doubao-lite-4k'],
        ),
        'spark': ProviderConfig(
          type: 'openai',
          name: '讯飞星火',
          apiKey: '',
          baseUrl: 'https://spark-api-open.xf-yun.com/v1',
          model: ['generalv3.5', 'generalv3', 'pro-128k'],
        ),
        'hunyuan': ProviderConfig(
          type: 'openai',
          name: '腾讯混元',
          apiKey: '',
          baseUrl: 'https://hunyuan.tencentcloudapi.com/v1',
          model: ['hunyuan-pro', 'hunyuan-standard', 'hunyuan-lite'],
        ),
        'ernie': ProviderConfig(
          type: 'openai',
          name: '文心一言',
          apiKey: '',
          baseUrl: 'https://qianfan.baidubce.com/v2',
          model: ['ernie-4.0-turbo-8k', 'ernie-3.5-8k', 'ernie-speed-128k'],
        ),
        'custom': ProviderConfig(
          type: 'openai',
          name: '自定义 API',
          apiKey: '',
          baseUrl: '',
          model: [],
        ),
      },
    );
  }
}
