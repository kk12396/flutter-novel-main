import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/ai_config.dart';
import '../services/storage_service.dart';
import '../services/ai_config_service.dart';
import '../services/llm_service.dart';
import '../services/theme_service.dart';
import '../services/settings_service.dart';
import '../constants/prompt_templates.dart';
import 'llm_config_page.dart';
import 'start_page.dart';
import 'settings_page.dart';

class SimplifiedNovelPage extends StatefulWidget {
  final String? loadProjectName;

  const SimplifiedNovelPage({
    super.key,
    this.loadProjectName,
  });

  @override
  State<SimplifiedNovelPage> createState() => _SimplifiedNovelPageState();
}

class _SimplifiedNovelPageState extends State<SimplifiedNovelPage>
    with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  final AIConfigService _aiConfigService = AIConfigService();
  final TextEditingController _outlinePromptController = TextEditingController();
  final TextEditingController _outlineEditController = TextEditingController();
  final TextEditingController _volumePlanningEditController = TextEditingController();  // 分卷规划（整本书）
  final TextEditingController _scopePlanningEditController = TextEditingController();  // 范围规划（每卷）
  final TextEditingController _planningStartController = TextEditingController(text: '1');
  final TextEditingController _planningCountController = TextEditingController(text: '10');
  final TextEditingController _generationChapterController = TextEditingController(text: '1');

  List<String> _projects = [];
  String? _currentBook;
  Project? _currentProject;
  AIConfig? _aiConfig;
  String _selectedVolume = '1';
  int _selectedTab = 0;
  bool _isLoading = false;
  String? _generatedChapterContent;
  int? _generatedChapterNumber;
  String? _generatedProgressTracking; // 生成的进度追踪内容
  
  // 自动续写相关
  bool _isAutoContinuing = false;
  bool _shouldStopAutoContinue = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);  // 5个Tab：大纲、分卷规划、范围规划、章节规划、生成章节
    _tabController.addListener(() {
      setState(() {
        _selectedTab = _tabController.index;
      });
    });
    // 延迟初始化，避免阻塞UI渲染
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _outlinePromptController.dispose();
    _outlineEditController.dispose();
    _volumePlanningEditController.dispose();
    _scopePlanningEditController.dispose();
    _planningStartController.dispose();
    _planningCountController.dispose();
    _generationChapterController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    
    try {
      await _storage.init();
      await _refreshProjects();
      _aiConfig = await _aiConfigService.getConfig();

      // 如果有指定加载的项目
      if (widget.loadProjectName != null) {
        if (_projects.contains(widget.loadProjectName)) {
          await _loadProject(widget.loadProjectName!);
        }
      }
      // 否则加载上次选中的项目
      else {
        final selected = await _storage.getSelectedProject();
        if (selected != null && _projects.contains(selected)) {
          await _loadProject(selected);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createProjectFromConfig(Map<String, dynamic> config) async {
    final bookName = config['bookName'] as String;
    final genre = config['genre'] as String;
    final theme = config['theme'] as String;
    final setting = config['setting'] as String;
    final plotHook = config['plotHook'] as String;

    // 如果项目已存在，添加数字后缀
    String projectName = bookName;
    int suffix = 1;
    while (_projects.contains(projectName)) {
      projectName = '$bookName($suffix)';
      suffix++;
    }

    // 构建大纲提示词
    final prompt = '''请创作一部$genre小说。

主题：$theme
背景设定：$setting
开篇钩子：$plotHook

请生成完整的小说大纲，包含基础信息、故事框架、世界观设定、角色设定、关键道具和分卷规划。''';    final project = Project(
      name: projectName,
      outline: '',
    );

    await _storage.saveProject(project);
    await _refreshProjects();

    setState(() {
      _currentBook = projectName;
      _currentProject = project;
      _outlinePromptController.text = prompt;
    });

    await _storage.saveSelectedProject(projectName);

    // 自动开始生成大纲
    if (mounted) {
      _showMessage('项目已创建，正在生成大纲...');
      await _generateOutline();
    }
  }

  Future<void> _refreshProjects() async {
    final projects = await _storage.listProjects();
    setState(() {
      _projects = projects;
    });
  }

  Future<void> _loadProject(String name) async {
    final project = await _storage.loadProject(name);
    if (project != null) {
      setState(() {
        _currentBook = name;
        _currentProject = project;
        _outlineEditController.text = project.outline;
        
        // 加载分卷规划 - 将Map转换为文本格式
        if (project.volumePlanning.isNotEmpty) {
          final planningContent = project.volumePlanning.entries
              .map((e) => '===第${e.key}卷===\n${e.value}')
              .join('\n\n');
          _volumePlanningEditController.text = planningContent;
        } else {
          _volumePlanningEditController.text = '';
        }
        
        // 加载范围规划
        if (project.scopePlanning[_selectedVolume] != null) {
          _scopePlanningEditController.text = project.scopePlanning[_selectedVolume]!;
        } else {
          _scopePlanningEditController.clear();
        }
      });
      await _storage.saveSelectedProject(name);
    }
  }

  Future<void> _generateOutline() async {
    final prompt = _outlinePromptController.text.trim();
    if (prompt.isEmpty) {
      _showMessage('请输入小说基本信息');
      return;
    }

    if (_aiConfig == null) {
      _showMessage('请先配置LLM服务');
      return;
    }

    final provider = _aiConfig!.providers[_aiConfig!.currentProvider];
    if (provider == null) {
      _showMessage('请先配置LLM服务');
      return;
    }
    
    // Ollama不需要API Key
    if (provider.type != 'ollama' && provider.apiKey.isEmpty) {
      _showMessage('请先配置API Key');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final messages = [
        LLMMessage(role: 'system', content: PromptTemplates.outline),
        LLMMessage(role: 'user', content: prompt),
      ];

      final result = await LLMService.callLLMWithConfig(messages, _aiConfig!);
      final cleaned = _cleanGeneratedContent(result);
      
      setState(() {
        _outlineEditController.text = cleaned;
      });

      // 同时更新项目数据
      if (_currentProject != null) {
        final updatedProject = _currentProject!.copyWith(
          outline: cleaned,
        );
        await _storage.saveProject(updatedProject);
        setState(() {
          _currentProject = updatedProject;
        });
      }

      _showMessage('大纲生成成功');
    } catch (e) {
      _showMessage('生成大纲失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _cleanGeneratedContent(String content) {
    String cleaned = content;
    cleaned = cleaned.replaceAll(RegExp(r'<思考>[\s\S]*?</思考>'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[思考\][\s\S]*?\[/思考\]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[.*?\]'), '');
    return cleaned.trim();
  }

  Future<void> _saveOutline() async {
    if (_currentProject == null) return;

    final updated = _currentProject!.copyWith(
      outline: _outlineEditController.text,
    );
    await _storage.saveProject(updated);
    setState(() => _currentProject = updated);
    _showMessage('大纲已保存');
  }

  // 生成分卷规划（整本书）
  Future<void> _generateVolumePlanning() async {
    if (_currentProject == null || _currentProject!.outline.isEmpty) {
      _showMessage('请先生成大纲');
      return;
    }

    if (_aiConfig == null) {
      _showMessage('请先配置LLM服务');
      return;
    }

    final provider = _aiConfig!.providers[_aiConfig!.currentProvider];
    if (provider == null) {
      _showMessage('请先配置LLM服务');
      return;
    }

    // Ollama不需要API Key
    if (provider.type != 'ollama' && provider.apiKey.isEmpty) {
      _showMessage('请先配置API Key');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final systemPrompt = PromptTemplates.bookVolumePlanning;
      
      final outlineContent = _currentProject!.outline;

      final userPrompt = '''请为《${_currentProject!.name}》生成完整的分卷规划。

基于以下大纲内容：

$outlineContent

请生成包含5卷的分卷规划，每卷120章。确保各卷之间有清晰的递进关系，伏笔贯穿始终。''';

      final messages = [
        LLMMessage(role: 'system', content: systemPrompt),
        LLMMessage(role: 'user', content: userPrompt),
      ];

      final result = await LLMService.callLLMWithConfig(messages, _aiConfig!);
      final cleaned = _cleanGeneratedContent(result);

      // 解析分卷规划内容并保存到项目
      final volumePlanningMap = _parseVolumePlanning(cleaned);
      
      final updatedProject = _currentProject!.copyWith(
        volumePlanning: volumePlanningMap,
      );
      await _storage.saveProject(updatedProject);
      setState(() {
        _currentProject = updatedProject;
        _volumePlanningEditController.text = cleaned;
      });
      
      _showMessage('分卷规划已生成并保存');
    } catch (e) {
      _showMessage('生成分卷规划失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 解析分卷规划文本为Map
  Map<String, String> _parseVolumePlanning(String content) {
    final Map<String, String> result = {};
    
    // 尝试匹配 "第X卷" 或 "===第X卷===" 格式，兼容各种空格格式
    final regex = RegExp(r'(?:===\s*)?第\s*(\d+)\s*卷(?:\s*===)?[：:\s]*([\s\S]*?)(?=(?:===\s*)?第\s*\d+\s*卷(?:\s*===)?|$)', caseSensitive: false);
    final matches = regex.allMatches(content);
    
    for (final match in matches) {
      final volumeNum = match.group(1);
      final volumeContent = match.group(2)?.trim();
      if (volumeNum != null && volumeContent != null && volumeContent.isNotEmpty) {
        result[volumeNum] = volumeContent;
      }
    }
    
    // 如果没有匹配到格式，将整个内容作为第1卷
    if (result.isEmpty && content.isNotEmpty) {
      result['1'] = content;
    }
    
    return result;
  }

  // 生成范围规划（每卷的详细规划）
  Future<void> _generateScopePlanning() async {
    if (_currentProject == null) {
      _showMessage('请先选择项目');
      return;
    }

    if (_currentProject!.volumePlanning.isEmpty) {
      _showMessage('请先生成分卷规划');
      return;
    }

    if (_aiConfig == null) {
      _showMessage('请先配置LLM服务');
      return;
    }

    final provider = _aiConfig!.providers[_aiConfig!.currentProvider];
    if (provider == null) {
      _showMessage('请先配置LLM服务');
      return;
    }

    // Ollama不需要API Key
    if (provider.type != 'ollama' && provider.apiKey.isEmpty) {
      _showMessage('请先配置API Key');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final volumeNumber = int.parse(_selectedVolume);
      final volumeStartChapter = (volumeNumber - 1) * 120 + 1;
      final volumeEndChapter = volumeNumber * 120;

      String systemPrompt = PromptTemplates.scopePlanning;
      systemPrompt = systemPrompt.replaceAll('{startChapter}', volumeStartChapter.toString());
      systemPrompt = systemPrompt.replaceAll('{endChapter}', volumeEndChapter.toString());

      final outlineContent = _currentProject!.outline;

      final userPrompt = '''请为《${_currentProject!.name}》生成第$volumeNumber卷（第$volumeStartChapter-$volumeEndChapter章）的详细范围规划。

【大纲内容】
$outlineContent

【分卷规划】
${_currentProject!.volumePlanning[_selectedVolume] ?? '暂无分卷规划'}

【任务要求】
请基于以上大纲和分卷规划，专注于第$volumeNumber卷（第$volumeStartChapter-$volumeEndChapter章）生成详细的范围规划。
要求：
1. 严格遵循大纲中的世界观、角色设定和主线脉络
2. 结合分卷规划中对该卷的定位和核心脉络
3. 每10章为一个段落，描述该段落的核心事件和发展
4. 确保与前后卷的衔接顺畅，伏笔得到呼应''';

      final messages = [
        LLMMessage(role: 'system', content: systemPrompt),
        LLMMessage(role: 'user', content: userPrompt),
      ];

      final result = await LLMService.callLLMWithConfig(messages, _aiConfig!);
      final cleaned = _cleanGeneratedContent(result);

      // 自动保存范围规划
      final updatedScopePlanning = Map<String, String>.from(_currentProject!.scopePlanning);
      updatedScopePlanning[_selectedVolume.toString()] = cleaned;
      
      final updatedProject = _currentProject!.copyWith(
        scopePlanning: updatedScopePlanning,
      );
      await _storage.saveProject(updatedProject);
      
      setState(() {
        _currentProject = updatedProject;
        _scopePlanningEditController.text = cleaned;
      });
      
      _showMessage('范围规划已生成并保存');
    } catch (e) {
      _showMessage('生成范围规划失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 保存分卷规划（整本书）
  Future<void> _saveVolumePlanning() async {
    if (_currentProject == null) return;

    // 解析分卷规划内容
    final volumePlanningMap = _parseVolumePlanning(_volumePlanningEditController.text);
    
    final updated = _currentProject!.copyWith(
      volumePlanning: volumePlanningMap,
    );
    await _storage.saveProject(updated);
    setState(() => _currentProject = updated);
    _showMessage('分卷规划已保存');
  }

  // 保存范围规划（每卷）
  Future<void> _saveScopePlanning() async {
    if (_currentProject == null) return;

    final updatedScopePlanning = Map<String, String>.from(_currentProject!.scopePlanning);
    updatedScopePlanning[_selectedVolume] = _scopePlanningEditController.text;

    final updated = _currentProject!.copyWith(
      scopePlanning: updatedScopePlanning,
    );
    await _storage.saveProject(updated);
    setState(() => _currentProject = updated);
    _showMessage('范围规划已保存');
  }

  Future<void> _generateChapterPlanning() async {
    if (_currentProject == null || _currentProject!.outline.isEmpty) {
      _showMessage('请先生成大纲');
      return;
    }

    if (_aiConfig == null) {
      _showMessage('请先配置LLM服务');
      return;
    }

    final provider = _aiConfig!.providers[_aiConfig!.currentProvider];
    if (provider == null) {
      _showMessage('请先配置LLM服务');
      return;
    }

    // Ollama不需要API Key
    if (provider.type != 'ollama' && provider.apiKey.isEmpty) {
      _showMessage('请先配置API Key');
      return;
    }

    final startChapter = int.tryParse(_planningStartController.text) ?? 1;
    // 根据模型类型决定生成章节数：本地模型5章，在线模型10章
    final isLocalModel = provider.type == 'ollama' || provider.type == 'local';
    final chapterCount = isLocalModel ? 5 : 10;

    setState(() => _isLoading = true);

    try {
      final volumeNumber = (startChapter / 120).ceil();

      final outlineContent = _currentProject!.outline;

      final systemPrompt = PromptTemplates.chapterPlanning
          .replaceAll('{chapterCount}', chapterCount.toString());

      final userPrompt = '''请为《${_currentProject!.name}》生成第$startChapter章到第${startChapter + chapterCount - 1}章的章节规划。

【大纲内容】
$outlineContent

【范围规划】
${_currentProject!.scopePlanning[volumeNumber.toString()] ?? '暂无范围规划'}

请严格按照SKILL.md格式，生成$chapterCount章的详细规划。''';

      final messages = [
        LLMMessage(role: 'system', content: systemPrompt),
        LLMMessage(role: 'user', content: userPrompt),
      ];

      final result = await LLMService.callLLMWithConfig(messages, _aiConfig!);
      final cleaned = _cleanGeneratedContent(result);

      // 解析章节规划，按"第X章"分割
      final chapters = _parseChapterPlanning(cleaned, startChapter, chapterCount);
      final updatedPlanning = Map<String, String>.from(_currentProject!.chapterPlanning);
      updatedPlanning.addAll(chapters);

      final updated = _currentProject!.copyWith(
        chapterPlanning: updatedPlanning,
      );
      await _storage.saveProject(updated);
      setState(() => _currentProject = updated);
      _showMessage('章节规划生成成功：${chapters.length}章');
    } catch (e) {
      _showMessage('生成章节规划失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 解析章节规划内容，按"第X章"匹配分割
  Map<String, String> _parseChapterPlanning(String content, int startChapter, int maxChapters) {
    final chapters = <String, String>{};
    // 使用正则匹配"第X章"，支持多种格式：第1章、第 1 章、第1章等
    final regex = RegExp(r'第\s*(\d+)\s*章', multiLine: true);
    final matches = regex.allMatches(content).toList();

    for (int i = 0; i < matches.length && chapters.length < maxChapters; i++) {
      final match = matches[i];
      final startIndex = match.start;
      final endIndex = (i < matches.length - 1) ? matches[i + 1].start : content.length;
      
      // 提取章节内容（从"第X章"开始到下一个"第X章"之前）
      var chapterContent = content.substring(startIndex, endIndex).trim();
      
      // 移除分隔符（如果有的话）
      chapterContent = chapterContent.replaceAll('---CHAPTER_SEPARATOR---', '').trim();
      
      if (chapterContent.isNotEmpty) {
        // 计算实际章节号（基于起始章节）
        final actualChapterNum = startChapter + chapters.length;
        chapters[actualChapterNum.toString()] = chapterContent;
      }
    }

    return chapters;
  }

  Future<void> _continueChapterPlanning() async {
    if (_currentProject == null) return;

    final lastChapter = _currentProject!.chapterPlanning.keys
        .map((k) => int.tryParse(k) ?? 0)
        .fold(0, (max, v) => v > max ? v : max);

    final startChapter = lastChapter + 1;

    if (_aiConfig == null) {
      _showMessage('请先配置LLM服务');
      return;
    }

    final provider = _aiConfig!.providers[_aiConfig!.currentProvider];
    if (provider == null) {
      _showMessage('请先配置LLM服务');
      return;
    }

    // Ollama不需要API Key
    if (provider.type != 'ollama' && provider.apiKey.isEmpty) {
      _showMessage('请先配置API Key');
      return;
    }

    // 根据模型类型决定生成章节数：本地模型5章，在线模型10章
    final isLocalModel = provider.type == 'ollama' || provider.type == 'local';
    final chapterCount = isLocalModel ? 5 : 10;

    setState(() => _isLoading = true);

    try {
      final volumeNumber = (startChapter / 120).ceil();

      // 优先使用精简大纲，如果没有则使用写作大纲
      final outlineContent = _currentProject!.outline;

      final systemPrompt = PromptTemplates.chapterPlanning
          .replaceAll('{chapterCount}', chapterCount.toString());

      final userPrompt = '''请为《${_currentProject!.name}》生成第$startChapter章到第${startChapter + chapterCount - 1}章的章节规划。

【大纲内容】
$outlineContent

【范围规划】
${_currentProject!.scopePlanning[volumeNumber.toString()] ?? '暂无范围规划'}

请严格按照SKILL.md格式，生成$chapterCount章的详细规划。''';

      final messages = [
        LLMMessage(role: 'system', content: systemPrompt),
        LLMMessage(role: 'user', content: userPrompt),
      ];

      final result = await LLMService.callLLMWithConfig(messages, _aiConfig!);
      final cleaned = _cleanGeneratedContent(result);

      // 解析章节规划，按"第X章"分割
      final chapters = _parseChapterPlanning(cleaned, startChapter, chapterCount);
      final updatedPlanning = Map<String, String>.from(_currentProject!.chapterPlanning);
      updatedPlanning.addAll(chapters);

      final updated = _currentProject!.copyWith(
        chapterPlanning: updatedPlanning,
      );
      await _storage.saveProject(updated);
      setState(() => _currentProject = updated);
      _showMessage('章节规划生成成功：${chapters.length}章');
    } catch (e) {
      _showMessage('生成章节规划失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateChapter() async {
    if (_currentProject == null || _currentProject!.outline.isEmpty) {
      _showMessage('请先生成大纲');
      return;
    }

    if (_aiConfig == null) {
      _showMessage('请先配置LLM服务');
      return;
    }

    final provider = _aiConfig!.providers[_aiConfig!.currentProvider];
    if (provider == null) {
      _showMessage('请先配置LLM服务');
      return;
    }

    // Ollama不需要API Key
    if (provider.type != 'ollama' && provider.apiKey.isEmpty) {
      _showMessage('请先配置API Key');
      return;
    }

    final chapterNumber = int.tryParse(_generationChapterController.text) ?? 1;

    setState(() => _isLoading = true);

    try {
      final volumeNumber = (chapterNumber / 120).ceil();
      final chapterPlanning = _currentProject!.chapterPlanning[chapterNumber.toString()] ?? '';
      final volumePlanning = _currentProject!.volumePlanning[volumeNumber.toString()] ?? '';
      final currentProgressTracking = _currentProject!.progressTracking ?? '暂无进度追踪';

      // 优先使用精简大纲，如果没有则使用写作大纲
      final outlineContent = _currentProject!.outline;

      final userPrompt = '''目标书名：《${_currentProject!.name}》
目标分卷编号：第$volumeNumber卷
目标章节编号：第$chapterNumber章

精简大纲：
$outlineContent

分卷规划：
$volumePlanning

章节规划：
$chapterPlanning

进度追踪（必须参考，确保时间线、场景、角色状态一致）：
$currentProgressTracking

请生成第$chapterNumber章的完整内容，约2500字。

重要：生成后必须输出进度追踪更新，记录本章发生的变化。''';

      String systemPrompt = PromptTemplates.chapterGeneration;
      systemPrompt = systemPrompt.replaceAll('{chapterNumber}', chapterNumber.toString());

      final messages = [
        LLMMessage(role: 'user', content: systemPrompt + '\n\n' + userPrompt),
      ];

      final result = await LLMService.callLLMForChapter(messages, _aiConfig!);
      final cleaned = _cleanGeneratedContent(result);

      // 解析章节内容和进度追踪
      String chapterContent;
      String? newProgressTracking;
      
      // 标准化格式标记（移除可能的Markdown加粗符号）
      var normalized = cleaned.replaceAll(RegExp(r'\*\*'), '');
      
      // 检查各种可能的格式标记
      final hasContentMarker = normalized.contains('===章节内容===') || normalized.contains('【章节内容】');
      final hasProgressMarker = normalized.contains('===进度追踪更新===') || 
                                 normalized.contains('【进度追踪更新】') ||
                                 normalized.contains('===进度追踪===') ||
                                 normalized.contains('【进度追踪】') ||
                                 normalized.contains('### 章节进度追踪') ||
                                 normalized.contains('章节进度追踪');
      
      if (hasContentMarker && hasProgressMarker) {
        // 标准格式：提取章节内容和进度追踪
        final contentMatch = RegExp(r'(?:===|【)章节内容(?:===|】)\s*\n?([\s\S]*?)(?=\n?(?:===|【|###)(?:进度追踪更新|进度追踪|章节进度追踪)(?:===|】)?)', caseSensitive: false).firstMatch(normalized);
        final progressMatch = RegExp(r'(?:===|【|###)\s*(?:进度追踪更新|进度追踪|章节进度追踪)\s*(?:===|】)?\s*\n?([\s\S]*?)$', caseSensitive: false).firstMatch(normalized);
        
        chapterContent = contentMatch?.group(1)?.trim() ?? cleaned;
        newProgressTracking = progressMatch?.group(1)?.trim();
      } else if (hasProgressMarker) {
        // 只有进度追踪标记，尝试分割
        final parts = normalized.split(RegExp(r'(?:===|【|###)\s*(?:进度追踪更新|进度追踪|章节进度追踪)\s*(?:===|】)?', caseSensitive: false));
        chapterContent = parts[0].trim();
        newProgressTracking = parts.length > 1 ? parts[1].trim() : null;
      } else {
        // 无格式标记，全部作为章节内容
        chapterContent = cleaned;
        newProgressTracking = null;
      }

      // 确保章节内容不为空
      if (chapterContent.isEmpty) {
        chapterContent = cleaned;
      }

      setState(() {
        _generatedChapterContent = chapterContent;
        _generatedChapterNumber = chapterNumber;
        _generatedProgressTracking = newProgressTracking;
      });

      // 调试信息
      if (newProgressTracking == null || newProgressTracking.isEmpty) {
        _showMessage('警告：未解析到进度追踪，请检查LLM输出格式');
      }

      // 自动生成后自动保存
      await _autoSaveChapter(chapterNumber, chapterContent, newProgressTracking);
      
    } catch (e) {
      _showMessage('生成章节失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 自动保存章节（用于自动生成后自动保存）
  Future<void> _autoSaveChapter(int chapterNumber, String chapterContent, String? progressTracking) async {
    if (_currentProject == null) return;

    final chapterNumberStr = chapterNumber.toString();
    final existingIndex = _currentProject!.chapters.indexWhere((c) => c.chapter == chapterNumber);

    final now = DateTime.now().toIso8601String();
    List<Chapter> updatedChapters = List.from(_currentProject!.chapters);
    final updatedGeneratedChapters = Map<String, String>.from(_currentProject!.generatedChapters);

    if (existingIndex >= 0) {
      // 更新已有章节
      final existing = updatedChapters[existingIndex];
      updatedChapters[existingIndex] = Chapter(
        chapter: chapterNumber,
        content: chapterContent,
        wordCount: chapterContent.length,
        createdAt: existing.createdAt,
        updatedAt: now,
      );
    } else {
      // 新建章节
      updatedChapters.add(Chapter(
        chapter: chapterNumber,
        content: chapterContent,
        wordCount: chapterContent.length,
        createdAt: now,
      ));
    }
    updatedGeneratedChapters[chapterNumberStr] = chapterContent;

    // 更新进度追踪（如果有）
    String? updatedProgressTracking = _currentProject!.progressTracking;
    if (progressTracking != null && progressTracking.isNotEmpty) {
      updatedProgressTracking = progressTracking;
    }

    final updated = _currentProject!.copyWith(
      chapters: updatedChapters,
      generatedChapters: updatedGeneratedChapters,
      progressTracking: updatedProgressTracking,
    );
    await _storage.saveProject(updated);
    setState(() => _currentProject = updated);
    
    final progressMsg = progressTracking != null ? '，进度追踪已更新' : '';
    _showMessage('第${chapterNumber}章已自动生成并保存$progressMsg');
  }

  Future<void> _saveChapter() async {
    if (_currentProject == null || _generatedChapterContent == null) return;

    final chapterNumber = _generatedChapterNumber!;
    final chapterNumberStr = chapterNumber.toString();
    final existingIndex = _currentProject!.chapters.indexWhere((c) => c.chapter == chapterNumber);

    final now = DateTime.now().toIso8601String();
    List<Chapter> updatedChapters = List.from(_currentProject!.chapters);
    
    // 更新generatedChapters Map（用于保存到文件）
    final updatedGeneratedChapters = Map<String, String>.from(_currentProject!.generatedChapters);

    if (existingIndex >= 0) {
      // 追加模式：在原有内容后添加新内容
      final existing = updatedChapters[existingIndex];
      final newContent = '${existing.content}\n\n$_generatedChapterContent';
      updatedChapters[existingIndex] = Chapter(
        chapter: chapterNumber,
        content: newContent,
        wordCount: newContent.length,
        createdAt: existing.createdAt,
        updatedAt: now,
      );
      updatedGeneratedChapters[chapterNumberStr] = newContent;
    } else {
      // 新建模式
      updatedChapters.add(Chapter(
        chapter: chapterNumber,
        content: _generatedChapterContent!,
        wordCount: _generatedChapterContent!.length,
        createdAt: now,
      ));
      updatedGeneratedChapters[chapterNumberStr] = _generatedChapterContent!;
    }

    // 保存进度追踪（如果有）
    String? updatedProgressTracking = _currentProject!.progressTracking;
    if (_generatedProgressTracking != null && _generatedProgressTracking!.isNotEmpty) {
      updatedProgressTracking = _generatedProgressTracking;
    }

    final updated = _currentProject!.copyWith(
      chapters: updatedChapters,
      generatedChapters: updatedGeneratedChapters,
      progressTracking: updatedProgressTracking,
    );
    await _storage.saveProject(updated);
    setState(() => _currentProject = updated);
    
    final progressMsg = _generatedProgressTracking != null ? '，进度追踪已更新' : '';
    _showMessage('章节已保存到 正文/第${chapterNumber}章.txt$progressMsg');
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  /// 润色章节
  Future<void> _polishChapter(int chapterNumber, String polishType) async {
    if (_currentProject == null) return;

    // 查找章节内容
    final chapter = _currentProject!.chapters.firstWhere(
      (c) => c.chapter == chapterNumber,
      orElse: () => Chapter(chapter: chapterNumber, content: '', wordCount: 0, createdAt: DateTime.now().toIso8601String()),
    );

    if (chapter.content.isEmpty) {
      _showMessage('第${chapterNumber}章暂无内容，无法润色');
      return;
    }

    if (_aiConfig == null) {
      _showMessage('请先配置LLM服务');
      return;
    }

    final provider = _aiConfig!.providers[_aiConfig!.currentProvider];
    if (provider == null) {
      _showMessage('请先配置LLM服务');
      return;
    }

    // Ollama不需要API Key
    if (provider.type != 'ollama' && provider.apiKey.isEmpty) {
      _showMessage('请先配置API Key');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String systemPrompt = PromptTemplates.chapterPolish;
      systemPrompt = systemPrompt.replaceAll('{polishType}', polishType);

      final userPrompt = '''请对以下章节进行润色：

【章节信息】
书名：《${_currentProject!.name}》
章节：第${chapterNumber}章

【原文内容】
${chapter.content}

请按照${polishType}的要求进行润色，保持原有情节和字数范围。''';      final messages = [
        LLMMessage(role: 'system', content: systemPrompt),
        LLMMessage(role: 'user', content: userPrompt),
      ];

      final result = await LLMService.callLLMWithConfig(messages, _aiConfig!);
      final cleaned = _cleanGeneratedContent(result);

      // 解析润色后的内容
      final contentMatch = RegExp(r'===润色后内容===\n([\s\S]*?)(?====润色报告===|$)').firstMatch(cleaned);
      final polishedContent = contentMatch?.group(1)?.trim() ?? cleaned;

      // 自动保存润色后的内容
      final chapterNumberStr = chapterNumber.toString();
      final existingIndex = _currentProject!.chapters.indexWhere((c) => c.chapter == chapterNumber);

      final now = DateTime.now().toIso8601String();
      List<Chapter> updatedChapters = List.from(_currentProject!.chapters);
      final updatedGeneratedChapters = Map<String, String>.from(_currentProject!.generatedChapters);

      if (existingIndex >= 0) {
        updatedChapters[existingIndex] = Chapter(
          chapter: chapterNumber,
          content: polishedContent,
          wordCount: polishedContent.length,
          createdAt: updatedChapters[existingIndex].createdAt,
          updatedAt: now,
        );
      } else {
        updatedChapters.add(Chapter(
          chapter: chapterNumber,
          content: polishedContent,
          wordCount: polishedContent.length,
          createdAt: now,
        ));
      }
      updatedGeneratedChapters[chapterNumberStr] = polishedContent;

      final updated = _currentProject!.copyWith(
        chapters: updatedChapters,
        generatedChapters: updatedGeneratedChapters,
      );
      await _storage.saveProject(updated);

      setState(() {
        _currentProject = updated;
        _generatedChapterContent = polishedContent;
        _generatedChapterNumber = chapterNumber;
      });

      _showMessage('第${chapterNumber}章润色完成并已保存');
    } catch (e) {
      _showMessage('润色章节失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 显示润色选项对话框
  void _showPolishDialog(int chapterNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择润色强度'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('轻度润色'),
              subtitle: const Text('修正错别字、改善流畅度'),
              onTap: () {
                Navigator.pop(context);
                _polishChapter(chapterNumber, '轻度润色');
              },
            ),
            ListTile(
              title: const Text('中度润色'),
              subtitle: const Text('加强描写、深化角色、改进对话'),
              onTap: () {
                Navigator.pop(context);
                _polishChapter(chapterNumber, '中度润色');
              },
            ),
            ListTile(
              title: const Text('重度润色'),
              subtitle: const Text('重组段落、扩展发展、增强细节'),
              onTap: () {
                Navigator.pop(context);
                _polishChapter(chapterNumber, '重度润色');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 智能续写：自动分析项目状态，确定下一步动作并执行（支持循环模式）
  Future<void> _autoContinue() async {
    if (_currentProject == null) {
      _showMessage('请先选择或创建项目');
      return;
    }

    if (_aiConfig == null) {
      _showMessage('请先配置LLM服务');
      return;
    }

    // 如果已经在自动续写中，则停止
    if (_isAutoContinuing) {
      setState(() => _shouldStopAutoContinue = true);
      _showMessage('正在停止自动续写...');
      return;
    }

    // 开始自动续写循环
    setState(() {
      _isAutoContinuing = true;
      _shouldStopAutoContinue = false;
    });

    _showMessage('自动续写已启动，点击按钮停止');

    int cycleCount = 0;
    while (!_shouldStopAutoContinue) {
      cycleCount++;
      
      try {
        // 根据模型类型决定生成章节数：本地模型5章，在线模型10章
        final provider = _aiConfig!.providers[_aiConfig!.currentProvider];
        final isLocalModel = provider?.type == 'ollama' || provider?.type == 'local';
        final chapterBatchSize = isLocalModel ? 5 : 10;

        setState(() => _isLoading = true);

        // 1. 检查写作大纲
        if (_currentProject!.outline.isEmpty) {
          _showMessage('智能续写[$cycleCount]：开始生成大纲...');
          await _generateOutline();
          await _randomDelay();
          continue;
        }

        // 2. 检查分卷规划
        if (_currentProject!.volumePlanning.isEmpty) {
          _showMessage('智能续写[$cycleCount]：开始生成分卷规划...');
          await _generateVolumePlanning();
          await _randomDelay();
          continue;
        }

        // 3. 找到第一个未完成的卷（范围规划、章节规划、正文）
        String? incompleteVolume;
        for (var vol = 1; vol <= 5; vol++) {
          final volStr = vol.toString();
          final volStartChapter = (vol - 1) * 120 + 1;
          final volEndChapter = vol * 120;
          
          // 检查该卷的范围规划
          if (_currentProject!.scopePlanning[volStr]?.isEmpty ?? true) {
            incompleteVolume = volStr;
            break;
          }
          
          // 检查该卷的章节规划
          final volChapters = _currentProject!.chapterPlanning.entries
              .where((e) {
                final chapterNum = int.tryParse(e.key) ?? 0;
                return chapterNum >= volStartChapter && chapterNum <= volEndChapter;
              })
              .toList();
          if (volChapters.length < 120) {
            incompleteVolume = volStr;
            break;
          }
          
          // 检查该卷的正文
          final volGeneratedChapters = _currentProject!.chapters
              .where((c) => c.chapter >= volStartChapter && c.chapter <= volEndChapter)
              .toList();
          if (volGeneratedChapters.length < 120) {
            incompleteVolume = volStr;
            break;
          }
        }
        
        if (incompleteVolume == null) {
          _showMessage('所有卷已完成！自动续写停止。');
          break;
        }
        
        // 切换到未完成的卷
        if (_selectedVolume != incompleteVolume) {
          setState(() => _selectedVolume = incompleteVolume!);
          if (_currentProject!.scopePlanning[incompleteVolume] != null) {
            _scopePlanningEditController.text = _currentProject!.scopePlanning[incompleteVolume]!;
          } else {
            _scopePlanningEditController.clear();
          }
        }

        // 4. 检查范围规划（当前卷）
        if (_currentProject!.scopePlanning[_selectedVolume]?.isEmpty ?? true) {
          _showMessage('智能续写[$cycleCount]：开始生成第$_selectedVolume卷范围规划...');
          await _generateScopePlanning();
          await _randomDelay();
          continue;
        }

        // 4. 检查章节规划（当前卷）
        final volumeStartChapter = (int.parse(_selectedVolume) - 1) * 120 + 1;
        final volumeEndChapter = int.parse(_selectedVolume) * 120;
        
        // 获取当前卷的章节规划（通过章节号范围判断）
        final currentVolumeChapters = _currentProject!.chapterPlanning.entries
            .where((e) {
              final chapterNum = int.tryParse(e.key) ?? 0;
              return chapterNum >= volumeStartChapter && chapterNum <= volumeEndChapter;
            })
            .toList();
        
        if (currentVolumeChapters.isEmpty) {
          _showMessage('智能续写[$cycleCount]：开始生成第$_selectedVolume卷章节规划（${isLocalModel ? "本地模型5章" : "在线模型10章"}）...');
          _planningStartController.text = volumeStartChapter.toString();
          _planningCountController.text = chapterBatchSize.toString();
          await _generateChapterPlanning();
          await _randomDelay();
          continue;
        }

        // 检查当前卷章节规划是否完成（120章）
        final currentVolumeChapterCount = currentVolumeChapters.length;
        if (currentVolumeChapterCount < 120) {
          _showMessage('智能续写[$cycleCount]：继续生成第$_selectedVolume卷章节规划（$currentVolumeChapterCount/120，${isLocalModel ? "本地模型5章" : "在线模型10章"}）...');
          final lastChapterInVolume = currentVolumeChapters
              .map((e) => int.tryParse(e.key) ?? 0)
              .fold(0, (max, v) => v > max ? v : max);
          final nextChapter = lastChapterInVolume + 1;
          _planningStartController.text = nextChapter.toString();
          _planningCountController.text = chapterBatchSize.toString();
          await _generateChapterPlanning();
          await _randomDelay();
          continue;
        }

        // 5. 检查章节正文（当前卷）
        final currentVolumeGeneratedChapters = _currentProject!.chapters
            .where((c) {
              final volumeStart = (int.parse(_selectedVolume) - 1) * 120 + 1;
              final volumeEnd = int.parse(_selectedVolume) * 120;
              return c.chapter >= volumeStart && c.chapter <= volumeEnd;
            })
            .toList();

        final generatedCount = currentVolumeGeneratedChapters.length;
        if (generatedCount < 120) {
          final nextChapterNum = (int.parse(_selectedVolume) - 1) * 120 + generatedCount + 1;
          _showMessage('智能续写[$cycleCount]：开始生成第$nextChapterNum章...');
          _generationChapterController.text = nextChapterNum.toString();
          await _generateChapter();
          await _randomDelay();
          continue;
        }

        // 当前卷已完成
        _showMessage('第$_selectedVolume卷已完成！自动续写停止。请手动切换到下一卷继续。');
        break;
        
      } catch (e) {
        _showMessage('智能续写[$cycleCount]失败: $e，将在延时后重试...');
        await _randomDelay();
      } finally {
        setState(() => _isLoading = false);
      }
    }

    setState(() {
      _isAutoContinuing = false;
      _shouldStopAutoContinue = false;
      _isLoading = false;
    });
    
    if (cycleCount > 0) {
      _showMessage('自动续写已停止，共执行$cycleCount轮');
    }
  }

  /// 根据设置进行延时
  Future<void> _randomDelay() async {
    final settingsService = SettingsService();
    final delaySeconds = settingsService.settings.getActualDelaySeconds();
    _showMessage('等待${delaySeconds}秒后继续...');
    await Future.delayed(Duration(seconds: delaySeconds));
  }

  bool get _hasOutline => _currentProject?.outline.isNotEmpty ?? false;
  bool get _hasVolumePlanning => _currentProject?.volumePlanning.isNotEmpty ?? false;
  bool get _hasScopePlanning => _currentProject?.scopePlanning.isNotEmpty ?? false;
  bool get _hasChapterPlanning => _currentProject?.chapterPlanning.isNotEmpty ?? false;
  bool get _hasGeneratedChapters => _currentProject?.chapters.isNotEmpty ?? false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 小说生成器'),
        actions: [
          if (_currentBook != null)
            IconButton(
              icon: Icon(_isAutoContinuing ? Icons.stop : Icons.auto_fix_high),
              tooltip: _isAutoContinuing ? '停止自动续写' : '智能续写',
              color: _isAutoContinuing ? Colors.red : null,
              onPressed: _isLoading && !_isAutoContinuing ? null : _autoContinue,
            ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '系统设置',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.smart_toy),
            tooltip: 'AI配置',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LLMConfigPage()),
              );
              _aiConfig = await _aiConfigService.getConfig();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProjectHeader(),
          if (_currentBook != null) ...[
            _buildWorkflowSteps(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(), // 禁用滑动，使用Tab切换
                children: [
                  KeepAliveWrapper(child: _buildOutlineTab()),
                  KeepAliveWrapper(child: _buildVolumePlanningTab()),
                  KeepAliveWrapper(child: _buildScopePlanningTab()),
                  KeepAliveWrapper(child: _buildChapterPlanningTab()),
                  KeepAliveWrapper(child: _buildChapterGenerationTab()),
                ],
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: _isLoading
          ? const FloatingActionButton(
              onPressed: null,
              child: CircularProgressIndicator(color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildProjectHeader() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey.shade200;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const StartPage()),
              );
            },
            icon: Icon(Icons.arrow_back, color: textColor),
            label: Text('返回主界面', style: TextStyle(color: textColor)),
            style: OutlinedButton.styleFrom(
              foregroundColor: textColor,
              side: BorderSide(color: isDarkMode ? Colors.white54 : Colors.grey),
              backgroundColor: isDarkMode ? const Color(0xFF3A3A3A) : Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '当前项目: ${_currentBook ?? ""}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowSteps() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey.shade200;
    final textColor = isDarkMode ? Colors.white70 : Colors.black54;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '创作流程',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStep('1', '大纲', _hasOutline),
              const Expanded(child: Divider()),
              _buildStep('2', '分卷规划', _hasVolumePlanning),
              const Expanded(child: Divider()),
              _buildStep('3', '范围规划', _hasScopePlanning),
              const Expanded(child: Divider()),
              _buildStep('4', '章节规划', _hasChapterPlanning),
              const Expanded(child: Divider()),
              _buildStep('5', '章节生成', _hasGeneratedChapters),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String title, bool completed) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed ? const Color(0xFF1890FF) : const Color(0xFFF0F0F0),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: completed ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: completed ? const Color(0xFF1890FF) : Colors.black87,
          ),
        ),
        Text(
          completed ? '已完成' : '待生成',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: completed ? const Color(0xFF52C41A) : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final unselectedColor = isDarkMode ? Colors.white70 : Colors.black87;
    
    return Container(
      color: bgColor,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF1890FF),
        unselectedLabelColor: unselectedColor,
        indicatorColor: const Color(0xFF1890FF),
        isScrollable: true,
        tabs: const [
          Tab(text: '大纲'),
          Tab(text: '分卷规划'),
          Tab(text: '范围规划'),
          Tab(text: '章节规划'),
          Tab(text: '生成章节'),
        ],
      ),
    );
  }

  Widget _buildOutlineTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final buttonBgColor = isDarkMode ? const Color(0xFF3A3A3A) : Colors.white;
    final buttonTextColor = isDarkMode ? Colors.white : Colors.black87;
    final borderColor = isDarkMode ? Colors.white54 : Colors.grey;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_hasOutline) ...[
            Text(
              '小说基本信息',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDarkMode ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _outlinePromptController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '请输入小说的基本信息，如：书名、体裁、主题、主角设定等...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '提示：可以包含书名、体裁类型、核心主题、主角特征、故事背景等信息',
              style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _generateOutline,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1890FF),
                foregroundColor: Colors.white,
              ),
              child: Text(_isLoading ? '生成中...' : '生成大纲', style: const TextStyle(color: Colors.white)),
            ),
          ] else ...[
            Text(
              '大纲内容',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDarkMode ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveOutline,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1890FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('保存大纲', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _outlineEditController,
              maxLines: 20,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 分卷规划Tab（整本书的分卷规划）
  Widget _buildVolumePlanningTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final buttonBgColor = isDarkMode ? const Color(0xFF3A3A3A) : Colors.white;
    final buttonTextColor = isDarkMode ? Colors.white : Colors.black87;
    final borderColor = isDarkMode ? Colors.white54 : Colors.grey;
    final hasVolumePlanning = _currentProject?.volumePlanning.isNotEmpty ?? false;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 生成按钮区域
          if (!hasVolumePlanning)
            ElevatedButton(
              onPressed: (_isLoading || _currentProject == null || _currentProject!.outline.isEmpty) 
                  ? null 
                  : _generateVolumePlanning,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1890FF),
                foregroundColor: Colors.white,
              ),
              child: Text(
                _isLoading ? '生成中...' : '生成分卷规划',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '基于大纲，生成整本书的分卷规划（包含所有卷的概要）',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          
          // 分卷规划内容编辑区
          if (hasVolumePlanning || _volumePlanningEditController.text.isNotEmpty) ...[
            const Text(
              '分卷规划内容',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveVolumePlanning,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1890FF),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('保存分卷规划', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _volumePlanningEditController,
              maxLines: 25,
              decoration: const InputDecoration(
                hintText: '分卷规划将显示在这里...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ] else ...[
            // 提示信息
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '尚未生成分卷规划',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '分卷规划是对整本书各卷内容的总体规划，包含：\n'
                    '• 每卷的标题和章节范围\n'
                    '• 每卷的核心主题和发展脉络\n'
                    '• 各卷之间的关联和递进关系\n\n'
                    '请确保已生成写作大纲，然后点击"生成分卷规划"按钮。',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 范围规划Tab（每卷的详细范围规划）
  Widget _buildScopePlanningTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final buttonBgColor = isDarkMode ? const Color(0xFF3A3A3A) : Colors.white;
    final buttonTextColor = isDarkMode ? Colors.white : Colors.black87;
    final borderColor = isDarkMode ? Colors.white54 : Colors.grey;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: _selectedVolume,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: ['1', '2', '3', '4', '5'].map((v) {
                    final start = (int.parse(v) - 1) * 120 + 1;
                    final end = int.parse(v) * 120;
                    return DropdownMenuItem(
                      value: v,
                      child: Text('第$v卷（$start-$end章）', style: const TextStyle(color: Colors.black87, fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedVolume = value;
                        if (_currentProject?.scopePlanning[value] != null) {
                          _scopePlanningEditController.text = _currentProject!.scopePlanning[value]!;
                        } else {
                          _scopePlanningEditController.clear();
                        }
                      });
                    }
                  },
                ),
              ),
              ElevatedButton(
                onPressed: (_isLoading || _currentProject == null || _currentProject!.volumePlanning.isEmpty) 
                    ? null 
                    : _generateScopePlanning,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1890FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text(_isLoading ? '生成中...' : '生成本卷范围规划', style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_currentProject!.volumePlanning.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '请先在"分卷规划"Tab生成分卷规划，然后才能生成范围规划',
                      style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              '基于大纲和分卷规划，为选中的卷生成详细的章节范围规划（每卷独立）',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          const SizedBox(height: 16),
          if (_scopePlanningEditController.text.isNotEmpty) ...[
            const Text(
              '范围规划内容',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveScopePlanning,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1890FF),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('保存范围规划', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _scopePlanningEditController,
              maxLines: 25,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChapterPlanningTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final buttonBgColor = isDarkMode ? const Color(0xFF3A3A3A) : Colors.white;
    final buttonTextColor = isDarkMode ? Colors.white : Colors.black87;
    final borderColor = isDarkMode ? Colors.white54 : Colors.grey;
    final sortedChapters = _currentProject?.chapterPlanning.entries.toList()
      ?..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _planningStartController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '起始章节',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    labelStyle: TextStyle(color: Colors.black87),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _generateChapterPlanning,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1890FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text(_isLoading ? '生成中...' : '生成章节规划', style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '基于精简大纲和范围规划生成章节规划。本地模型每次5章，在线模型每次10章',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          // 显示所有章节规划内容
          if (sortedChapters != null && sortedChapters.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已生成章节规划（共${sortedChapters.length}章）',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                ),
                OutlinedButton(
                  onPressed: _isLoading ? null : _continueChapterPlanning,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: buttonTextColor,
                    side: BorderSide(color: borderColor),
                    backgroundColor: buttonBgColor,
                  ),
                  child: Text(_isLoading ? '生成中...' : '继续生成', style: TextStyle(color: buttonTextColor)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 章节规划列表
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedChapters.length > 50 ? 50 : sortedChapters.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final chapter = sortedChapters[index];
                  return ExpansionTile(
                    title: Text('第${chapter.key}章', style: const TextStyle(color: Colors.black87, fontSize: 14)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          chapter.value,
                          style: const TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ] else ...[
            // 空状态提示
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.description_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      '尚未生成章节规划',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '输入起始章节号，点击生成按钮开始',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChapterGenerationTab() {
    final sortedChapters = _currentProject?.chapters.toList()
      ?..sort((a, b) => a.chapter.compareTo(b.chapter));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _generationChapterController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '章节号',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    labelStyle: TextStyle(color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _generateChapter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1890FF),
                  foregroundColor: Colors.white,
                ),
                child: Text(_isLoading ? '生成中...' : '生成章节', style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              if (_generatedChapterContent != null)
                ElevatedButton(
                  onPressed: _saveChapter,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF52C41A),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('保存章节', style: TextStyle(color: Colors.white)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_generatedChapterContent != null) ...[
            const Text(
              '章节内容预览',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Card(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: SelectableText(_generatedChapterContent!, style: const TextStyle(color: Colors.black87)),
              ),
            ),
          ],
          if (sortedChapters != null && sortedChapters.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const Text(
              '已生成章节',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedChapters.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final chapter = sortedChapters[index];
                  return ListTile(
                    title: Text('第${chapter.chapter}章', style: const TextStyle(color: Colors.black87)),
                    subtitle: Text(
                      chapter.content.length > 100
                          ? '${chapter.content.substring(0, 100)}...'
                          : chapter.content,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: _isLoading 
                            ? null 
                            : () => _showPolishDialog(chapter.chapter),
                          icon: const Icon(Icons.auto_fix_high, size: 16),
                          label: const Text('润色'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF1890FF),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text('${chapter.wordCount}字', style: const TextStyle(color: Color(0xFF096DD9))),
                          backgroundColor: const Color(0xFFE6F7FF),
                        ),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        _generatedChapterContent = chapter.content;
                        _generatedChapterNumber = chapter.chapter;
                        _generationChapterController.text = chapter.chapter.toString();
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// 保持Tab页面状态的包装器
class KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
