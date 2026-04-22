import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/ai_config.dart';
import 'log_service.dart';

class LLMMessage {
  final String role;
  final String content;

  LLMMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() {
    return {'role': role, 'content': content};
  }
}

class LLMService {
  static final http.Client _client = http.Client();
  static final LogService _log = LogService();
  
  static String _getUserAgent() {
    if (Platform.isAndroid) {
      return 'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
    } else if (Platform.isIOS) {
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
    } else if (Platform.isWindows) {
      return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    } else if (Platform.isMacOS) {
      return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    } else if (Platform.isLinux) {
      return 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    }
    return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  }
  
  static Future<http.Response> _postWithRetry(
    Uri url,
    Map<String, String> headers,
    String body, {
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 180),
  }) async {
    int attempt = 0;
    Exception? lastError;
    
    final fullHeaders = <String, String>{
      'User-Agent': _getUserAgent(),
      ...headers,
    };
    
    while (attempt < maxRetries) {
      try {
        attempt++;
        await _log.log('HTTP请求尝试 $attempt/$maxRetries: $url');
        
        final response = await _client.post(
          url,
          headers: fullHeaders,
          body: body,
        ).timeout(timeout, onTimeout: () {
          throw Exception('请求超时(${timeout.inSeconds}秒)');
        });
        
        return response;
      } on http.ClientException catch (e) {
        lastError = e;
        await _log.warning('HTTP请求失败(尝试 $attempt/$maxRetries): $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      } on SocketException catch (e) {
        lastError = Exception('网络连接错误: ${e.message}');
        await _log.warning('网络错误(尝试 $attempt/$maxRetries): $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      } on Exception {
        rethrow;
      }
    }
    
    throw lastError ?? Exception('请求失败，已达最大重试次数');
  }

  static const String _baseSystemPrompt = '''你是专业小说创作助手「墨韵」。

【核心准则】
1. 语言：纯中文输出，禁止任何英文（包括专有名词用中文音译）
2. 格式：严格遵循用户指定的输出格式，使用===标记包裹各区块
3. 质量：内容专业、逻辑连贯、描写生动
4. 风格：根据小说类型自动调整叙事风格

【输出规范】
- 只输出要求的内容，不添加解释性文字
- 不使用Markdown代码块包裹内容
- 保持段落清晰，适当使用空行分隔''';

  static const String _chapterSystemPrompt = '''你是专业小说创作助手「墨韵」，专注于高质量小说章节创作。

【核心准则】
1. 语言：纯中文输出，禁止任何英文（专有名词用中文音译）
2. 格式：严格遵循用户指定的输出格式
3. 质量：描写细腻、情节紧凑、对话自然、人物立体

═══════════════════════════════════════
⚠️ 最高优先级：比喻句式限制 ⚠️
═══════════════════════════════════════

【硬性指标】
- "像"字比喻：每章最多3次（超过即失败）
- "仿佛/好似/如同/宛如"：每章最多2次
- 禁止连续两段使用比喻句式

【为什么这是最高优先级】
AI生成最明显的特征就是比喻泛滥（每章20+次），这是读者一眼就能识别的AI痕迹。
正常人类作家每章只用3-5次比喻，且每次都有明确功能。

【比喻使用原则】
比喻必须有功能，不能只是装饰：
- ✅ 功能性比喻：帮助理解陌生概念、强化情绪冲击、揭示人物心理
- ❌ 装饰性比喻：只是让句子"看起来更有文采"，删除后不影响理解

【判断标准】
删除这个比喻后，读者理解是否受影响？
- 不受影响 → 删除，用直接描写
- 受影响 → 保留

【替代方案】
1. 直接描写（最优先）
   不必要："雨像无数根银针"
   直接写："雨砸在青石板上，水花溅起半尺高"

2. 动词替代
   不必要："声音像拧在耳膜上"
   用动作："铁条吱扭一声，她耳膜跟着一紧"

3. 感官细节
   不必要："冰凉得像尸水"
   用感官："雨水钻进衣领，凉意顺着脊椎往下爬"

4. 省略比喻词
   不必要："黑得像墓坑"
   直接写："黑。伸手不见五指的黑"

5. 具体化
   不必要："像被谁掐住脖子"
   具体写："光线只照出前面一截，后面全吞进黑暗"

【检查方法】
生成后必须统计"像"字出现次数，超过3次必须逐个删除或改写。

═══════════════════════════════════════
去AI化核心框架（P.S.O.E）- 必须严格执行
═══════════════════════════════════════

【P - 具体的人物（Persona）】
- 拒绝模糊标签，每个角色都有具体特征、处境、动机
- 错误示例："一个创业者"
- 正确示例："32岁的前程序员，有房贷和2岁女儿，在微信上卖自制辣酱"
- 每个配角都要有独立的人格，不能只是主角的工具人

【S - 具体的场景（Scene）】
- 描述时间、地点、环境、感官细节
- 错误示例："在工作场合"
- 正确示例："凌晨2点的便利店，他一边等关东煮加热，一边用手机回复客户投诉"
- 场景必须服务于情节，不能为了描写而描写

【O - 口语化表达（Oral）】
- 用自然交谈语气替换书面化词汇
- 错误示例："综上所述""具有重要意义"
- 正确示例："唠了这么多""这事儿成了"
- 适当使用语气词：其实呢、话说、嗯、呀
- 善用短句、叠词：试试看、慢慢来、搞一下

【E - 情绪共鸣（Emotion）】
- 禁止直接陈述情绪，通过动作、微表情、细节展现
- 错误示例："他感到难过"
- 正确示例："他盯着那个红色的'发送失败'感叹号，愣了三秒，然后把手机屏幕朝下扣在了桌上"

═══════════════════════════════════════
叙述视角规则
═══════════════════════════════════════

- 默认使用第三人称叙述（他/她/它）
- 第一人称（我）仅用于：
  · 回忆片段：需用"他回想起..."、"记忆如潮水般涌来..."等引入
  · 内心独白：需用引号或独立段落标记
  · 日记/信件：需有明确格式标记
- 禁止突然切换视角，必须有明确过渡
- 错误示例：直接以"我牵着若雪的手"开头（突兀）
- 正确示例："凌云牵着若雪的手...他忽然想起三年前的灯市..."（第三人称+回忆引入）

═══════════════════════════════════════
禁用词汇（每词每章最多1次）
═══════════════════════════════════════

- 愣了愣→怔住、呆住、一时没反应过来
- 苦笑→无奈一笑、自嘲地笑笑、扯了扯嘴角
- 摸了摸下巴→思索片刻、沉吟、若有所思
- 长舒一口气→松了口气、如释重负、放下心来
- 心中一动→心中一凛、心头一跳、灵光一闪
- 眼中闪过一丝→眼中掠过一抹、眼底浮现、目光中透出

═══════════════════════════════════════
禁止事项
═══════════════════════════════════════

- 英文单词、英文标点
- 固定套路结构（如每章都是清晨→系统提示→找师傅→一天学会）
- 相同结尾模板：禁止"闭上眼睛沉沉睡去"类结尾
- 瞬移式场景切换：场景转换必须有明确动机和过渡
- 形容词堆砌："非常""特别""极其"等程度副词
- 抽象空洞：偏好"人生哲理""深刻内涵"等宏大概念
- 缺乏细节：仅呈现结论与评价，省略过程、场景与感官描写
- 比喻泛滥：每章"像"字超过3次，或连续段落使用比喻''';

  static Future<String> callLLMWithConfig(List<LLMMessage> messages, AIConfig config) async {
    return callLLMWithSystemPrompt(messages, config, _baseSystemPrompt);
  }

  static Future<String> callLLMForChapter(List<LLMMessage> messages, AIConfig config) async {
    return callLLMWithSystemPrompt(messages, config, _chapterSystemPrompt);
  }

  static Future<String> callLLMWithSystemPrompt(
    List<LLMMessage> messages,
    AIConfig config,
    String systemPrompt,
  ) async {
    final messagesWithSystemPrompt = [
      LLMMessage(role: 'system', content: systemPrompt),
      ...messages,
    ];
    final provider = config.providers[config.currentProvider];
    if (provider == null) {
      final error = 'LLM服务配置未找到: ${config.currentProvider}';
      await _log.error(error);
      throw Exception(error);
    }

    await _log.log('调用LLM: provider=${config.currentProvider}, type=${provider.type}, model=${config.currentModel}');

    final stopwatch = Stopwatch()..start();
    
    try {
      String result;
      switch (provider.type) {
        case 'ollama':
          await _log.log('使用Ollama调用');
          result = await _callOllama(messagesWithSystemPrompt, config, provider);
          break;
        case 'claude':
          await _log.log('使用Claude调用');
          result = await _callClaude(messagesWithSystemPrompt, config, provider);
          break;
        case 'gemini':
          await _log.log('使用Gemini调用');
          result = await _callGemini(messagesWithSystemPrompt, config, provider);
          break;
        case 'openai':
          await _log.log('使用OpenAI调用');
          result = await _callOpenAI(messagesWithSystemPrompt, config, provider);
          break;
        default:
          await _log.log('使用默认OpenAI调用');
          result = await _callOpenAI(messagesWithSystemPrompt, config, provider);
      }
      
      stopwatch.stop();
      await _log.apiResponse(provider.type, result, durationMs: stopwatch.elapsedMilliseconds);
      return result;
      
    } catch (e, stackTrace) {
      stopwatch.stop();
      await _log.apiError(provider.type, e.toString(), request: messages.last.content.substring(0, messages.last.content.length > 100 ? 100 : messages.last.content.length));
      await _log.error('LLM调用失败', e, stackTrace);
      rethrow;
    }
  }

  static Future<String> _callOpenAI(
    List<LLMMessage> messages,
    AIConfig config,
    ProviderConfig provider,
  ) async {
    final url = Uri.parse('${provider.baseUrl}/chat/completions');
    final response = await _postWithRetry(
      url,
      {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${provider.apiKey}',
      },
      jsonEncode({
        'model': config.currentModel,
        'messages': messages.map((m) => m.toJson()).toList(),
        'temperature': 0.7,
      }),
      maxRetries: 3,
      timeout: Duration(seconds: config.timeoutSeconds),
    );

    if (response.statusCode != 200) {
      throw Exception('API请求失败: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('API返回数据格式错误: 无choices');
    }
    final message = choices[0]['message'];
    if (message == null) {
      throw Exception('API返回数据格式错误: 无message');
    }
    final content = message['content'] as String?;
    if (content == null || content.isEmpty) {
      throw Exception('API返回数据格式错误: 无content');
    }
    return content;
  }

  static Future<String> _callOllama(
    List<LLMMessage> messages,
    AIConfig config,
    ProviderConfig provider,
  ) async {
    final url = Uri.parse('${provider.baseUrl}/api/chat');
    
    await _log.log('Ollama请求: url=$url, model=${config.currentModel}');
    
    final requestBody = {
      'model': config.currentModel,
      'messages': messages.map((m) => m.toJson()).toList(),
      'stream': false,
    };
    
    await _log.log('Ollama请求体: ${jsonEncode(requestBody)}');
    
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    ).timeout(const Duration(minutes: 10), onTimeout: () async {
      final error = 'Ollama请求超时(10分钟)';
      await _log.error(error);
      throw Exception('$error，请检查：\n1. Ollama服务是否已启动\n2. 模型是否已下载\n3. 本地模型生成较慢，请耐心等待或选择更快的模型');
    });

    final responsePreview = response.body.length > 500 ? '${response.body.substring(0, 500)}...' : response.body;
    await _log.log('Ollama响应: status=${response.statusCode}, body=$responsePreview');

    if (response.statusCode != 200) {
      final error = 'Ollama请求失败: status=${response.statusCode}, body=${response.body}';
      await _log.error(error);
      throw Exception(error);
    }

    try {
      final data = jsonDecode(response.body);
      final message = data['message'] as Map<String, dynamic>?;
      if (message == null) {
        throw Exception('Ollama返回数据格式错误: 无message字段');
      }
      
      String? content = message['content'] as String?;
      
      if (content == null || content.isEmpty) {
        content = message['thinking'] as String?;
      }
      
      if (content == null || content.isEmpty) {
        throw Exception('Ollama返回空内容');
      }
      await _log.log('Ollama返回内容长度: ${content.length}字符');
      return content;
    } catch (e, stackTrace) {
      await _log.error('解析Ollama响应失败', e, stackTrace);
      throw Exception('解析Ollama响应失败: $e\n响应内容: ${response.body.substring(0, 200)}');
    }
  }

  static Future<String> _callClaude(
    List<LLMMessage> messages,
    AIConfig config,
    ProviderConfig provider,
  ) async {
    String baseUrl = provider.baseUrl;
    if (baseUrl.endsWith('/v1')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 3);
    }
    final url = Uri.parse('$baseUrl/v1/messages');
    
    String? systemPrompt;
    List<Map<String, dynamic>> chatMessages = [];
    
    for (final msg in messages) {
      if (msg.role == 'system') {
        systemPrompt = msg.content;
      } else {
        chatMessages.add(msg.toJson());
      }
    }
    
    final requestBody = <String, dynamic>{
      'model': config.currentModel,
      'messages': chatMessages,
      'max_tokens': 4096,
      'temperature': 0.7,
    };
    
    if (systemPrompt != null) {
      requestBody['system'] = systemPrompt;
    }
    
    final response = await _postWithRetry(
      url,
      {
        'Content-Type': 'application/json',
        'x-api-key': provider.apiKey,
        'anthropic-version': '2023-06-01',
      },
      jsonEncode(requestBody),
      maxRetries: 3,
      timeout: Duration(seconds: config.timeoutSeconds),
    );

    if (response.statusCode != 200) {
      throw Exception('Claude请求失败: ${response.body}');
    }

    final data = jsonDecode(response.body);
    await _log.log('Claude响应数据: ${jsonEncode(data)}');
    
    var contentList = data['content'] as List?;
    
    if (contentList == null || contentList.isEmpty) {
      if (data['choices'] != null) {
        final choices = data['choices'] as List;
        if (choices.isNotEmpty) {
          final message = choices[0]['message'];
          if (message != null) {
            final content = message['content'] as String?;
            if (content != null && content.isNotEmpty) {
              return content;
            }
          }
        }
      }
      throw Exception('Claude返回数据格式错误: 无content, 响应: ${response.body}');
    }
    
    String? text;
    for (final item in contentList) {
      if (item is Map && item['type'] == 'text') {
        text = item['text'] as String?;
        if (text != null && text.isNotEmpty) {
          break;
        }
      }
    }
    
    if (text == null || text.isEmpty) {
      text = contentList[0]['text'] as String?;
    }
    
    if (text == null || text.isEmpty) {
      throw Exception('Claude返回数据格式错误: 无text, content: ${jsonEncode(contentList)}');
    }
    return text;
  }

  static Future<String> _callGemini(
    List<LLMMessage> messages,
    AIConfig config,
    ProviderConfig provider,
  ) async {
    final url = Uri.parse(
      '${provider.baseUrl}/models/${config.currentModel}:generateContent?key=${provider.apiKey}',
    );

    final content = messages.map((m) => {
      'role': m.role == 'user' ? 'user' : 'model',
      'parts': [{'text': m.content}],
    }).toList();

    final response = await _postWithRetry(
      url,
      {'Content-Type': 'application/json'},
      jsonEncode({
        'contents': content,
        'generationConfig': {
          'temperature': 0.7,
        },
      }),
      maxRetries: 3,
      timeout: Duration(seconds: config.timeoutSeconds),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini请求失败: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini返回数据格式错误: 无candidates');
    }
    final contentData = candidates[0]['content'];
    if (contentData == null) {
      throw Exception('Gemini返回数据格式错误: 无content');
    }
    final parts = contentData['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini返回数据格式错误: 无parts');
    }
    final text = parts[0]['text'] as String?;
    if (text == null || text.isEmpty) {
      throw Exception('Gemini返回数据格式错误: 无text');
    }
    return text;
  }

  static Future<bool> testConnection(AIConfig config) async {
    try {
      final provider = config.providers[config.currentProvider];
      if (provider == null) {
        return false;
      }

      final messages = [
        LLMMessage(role: 'user', content: 'Hi'),
      ];

      switch (provider.type) {
        case 'ollama':
          await _callOllama(messages, config, provider);
          break;
        case 'claude':
          await _callClaude(messages, config, provider);
          break;
        case 'gemini':
          await _callGemini(messages, config, provider);
          break;
        default:
          await _callOpenAI(messages, config, provider);
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
