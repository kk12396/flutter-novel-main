import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/llm_service.dart';
import '../services/ai_config_service.dart';
import '../models/project.dart';
import 'simplified_novel_page.dart';
import 'llm_config_page.dart';
import 'settings_page.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  final StorageService _storage = StorageService();
  final AIConfigService _aiConfigService = AIConfigService();
  bool _showCustomForm = false;
  bool _showProjectList = false;
  bool _isLoading = false;
  bool _isGenerating = false;
  String _generationStatus = '';
  List<String> _projects = [];

  // 表单控制器
  final TextEditingController _bookNameController = TextEditingController();
  final TextEditingController _settingController = TextEditingController();
  final TextEditingController _hookController = TextEditingController();

  // 下拉选项
  String _selectedGenre = '玄幻';
  String _selectedTheme = '逆袭崛起';

  final List<String> _genres = [
    '玄幻', '仙侠', '都市', '科幻', '历史', '武侠', '奇幻', '悬疑', '末世', '无限流'
  ];

  final List<String> _themes = [
    '逆袭崛起', '复仇之路', '守护挚爱', '探索未知', '追求长生', 
    '权力争霸', '寻找真相', '改变命运', '打破宿命', '重建秩序'
  ];

  final Map<String, List<String>> _settings = {
    '玄幻': ['斗气大陆', '魔法世界', '妖兽森林', '远古遗迹', '天界神域'],
    '仙侠': ['修真界', '仙界', '凡间王朝', '洞天福地', '魔道宗门'],
    '都市': ['现代都市', '灵气复苏', '异能都市', '商业帝国', '娱乐圈'],
    '科幻': ['星际时代', '赛博朋克', '末日废土', '时空穿越', '人工智能'],
    '历史': ['架空王朝', '乱世争霸', '宫廷权谋', '江湖风云', '边塞烽火'],
    '武侠': ['江湖武林', '门派纷争', '朝廷与江湖', '西域边疆', '江南水乡'],
    '奇幻': ['中土世界', '精灵国度', '矮人王国', '魔法学院', '异世界'],
    '悬疑': ['现代都市', '古镇谜案', '封闭空间', '校园怪谈', '古墓探秘'],
    '末世': ['丧尸危机', '核冬天', '资源枯竭', '外星入侵', '文明重启'],
    '无限流': ['主神空间', '恐怖片世界', '游戏副本', '诸天万界', '轮回世界'],
  };

  final List<String> _plotHooks = [
    '卷入惊天阴谋', '发现隐藏秘密', '意外结识关键人物', 
    '被命运推向漩涡中心', '继承神秘使命', '解开古老谜团'
  ];

  @override
  void initState() {
    super.initState();
    // 延迟加载项目列表，避免阻塞UI渲染
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProjects();
    });
  }

  @override
  void dispose() {
    _bookNameController.dispose();
    _settingController.dispose();
    _hookController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    try {
      final projects = await _storage.listProjects();
      if (mounted) {
        setState(() {
          _projects = projects;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getRandomItem(List<String> list) {
    return list[DateTime.now().millisecond % list.length];
  }

  // 从大纲中提取书名
  String _extractBookNameFromOutline(String outline) {
    // 尝试匹配【书名】xxx 格式（优先匹配）
    final bracketMatch = RegExp(r'【书名】\s*(.+?)(?:\n|$)').firstMatch(outline);
    if (bracketMatch != null) {
      String bookName = bracketMatch.group(1)?.trim() ?? '';
      // 清理非法字符和书名号
      bookName = bookName.replaceAll(RegExp(r'[\\/:*?"<>|《》]'), '').trim();
      // 过滤掉默认值和占位符
      if (bookName.isNotEmpty && 
          bookName.length <= 20 && 
          bookName != '书名' && 
          bookName != '具体书名' &&
          !bookName.toLowerCase().contains('bookname')) {
        return bookName;
      }
    }
    
    // 尝试匹配《书名》格式
    final match = RegExp(r'《([^》]+)》').firstMatch(outline);
    if (match != null) {
      String bookName = match.group(1) ?? '';
      // 清理非法字符
      bookName = bookName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
      // 过滤掉默认值和占位符
      if (bookName.isNotEmpty && 
          bookName.length <= 20 && 
          bookName != '书名' && 
          bookName != '具体书名' &&
          !bookName.toLowerCase().contains('bookname')) {
        return bookName;
      }
    }
    // 尝试匹配 "书名：" 或 "bookName:" 格式
    final nameMatch = RegExp(r'(?:书名|bookName)[：:]\s*《?([^》\n]+)》?', caseSensitive: false).firstMatch(outline);
    if (nameMatch != null) {
      String bookName = nameMatch.group(1)?.trim() ?? '';
      bookName = bookName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
      // 过滤掉默认值和占位符
      if (bookName.isNotEmpty && 
          bookName.length <= 20 && 
          bookName != '书名' && 
          bookName != '具体书名' &&
          !bookName.toLowerCase().contains('bookname')) {
        return bookName;
      }
    }
    return '';
  }

  /// 生成小说大纲（自定义模式：使用预定义书名）
  Future<String> _generateOutlineWithBookName(String genre, String theme, String setting, String plotHook, String bookName) async {
    setState(() {
      _isGenerating = true;
      _generationStatus = '正在连接AI服务...';
    });

    try {
      final aiConfig = await _aiConfigService.getConfig();
      
      // 检查配置
      final provider = aiConfig.providers[aiConfig.currentProvider];
      if (provider == null) {
        throw Exception('AI服务配置不存在，请先配置AI服务');
      }
      
      setState(() {
        _generationStatus = '正在生成大纲，这可能需要几分钟...';
      });
      
      final prompt = '''请创作一部$genre小说的完整大纲（700-900字）。

书名：《$bookName》
主题：$theme
背景设定：$setting
开篇钩子：$plotHook

【输出格式】
【书名】$bookName
【主题】$theme
【风格】[体裁+风格+目标读者]
【类型】$genre

【主角】[姓名]：[核心特质+成长弧线]
【初始状态】[背景设定+初始处境+起始能力/身份]

【世界观】
[时空背景+主要势力+核心规则+力量体系]

【关键角色】
- [姓名]：[核心特征+与主角关系+作用]

【次要群体】
- [群体名称]：[特征+作用]

【关键道具/能力】
- [名称]：[功能说明+获取方式]

【核心体系】
[根据小说类型填写]

【分卷概要】
第1卷（第1-120章）：[1-2句话简述]
第2卷（第121-240章）：[1-2句话简述]
...

注意：书名已确定为《$bookName》，请围绕这个书名创作详细大纲。''';    
      final messages = [LLMMessage(role: 'user', content: prompt)];
      final outline = await LLMService.callLLMWithConfig(messages, aiConfig);
      
      if (outline.isEmpty) {
        throw Exception('AI返回空内容，请检查模型是否正常工作');
      }
      
      return outline;
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _generationStatus = '';
      });
      _showErrorDialog('生成失败', e.toString());
      rethrow;
    }
  }
  
  /// 生成小说大纲（随机模式：AI自动生成书名）
  Future<Map<String, String>> _generateOutlineWithAutoBookName(String genre, String theme, String setting, String plotHook) async {
    setState(() {
      _isGenerating = true;
      _generationStatus = '正在连接AI服务...';
    });

    try {
      final aiConfig = await _aiConfigService.getConfig();
      
      // 检查配置
      final provider = aiConfig.providers[aiConfig.currentProvider];
      if (provider == null) {
        throw Exception('AI服务配置不存在，请先配置AI服务');
      }
      
      setState(() {
        _generationStatus = '正在生成大纲，这可能需要几分钟...';
      });
      
      final prompt = '''请创作一部$genre小说的完整大纲（700-900字）。

主题：$theme
背景设定：$setting
开篇钩子：$plotHook

【要求】
1. 首先根据主题和背景，创作一个吸引人的具体书名（2-6个字），格式为《书名》
2. 然后按以下格式生成完整大纲：

【书名】[具体书名]
【主题】$theme
【风格】[体裁+风格+目标读者]
【类型】$genre

【主角】[姓名]：[核心特质+成长弧线]
【初始状态】[背景设定+初始处境+起始能力/身份]

【世界观】
[时空背景+主要势力+核心规则+力量体系]

【关键角色】
- [姓名]：[核心特征+与主角关系+作用]

【次要群体】
- [群体名称]：[特征+作用]

【关键道具/能力】
- [名称]：[功能说明+获取方式]

【核心体系】
[根据小说类型填写]

【分卷概要】
第1卷（第1-120章）：[1-2句话简述]
第2卷（第121-240章）：[1-2句话简述]
...

重要：书名必须是具体的，例如《斗破苍穹》《凡人修仙传》，不能是《书名》这两个字''';    
      final messages = [LLMMessage(role: 'user', content: prompt)];
      final outline = await LLMService.callLLMWithConfig(messages, aiConfig);
      
      if (outline.isEmpty) {
        throw Exception('AI返回空内容，请检查模型是否正常工作');
      }
      
      // 从大纲中提取书名
      String bookName = _extractBookNameFromOutline(outline);
      if (bookName.isEmpty) {
        bookName = '未命名作品';
      }
      
      return {'bookName': bookName, 'outline': outline};
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _generationStatus = '';
      });
      _showErrorDialog('生成失败', e.toString());
      rethrow;
    }
  }

  Future<void> _startCustomGeneration() async {
    final genre = _selectedGenre;
    final theme = _selectedTheme;
    final setting = _settingController.text.trim().isEmpty 
        ? _getRandomItem(_settings[_selectedGenre]!)
        : _settingController.text.trim();
    final hook = _hookController.text.trim().isEmpty 
        ? _getRandomItem(_plotHooks)
        : _hookController.text.trim();
    
    // 使用用户输入的书名，若为空则使用默认值
    final bookName = _bookNameController.text.trim().isEmpty 
        ? '未命名作品' 
        : _bookNameController.text.trim();

    try {
      // 生成大纲（使用预定义的书名）
      final outline = await _generateOutlineWithBookName(genre, theme, setting, hook, bookName);

      // 3. 创建项目并保存大纲
      setState(() {
        _generationStatus = '正在保存项目...';
      });

      final project = Project(
        name: bookName,
        outline: outline,
      );
      await _storage.saveProject(project);
      await _storage.saveSelectedProject(bookName);

      setState(() {
        _isGenerating = false;
        _generationStatus = '';
      });

      // 4. 跳转到创作界面
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SimplifiedNovelPage(
              loadProjectName: bookName,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _generationStatus = '';
      });
      _showErrorDialog('生成失败', e.toString());
    }
  }

  Future<void> _startRandomGeneration() async {
    final genre = _getRandomItem(_genres);
    final theme = _getRandomItem(_themes);
    final setting = _getRandomItem(_settings[genre]!);
    final hook = _getRandomItem(_plotHooks);

    try {
      // 生成大纲并自动提取书名
      final result = await _generateOutlineWithAutoBookName(genre, theme, setting, hook);
      final bookName = result['bookName']!;
      final outline = result['outline']!;

      // 3. 创建项目并保存大纲
      setState(() {
        _generationStatus = '正在保存项目...';
      });

      final project = Project(
        name: bookName,
        outline: outline,
      );
      await _storage.saveProject(project);
      await _storage.saveSelectedProject(bookName);

      setState(() {
        _isGenerating = false;
        _generationStatus = '';
      });

      // 4. 跳转到创作界面
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SimplifiedNovelPage(
              loadProjectName: bookName,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _generationStatus = '';
      });
      _showErrorDialog('生成失败', e.toString());
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _continueProject(String projectName) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SimplifiedNovelPage(
          loadProjectName: projectName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸用于响应式布局
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isMediumScreen = screenSize.width >= 600 && screenSize.width < 900;
    
    // 根据屏幕尺寸调整字体和间距
    final titleFontSize = isSmallScreen ? 32.0 : 48.0;
    final subtitleFontSize = isSmallScreen ? 14.0 : 18.0;
    final padding = isSmallScreen ? 16.0 : 40.0;
    final maxWidth = isSmallScreen ? double.infinity : 900.0;
    
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 标题
                  Text(
                    '📚 AI 小说生成器',
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1890FF),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 10 : 15),
                  Text(
                    '选择一种方式开始您的小说创作之旅',
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6) ?? Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isSmallScreen ? 16 : 20),
                  // 配置按钮
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('系统设置'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1890FF),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LLMConfigPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.smart_toy, size: 18),
                        label: const Text('AI配置'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1890FF),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 20 : 30),

                  // 主要内容区域
                  if (_isGenerating) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_generationStatus, style: const TextStyle(color: Colors.black54)),
                  ] else if (_isLoading) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('加载中...', style: TextStyle(color: Colors.black54)),
                  ] else if (!_showCustomForm && !_showProjectList) ...[
                    // 三个选项卡片 - 响应式布局
                    if (isSmallScreen)
                      // 小屏幕：垂直排列
                      Column(
                        children: [
                          _buildOptionCard(
                            icon: '✏️',
                            title: '自定义创作',
                            description: '设定书名、类型、主题，打造专属故事',
                            onTap: () => setState(() => _showCustomForm = true),
                            isSmallScreen: true,
                          ),
                          const SizedBox(height: 16),
                          _buildOptionCard(
                            icon: '🎲',
                            title: '随机生成',
                            description: '一键随机生成完整设定，快速开始创作',
                            onTap: _startRandomGeneration,
                            isSmallScreen: true,
                          ),
                          const SizedBox(height: 16),
                          _buildOptionCard(
                            icon: '📂',
                            title: '继续创作',
                            description: '加载已保存的项目继续创作',
                            onTap: () {
                              _loadProjects();
                              setState(() => _showProjectList = true);
                            },
                            isSmallScreen: true,
                          ),
                        ],
                      )
                    else if (isMediumScreen)
                      // 中等屏幕：Wrap 布局
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          _buildOptionCard(
                            icon: '✏️',
                            title: '自定义创作',
                            description: '设定书名、类型、主题，打造专属故事',
                            onTap: () => setState(() => _showCustomForm = true),
                            isSmallScreen: false,
                          ),
                          _buildOptionCard(
                            icon: '🎲',
                            title: '随机生成',
                            description: '一键随机生成完整设定，快速开始创作',
                            onTap: _startRandomGeneration,
                            isSmallScreen: false,
                          ),
                          _buildOptionCard(
                            icon: '📂',
                            title: '继续创作',
                            description: '加载已保存的项目继续创作',
                            onTap: () {
                              _loadProjects();
                              setState(() => _showProjectList = true);
                            },
                            isSmallScreen: false,
                          ),
                        ],
                      )
                    else
                      // 大屏幕：水平排列
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildOptionCard(
                            icon: '✏️',
                            title: '自定义创作',
                            description: '设定书名、类型、主题，打造专属故事',
                            onTap: () => setState(() => _showCustomForm = true),
                            isSmallScreen: false,
                          ),
                          const SizedBox(width: 30),
                          _buildOptionCard(
                            icon: '🎲',
                            title: '随机生成',
                            description: '一键随机生成完整设定，快速开始创作',
                            onTap: _startRandomGeneration,
                            isSmallScreen: false,
                          ),
                          const SizedBox(width: 30),
                          _buildOptionCard(
                            icon: '📂',
                            title: '继续创作',
                            description: '加载已保存的项目继续创作',
                            onTap: () {
                              _loadProjects();
                              setState(() => _showProjectList = true);
                            },
                            isSmallScreen: false,
                          ),
                        ],
                      ),
                  ] else if (_showCustomForm) ...[
                    // 自定义创作表单
                    _buildCustomForm(),
                  ] else if (_showProjectList) ...[
                    // 项目列表
                    _buildProjectList(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    required bool isSmallScreen,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFFF0F0F0);
    final titleColor = isDarkMode ? Colors.white : Colors.black87;
    final descColor = isDarkMode ? Colors.white70 : Colors.black54;
    
    // 根据屏幕尺寸调整卡片大小
    final cardWidth = isSmallScreen ? double.infinity : 280.0;
    final cardPadding = isSmallScreen ? 24.0 : 40.0;
    final iconSize = isSmallScreen ? 36.0 : 48.0;
    final titleFontSize = isSmallScreen ? 18.0 : 22.0;
    final descFontSize = isSmallScreen ? 12.0 : 14.0;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: cardWidth,
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(icon, style: TextStyle(fontSize: iconSize)),
              SizedBox(height: isSmallScreen ? 12 : 20),
              Text(
                title,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w500,
                  color: titleColor,
                ),
              ),
              SizedBox(height: isSmallScreen ? 8 : 10),
              Text(
                description,
                style: TextStyle(
                  fontSize: descFontSize,
                  color: descColor,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomForm() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFFF0F0F0);
    final titleColor = isDarkMode ? Colors.white : Colors.black87;
    
    return Container(
      width: 600,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              '自定义故事设定',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: titleColor,
              ),
            ),
          ),
          const SizedBox(height: 30),

          // 书名
          _buildFormLabel('书名'),
          TextField(
            controller: _bookNameController,
            decoration: const InputDecoration(
              hintText: '输入书名（可选，留空将由AI生成）',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(height: 16),

          // 类型和主题
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormLabel('类型'),
                    DropdownButtonFormField<String>(
                      value: _selectedGenre,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _genres.map((g) => DropdownMenuItem(
                        value: g,
                        child: Text(g),
                      )).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedGenre = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormLabel('主题'),
                    DropdownButtonFormField<String>(
                      value: _selectedTheme,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _themes.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t),
                      )).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedTheme = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 背景设定
          _buildFormLabel('背景设定'),
          TextField(
            controller: _settingController,
            decoration: const InputDecoration(
              hintText: '如：修真界、未来都市、魔法学院（可选）',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(height: 16),

          // 开篇钩子
          _buildFormLabel('开篇钩子'),
          TextField(
            controller: _hookController,
            decoration: const InputDecoration(
              hintText: '如：卷入惊天阴谋、发现隐藏秘密（可选）',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(height: 30),

          // 按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _startCustomGeneration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1890FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('开始创作'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => setState(() => _showCustomForm = false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Colors.grey),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('取消'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildProjectList() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFFF0F0F0);
    final titleColor = isDarkMode ? Colors.white : Colors.black87;
    
    return Container(
      width: 800,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              '选择项目继续创作',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: titleColor,
              ),
            ),
          ),
          const SizedBox(height: 30),

          if (_projects.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  '暂无项目，请先创建新项目',
                  style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54),
                ),
              ),
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _projects.map((name) => _buildProjectCard(name, isDarkMode)).toList(),
            ),

          const SizedBox(height: 30),
          Center(
            child: OutlinedButton(
              onPressed: () => setState(() => _showProjectList = false),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                side: BorderSide(color: isDarkMode ? Colors.white54 : Colors.grey),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('返回'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(String name, bool isDarkMode) {
    final cardColor = isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFFFAFAFA);
    final borderColor = isDarkMode ? const Color(0xFF4A4A4A) : const Color(0xFFF0F0F0);
    
    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name.startsWith('《') ? name : '《$name》',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF1890FF),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _continueProject(name),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1890FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('继续创作'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _deleteProject(name),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF4D4F),
                  side: const BorderSide(color: Color(0xFFFF4D4F)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProject(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除项目"$name"吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF4D4F)),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storage.deleteProject(name);
      await _loadProjects();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('项目已删除')),
        );
      }
    }
  }
}
