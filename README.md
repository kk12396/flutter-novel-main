# 开源说明

这是1个flutter版支持多端的AI小说生成器。本软件是受 https://www.52pojie.cn/forum.php?mod=viewthread&tid=2078458 的启发，但是觉得原版操作太麻烦，于是基于2025年4-5月份自写的4-5个创作小说提示词，
将写作步骤分为生成大纲，设计分卷规划，设计范围规划，设计章节规划，最后生成每章正文，先是将参考版简化为纯html版，在龙虾出来后又加入了自动判定进度续写功能，但是测试发现逻辑问题，于是加了进度追踪，又测试多章写作遇到新问题，同质化于是修改了提示词，2026年3月底结合mud游戏与创作小说得到灵感就增加了随机生成书名和题材功能。
本来是想留着自用，或者搞推广部分功能收费，但是发现已经有了很多AI创作的，也有不少开源，干脆也开源出来。

# 注意事项：
本工具仅为写作辅助工具，内容由用户自行调用大模型接口获取，工具仅封装常用写作的提示词模板。
生成内容仅供娱乐参考，AI生成的内容可能存在逻辑混乱、同质化、事实错误等问题。
请勿将生成内容直接用于商业用途或作为专业建议。
使用者应对生成内容进行审核和修改。
**软件支持自定义AI接口，电脑端支持本地ollama，如果是手机用本地ollama要用间接方法，
也就是局域网转发，用python或go简单写1个就行了。**
**同质化问题，也就是某一章看起来没问题，但是连续几章就看出来问题，几乎都一样的套路。**


# NovelGenerator - 开发者文档节选

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

---

## GitHub 在线打包 APK（推荐）

下面这套流程已经可直接用于你的仓库，适合**不在本地装 Android/Flutter 环境**时打包 APK。

### 1) 我已经帮你补齐的关键点

- 新增了 GitHub Actions 工作流：`.github/workflows/android-apk.yml`。
- 工作流自动完成：
  - 安装 JDK 17
  - 安装 Flutter（stable）
  - 拉取依赖 `flutter pub get`
  - 执行测试 `flutter test`
  - 构建 APK（支持 release/debug，支持 split-per-abi）
  - 上传 APK 到 Actions Artifacts
- 修复了一个常见 CI 阻塞项：
  - 删除 `android/gradle.properties` 中原本固定在 Windows 本机路径的 `org.gradle.java.home=C:\\Program Files\\Java\\jdk-17.0.5`
  - 这样 GitHub Linux Runner 才不会因为找不到本地 Windows 路径而失败。

### 2) 第一次使用前（GitHub 网页操作）

1. 把代码推送到 GitHub 仓库（`main` 或 `master` 分支）。
2. 打开仓库的 **Actions** 标签页。首次使用时若提示启用，点击启用 Actions。
3. 左侧找到工作流 **Build Android APK**。

### 3) 手动在线打包（最常用）

1. 进入 **Actions -> Build Android APK**。
2. 点击 **Run workflow**。
3. 参数说明：
   - `build_mode`：
     - `release`：正式包（推荐）
     - `debug`：调试包
   - `split_per_abi`：
     - `false`：单个通用 APK
     - `true`：按 CPU 架构拆分多个 APK（体积更小）
4. 点击绿色 **Run workflow** 开始构建。

### 4) 自动触发打包规则

工作流还会在以下场景自动触发：

- push 到 `main/master` 且改动了 `lib/**`、`android/**`、`pubspec.yaml` 等关键文件。
- pull request 改动了同样这些关键文件。

自动触发时默认构建 `release` APK。

### 5) 在哪里下载 APK

1. 打包完成后，打开这次 workflow run。
2. 页面底部 **Artifacts** 区域会出现：`android-apk-<run_number>`。
3. 下载压缩包后解压，可得到：
   - `app-release.apk`（通用包）
   - 或多个分 ABI 的 APK（如果你启用了 split-per-abi）

### 6) 常见失败与排查

- **Gradle/JDK 相关错误**：
  - 已移除仓库中的固定本机 JDK 路径，通常可解决。
- **依赖拉取失败**：
  - 可能是网络抖动，重新 Run workflow 一次。
- **测试失败导致无法产物**：
  - 当前流程会先跑 `flutter test`，测试失败就会阻断打包（这是预期行为，防止坏包）。

### 7) 可选增强（后续你想要我可以继续加）

- 自动生成 `aab`（上架 Google Play 用）
- 增加 keystore 签名（生成可直接发布的正式签名包）
- 打 tag 时自动产出版本包（如 `v1.0.1`）
- 把 APK 自动上传到 Release 页面
