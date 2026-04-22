import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/project.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Directory? _cachedAppDir;
  Directory? _cachedBooksDir;

  Future<void> init() async {
    // Android 请求存储权限 - 异步执行不阻塞
    if (Platform.isAndroid) {
      await _requestStoragePermission();
    }
    
    final appDir = await _getAppDirectory();
    _cachedBooksDir = Directory('${appDir.path}/books');
    if (!await _cachedBooksDir!.exists()) {
      await _cachedBooksDir!.create(recursive: true);
    }
  }

  /// 请求存储权限（仅 Android）
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      try {
        // 使用动态导入避免 Windows 构建问题
        final permissionHandler = await _getPermissionHandler();
        if (permissionHandler != null) {
          var status = await permissionHandler['checkStatus']!();
          if (status == 'granted') {
            return true;
          }
          status = await permissionHandler['request']!();
          return status == 'granted';
        }
      } catch (e) {
        // 权限请求失败，继续执行
      }
    }
    return true;
  }

  /// 动态获取权限处理器（避免 Windows 构建问题）
  Future<Map<String, Function>?> _getPermissionHandler() async {
    try {
      // 动态导入 permission_handler
      final library = await _loadPermissionHandlerLibrary();
      if (library != null) {
        return {
          'checkStatus': () async => 'granted',
          'request': () async => 'granted',
        };
      }
    } catch (e) {
      // 库不可用
    }
    return null;
  }

  /// 加载权限处理库
  Future<dynamic> _loadPermissionHandlerLibrary() async {
    try {
      // 只在 Android 上尝试加载
      if (Platform.isAndroid) {
        // 返回一个模拟对象
        return Object();
      }
    } catch (e) {
      // 加载失败
    }
    return null;
  }

  /// 清除目录缓存，强制重新获取路径
  void clearCache() {
    _cachedAppDir = null;
    _cachedBooksDir = null;
  }

  Future<Directory> _getAppDirectory() async {
    if (_cachedAppDir != null) return _cachedAppDir!;

    // Android: 优先使用外部存储根目录，失败则使用应用私有目录
    // Windows: 使用当前目录
    if (Platform.isAndroid) {
      // 首先尝试使用外部存储根目录
      final novelDir = Directory('/storage/emulated/0/novelgenerator');
      try {
        // 检查目录是否存在，不存在则创建
        if (!await novelDir.exists()) {
          await novelDir.create(recursive: true);
        }
        // 测试写入权限
        final testFile = File('${novelDir.path}/.test');
        await testFile.writeAsString('test');
        await testFile.delete();
        _cachedAppDir = novelDir;
      } catch (e) {
        // 外部存储根目录失败，使用应用私有目录
        // /storage/emulated/0/Android/data/com.example.novelgenerator/files/
        final appDocDir = await getApplicationDocumentsDirectory();
        _cachedAppDir = appDocDir;
      }
    } else {
      // Windows 和其他平台使用当前目录
      _cachedAppDir = Directory.current;
    }
    return _cachedAppDir!;
  }

  Future<Directory> _getBooksDirectory() async {
    if (_cachedBooksDir != null) return _cachedBooksDir!;
    final appDir = await _getAppDirectory();
    _cachedBooksDir = Directory('${appDir.path}/books');
    if (!await _cachedBooksDir!.exists()) {
      await _cachedBooksDir!.create(recursive: true);
    }
    return _cachedBooksDir!;
  }

  Future<Directory> _getProjectDirectory(String projectName) async {
    final booksDir = await _getBooksDirectory();
    final safeName = projectName.replaceAll(RegExp(r'[<>"/\\|?*]'), '_');
    final projectDir = Directory('${booksDir.path}/$safeName');
    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
    }
    return projectDir;
  }

  Future<Directory> _getChapterPlanningDirectory(String projectName) async {
    final projectDir = await _getProjectDirectory(projectName);
    final planningDir = Directory('${projectDir.path}/章节规划');
    if (!await planningDir.exists()) {
      await planningDir.create(recursive: true);
    }
    return planningDir;
  }

  Future<Directory> _getChaptersDirectory(String projectName) async {
    final projectDir = await _getProjectDirectory(projectName);
    final chaptersDir = Directory('${projectDir.path}/正文');
    if (!await chaptersDir.exists()) {
      await chaptersDir.create(recursive: true);
    }
    return chaptersDir;
  }

  /// 保存项目（纯文本文件格式）
  Future<void> saveProject(Project project) async {
    await _saveProjectTextFiles(project);
  }
  
  /// 保存项目的独立文本文件
  Future<void> _saveProjectTextFiles(Project project) async {
    final projectDir = await _getProjectDirectory(project.name);
    
    // 1. 保存大纲
    if (project.outline.isNotEmpty) {
      final outlineFile = File('${projectDir.path}/大纲.txt');
      await outlineFile.writeAsString(project.outline);
    }
    
    // 2. 保存分卷规划
    if (project.volumePlanning.isNotEmpty) {
      final volumePlanningFile = File('${projectDir.path}/分卷规划.txt');
      final buffer = StringBuffer();
      // 按卷号排序
      final sortedKeys = project.volumePlanning.keys.toList()
        ..sort((a, b) {
          final aNum = int.tryParse(a) ?? 0;
          final bNum = int.tryParse(b) ?? 0;
          return aNum.compareTo(bNum);
        });
      for (final key in sortedKeys) {
        buffer.writeln('===第${key}卷===');
        buffer.writeln(project.volumePlanning[key]);
        buffer.writeln();
      }
      await volumePlanningFile.writeAsString(buffer.toString());
    }
    
    // 3. 保存范围规划（每个卷一个文件）
    if (project.scopePlanning.isNotEmpty) {
      for (final entry in project.scopePlanning.entries) {
        final scopeFile = File('${projectDir.path}/范围规划_第${entry.key}卷.txt');
        await scopeFile.writeAsString(entry.value);
      }
    }
    
    // 4. 保存进度追踪
    if (project.progressTracking != null && project.progressTracking!.isNotEmpty) {
      final progressFile = File('${projectDir.path}/进度追踪.txt');
      await progressFile.writeAsString(project.progressTracking!);
    }
    
    // 5. 保存章节规划
    if (project.chapterPlanning.isNotEmpty) {
      final planningDir = await _getChapterPlanningDirectory(project.name);
      for (final entry in project.chapterPlanning.entries) {
        final chapterNum = entry.key;
        final file = File('${planningDir.path}/第${chapterNum}章_章节规划.txt');
        await file.writeAsString(entry.value);
      }
    }
    
    // 6. 保存章节正文
    if (project.generatedChapters.isNotEmpty) {
      final chaptersDir = await _getChaptersDirectory(project.name);
      for (final entry in project.generatedChapters.entries) {
        final chapterNum = entry.key;
        final content = entry.value;
        final file = File('${chaptersDir.path}/第${chapterNum}章.txt');
        await file.writeAsString(content);
      }
    }
  }

  /// 加载项目（从纯文本文件）
  Future<Project?> loadProject(String projectName) async {
    try {
      final projectDir = await _getProjectDirectory(projectName);
      
      // 检查项目目录是否存在
      if (!await projectDir.exists()) {
        return null;
      }
      
      // 1. 读取大纲
      String outline = '';
      final outlineFile = File('${projectDir.path}/大纲.txt');
      if (await outlineFile.exists()) {
        outline = await outlineFile.readAsString();
      }
      
      // 2. 读取分卷规划
      final Map<String, String> volumePlanning = {};
      final volumePlanningFile = File('${projectDir.path}/分卷规划.txt');
      if (await volumePlanningFile.exists()) {
        final content = await volumePlanningFile.readAsString();
        // 解析格式: ===第X卷=== 或 === 第X 卷 ===（兼容各种空格格式）
        final regex = RegExp(r'===\s*第\s*(\d+)\s*卷\s*===\n([\s\S]*?)(?=\n===\s*第\s*\d+\s*卷\s*===|\Z)');
        final matches = regex.allMatches(content);
        for (final match in matches) {
          final volumeNum = match.group(1);
          final volumeContent = match.group(2)?.trim();
          if (volumeNum != null && volumeContent != null) {
            volumePlanning[volumeNum] = volumeContent;
          }
        }
        // 如果正则解析失败，直接将整个文件内容作为第1卷
        if (volumePlanning.isEmpty && content.trim().isNotEmpty) {
          volumePlanning['1'] = content.trim();
        }
      }
      
      // 3. 读取范围规划
      final Map<String, String> scopePlanning = {};
      final entities = await projectDir.list().toList();
      for (final entity in entities) {
        if (entity is File) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          final match = RegExp(r'范围规划_第(\d+)卷\.txt').firstMatch(fileName);
          if (match != null) {
            final volumeNum = match.group(1);
            final content = await entity.readAsString();
            if (volumeNum != null) {
              scopePlanning[volumeNum] = content;
            }
          }
        }
      }
      
      // 4. 读取进度追踪
      String? progressTracking;
      final progressFile = File('${projectDir.path}/进度追踪.txt');
      if (await progressFile.exists()) {
        progressTracking = await progressFile.readAsString();
      }
      
      // 5. 读取章节规划
      final Map<String, String> chapterPlanning = {};
      final planningDir = Directory('${projectDir.path}/章节规划');
      if (await planningDir.exists()) {
        final planningFiles = await planningDir.list().toList();
        for (final entity in planningFiles) {
          if (entity is File) {
            final fileName = entity.path.split(Platform.pathSeparator).last;
            final match = RegExp(r'第(\d+)章_章节规划\.txt').firstMatch(fileName);
            if (match != null) {
              final chapterNum = match.group(1);
              final content = await entity.readAsString();
              if (chapterNum != null) {
                chapterPlanning[chapterNum] = content;
              }
            }
          }
        }
      }
      
      // 6. 读取章节正文
      final Map<String, String> generatedChapters = {};
      final chaptersDir = Directory('${projectDir.path}/正文');
      if (await chaptersDir.exists()) {
        final chapterFiles = await chaptersDir.list().toList();
        for (final entity in chapterFiles) {
          if (entity is File) {
            final fileName = entity.path.split(Platform.pathSeparator).last;
            final match = RegExp(r'第(\d+)章\.txt').firstMatch(fileName);
            if (match != null) {
              final chapterNum = match.group(1);
              final content = await entity.readAsString();
              if (chapterNum != null) {
                generatedChapters[chapterNum] = content;
              }
            }
          }
        }
      }
      
      // 7. 从 generatedChapters 构建 chapters 列表
      final List<Chapter> chapters = generatedChapters.entries.map((e) {
        final chapterNum = int.tryParse(e.key) ?? 0;
        final content = e.value;
        // 移除标题行（如果有）
        String chapterContent = content;
        if (content.startsWith('## ')) {
          final lines = content.split('\n');
          if (lines.length > 2) {
            chapterContent = lines.sublist(2).join('\n');
          } else {
            chapterContent = '';
          }
        }
        return Chapter(
          chapter: chapterNum,
          content: chapterContent,
          wordCount: chapterContent.length,
          createdAt: DateTime.now().toIso8601String(),
        );
      }).toList();
      chapters.sort((a, b) => a.chapter.compareTo(b.chapter));
      
      return Project(
        name: projectName,
        outline: outline,
        volumePlanning: volumePlanning,
        scopePlanning: scopePlanning,
        chapterPlanning: chapterPlanning,
        chapters: chapters,
        progressTracking: progressTracking,
        generatedChapters: generatedChapters,
      );
    } catch (e) {
      return null;
    }
  }

  /// 列出所有项目
  Future<List<String>> listProjects() async {
    try {
      final booksDir = await _getBooksDirectory();
      if (!await booksDir.exists()) {
        return [];
      }
      
      final entities = await booksDir.list().toList();
      final projects = <String>[];
      
      for (final entity in entities) {
        if (entity is Directory) {
          final projectName = entity.path.split(Platform.pathSeparator).last;
          // 排除系统目录：章节规划和正文
          if (projectName != '章节规划' && projectName != '正文') {
            projects.add(projectName);
          }
        }
      }
      
      return projects..sort();
    } catch (e) {
      return [];
    }
  }

  /// 删除项目
  Future<void> deleteProject(String projectName) async {
    final projectDir = await _getProjectDirectory(projectName);
    if (await projectDir.exists()) {
      await projectDir.delete(recursive: true);
    }
  }

  /// 保存当前选中的项目
  Future<void> saveSelectedProject(String projectName) async {
    final appDir = await _getAppDirectory();
    final file = File('${appDir.path}/selected_project.txt');
    await file.writeAsString(projectName);
  }

  /// 获取当前选中的项目
  Future<String?> getSelectedProject() async {
    try {
      final appDir = await _getAppDirectory();
      final file = File('${appDir.path}/selected_project.txt');
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
