# NovelGenerator - 开发者文档

## 项目概述

NovelGenerator 是一个基于 Flutter 开发的 AI 智能小说创作工具，支持通过多种 LLM API（OpenRouter、OpenAI、Ollama 等）自动生成小说内容。

## 技术栈

- **框架**: Flutter 3.11.4+
- **语言**: Dart
- **状态管理**: StatefulWidget（原生状态管理）
- **本地存储**: SharedPreferences + 文件系统
- **网络请求**: http 包
- **路径管理**: path_provider

## 项目结构

```
lib/
├── constants/
│   └── prompt_templates.dart    # AI提示词模板
├── models/
│   ├── ai_config.dart           # AI配置模型
│   └── project.dart             # 项目数据模型
├── pages/
│   ├── llm_config_page.dart     # LLM配置页面
│   ├── settings_page.dart       # 系统设置页面
│   ├── simplified_novel_page.dart # 小说创作主页面
│   └── start_page.dart          # 启动页面
├── services/
│   ├── ai_config_service.dart   # AI配置管理服务
│   ├── llm_service.dart         # LLM API调用服务
│   ├── log_service.dart         # 日志服务
│   ├── settings_service.dart    # 系统设置服务
│   ├── storage_service.dart     # 项目存储服务
│   └── theme_service.dart       # 主题管理服务
├── utils/
│   └── responsive.dart          # 响应式布局工具
└── main.dart                    # 应用入口
```

## 核心功能模块

### 1. 项目管理系统 (storage_service.dart)

- **项目存储**: 每个项目独立目录，位于 `books/项目名称/`
- **文件结构**:
  ```
  books/项目名称/
  ├── 大纲.txt
  ├── 分卷规划.txt
  ├── 范围规划_第X卷.txt
  ├── 进度追踪.txt
  ├── 章节规划/
  │   └── 第X章_章节规划.txt
  └── 正文/
      └── 第X章.txt
  ```

### 2. AI配置系统 (ai_config.dart / ai_config_service.dart)

- **支持的提供商**:
  - OpenRouter (默认)
  - OpenAI
  - Ollama (本地)
  - Claude
  - 智谱AI
  - 深度求索
  - 通义千问

- **配置存储**: `ai_config.json` (应用运行目录)

### 3. LLM调用服务 (llm_service.dart)

- **统一接口**: `callLLMWithConfig()`
- **超时设置**: 180秒
- **支持协议**: OpenAI API格式、Ollama格式

### 4. 提示词模板 (prompt_templates.dart)

包含完整的提示词模板：
- `outline`: 大纲生成（700-900字精简格式）
- `volumePlanning`: 分卷规划生成
- `scopePlanning`: 范围规划生成
- `chapterPlanning`: 章节规划生成
- `chapterGeneration`: 章节内容生成

## 数据模型

### Project 模型

```dart
class Project {
  final String name;                    // 项目名称
  final String outline;                 // 大纲
  final Map<String, String> volumePlanning;  // 分卷规划
  final Map<String, String> scopePlanning;   // 范围规划
  final Map<String, String> chapterPlanning; // 章节规划
  final List<Chapter> chapters;         // 章节列表
  final Map<String, String> generatedChapters; // 已生成章节
  final String? progressTracking;       // 进度追踪
}
```

### AIConfig 模型

```dart
class AIConfig {
  final String currentProvider;         // 当前提供商
  final String currentModel;            // 当前模型
  final Map<String, ProviderConfig> providers; // 提供商配置
}
```

## 依赖库

### 核心依赖

- `flutter`: SDK
- `shared_preferences`: ^2.2.3 - 本地存储
- `http`: ^1.2.1 - HTTP请求
- `path_provider`: ^2.1.3 - 路径获取

### 开发依赖

- `flutter_test`: 测试框架
- `flutter_lints`: ^6.0.0 - 代码规范

## 开发环境搭建

### 1. 安装依赖

```bash
flutter pub get
```

### 2. 运行开发版本

```bash
flutter run
```

### 3. 构建发布版本

#### Windows
```bash
flutter build windows --release
```
输出目录: `build/windows/x64/runner/Release/`

#### Android
```bash
# 完整APK（包含所有架构）
flutter build apk --release

# 分架构构建（体积更小，推荐）
flutter build apk --release --target-platform=android-arm64
flutter build apk --release --target-platform=android-arm

# 如果遇到 Gradle daemon 问题，使用：
$env:GRADLE_OPTS="-Dorg.gradle.daemon=false"; flutter build apk --release --target-platform=android-arm64
```
输出目录: `build/app/outputs/flutter-apk/`

#### iOS (需要Mac)
```bash
flutter build ios --release
```

### 4. 安装到设备

```bash
# 安装到安卓设备/模拟器
adb install build/app/outputs/flutter-apk/app-release.apk

# 启动应用
adb shell am start -n com.example.novelgenerator/.MainActivity
```

## 关键配置

### 添加新的LLM提供商

在 `ai_config.dart` 中的 `getDefaultConfig()` 方法添加：

```dart
'new-provider': ProviderConfig(
  type: 'openai',  // 或 'ollama', 'claude'
  name: 'New Provider',
  enabled: true,
  apiKey: '',
  baseUrl: 'https://api.example.com/v1',
  model: ['model-1', 'model-2'],
)
```

### 修改提示词模板

编辑 `constants/prompt_templates.dart` 中的对应常量。

## 调试与日志

### Windows
- **日志位置**: `build/windows/x64/runner/Release/logs/`
- **日志文件**: `app_YYYYMMDD.log`

### Android
- **日志位置**: 应用私有目录下的 `logs/` 文件夹
- **查看日志**: 使用 Android Studio 或 `adb logcat`

## 构建输出

### Windows
- **输出目录**: `build/windows/x64/runner/Release/`
- **可执行文件**: `novelgenerator.exe`
- **依赖库**: 同目录下的 DLL 文件

### Android
- **输出目录**: `build/app/outputs/flutter-apk/`
- **APK文件**: `app-release.apk`
- **安装命令**: `adb install build/app/outputs/flutter-apk/app-release.apk`
- **支持架构**: armeabi-v7a, arm64-v8a, x86_64

## 存储路径

### Windows
- **项目数据**: 运行目录下的 `books/` 文件夹
- **配置文件**: 运行目录下的 `config.json`, `ai_config.json`, `theme_config.json`

### Android
- **优先路径**: `/storage/emulated/0/novelgenerator/`
- **降级路径**: `/storage/emulated/0/Android/data/com.example.novelgenerator/files/`
- **路径选择**: 应用启动时自动检测外部存储权限，优先使用外部存储根目录，权限不足时降级到应用私有目录

## 主题系统

### ThemeService

位于 `services/theme_service.dart`，管理应用主题状态：

- **功能**: 浅色/深色主题切换、主题持久化
- **存储**: 主题配置保存在 `theme_config.json`
- **使用**: 
  ```dart
  final themeService = ThemeService();
  themeService.toggleTheme();  // 切换主题
  bool isDark = themeService.isDarkMode;  // 获取当前主题
  ```

### 主题适配

各页面通过 `Theme.of(context).brightness` 判断当前主题：
```dart
final isDarkMode = Theme.of(context).brightness == Brightness.dark;
final cardColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
```

## 响应式布局

### 屏幕适配

应用支持多平台响应式布局，主要适配点：

- **小屏幕** (<600px): 手机竖屏，卡片垂直排列
- **中等屏幕** (600-900px): 平板/手机横屏，Wrap布局
- **大屏幕** (>900px): 桌面端，水平排列

### 实现方式

使用 `MediaQuery` 获取屏幕尺寸：
```dart
final screenSize = MediaQuery.of(context).size;
final isSmallScreen = screenSize.width < 600;
final isMediumScreen = screenSize.width >= 600 && screenSize.width < 900;

// 根据屏幕尺寸调整
final titleFontSize = isSmallScreen ? 32.0 : 48.0;
final padding = isSmallScreen ? 16.0 : 40.0;
```

## 系统设置

### SettingsService

位于 `services/settings_service.dart`，管理系统设置：

- **功能**: 主题模式、自动续写延迟设置
- **存储**: 配置保存在 `config.json`
- **设置项**:
  - `baseDelaySeconds`: 基础延迟秒数 (10-240秒)
  - `randomDelaySeconds`: 随机延迟秒数 (0-60秒)
  - `isDarkMode`: 是否深色主题

### SettingsPage

位于 `pages/settings_page.dart`，设置界面：

- 主题切换开关
- 基础延迟滑块 (10-240秒，步进10秒)
- 随机延迟滑块 (0-60秒，步进5秒)
- 实时显示当前设置值

## 安卓适配

### 文件存储路径

安卓版优先使用外部存储根目录：`/storage/emulated/0/novelgenerator/`
如果权限不足，降级到应用私有目录：`/storage/emulated/0/Android/data/com.example.novelgenerator/files/`

### 权限配置

`AndroidManifest.xml` 已配置：
- `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` - 存储权限
- `MANAGE_EXTERNAL_STORAGE` - Android 11+ 所有文件访问权限
- `READ_MEDIA_IMAGES/VIDEO/AUDIO` - Android 13+ 媒体权限
- `INTERNET` / `ACCESS_NETWORK_STATE` - 网络权限
- `requestLegacyExternalStorage="true"` - 传统外部存储支持

### 路径选择逻辑

```dart
// 首先尝试外部存储根目录
final novelDir = Directory('/storage/emulated/0/novelgenerator');
try {
  // 测试创建和写入权限
  if (!await novelDir.exists()) {
    await novelDir.create(recursive: true);
  }
  final testFile = File('${novelDir.path}/.test');
  await testFile.writeAsString('test');
  await testFile.delete();
  // 使用外部存储
} catch (e) {
  // 降级到应用私有目录
  final appDocDir = await getApplicationDocumentsDirectory();
}
```

### 注意事项

1. 安卓 `Directory.current` 返回 `/`（只读），必须使用 `path_provider`
2. 日志服务使用 `getApplicationDocumentsDirectory()`（应用私有）
3. 存储服务优先使用外部存储根目录，失败时降级到应用私有目录

## 注意事项

1. **编码问题**: 所有文本文件使用 UTF-8 编码
2. **路径处理**: 使用 `Platform.pathSeparator` 处理跨平台路径
3. **异步操作**: 所有文件操作和API调用都是异步的
4. **状态管理**: 使用 `setState()` 更新UI，复杂状态考虑使用 Provider 或 Riverpod

## 扩展开发

### 添加新的生成阶段

1. 在 `prompt_templates.dart` 添加提示词模板
2. 在 `simplified_novel_page.dart` 添加生成方法
3. 在 `storage_service.dart` 添加保存逻辑
4. 更新UI添加对应按钮

### 自定义解析逻辑

章节内容和进度追踪解析支持多种格式：
- `===章节内容===` / `===进度追踪更新===`
- `【章节内容】` / `【进度追踪更新】`
- `### 章节进度追踪` (Markdown格式)

解析逻辑位于 `simplified_novel_page.dart` 的 `_generateChapter()` 方法。

## 许可证

本项目为私有项目，未经授权不得分发。
