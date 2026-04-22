class Chapter {
  final int chapter;
  final String content;
  final int wordCount;
  final String createdAt;
  final String? updatedAt;

  Chapter({
    required this.chapter,
    required this.content,
    required this.wordCount,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'chapter': chapter,
      'content': content,
      'wordCount': wordCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      chapter: json['chapter'],
      content: json['content'],
      wordCount: json['wordCount'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }
}

class Project {
  final String name;
  final String outline;
  final Map<String, String> volumePlanning;
  final Map<String, String> scopePlanning;
  final Map<String, String> chapterPlanning;
  final List<Chapter> chapters;
  final Map<String, String> generatedChapters;
  final String? progressTracking;

  Project({
    required this.name,
    this.outline = '',
    Map<String, String>? volumePlanning,
    Map<String, String>? scopePlanning,
    Map<String, String>? chapterPlanning,
    List<Chapter>? chapters,
    Map<String, String>? generatedChapters,
    this.progressTracking,
  })  : volumePlanning = volumePlanning ?? {},
        scopePlanning = scopePlanning ?? {},
        chapterPlanning = chapterPlanning ?? {},
        chapters = chapters ?? [],
        generatedChapters = generatedChapters ?? {};

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'outline': outline,
      'volumePlanning': volumePlanning,
      'scopePlanning': scopePlanning,
      'chapterPlanning': chapterPlanning,
      'chapters': chapters.map((c) => c.toJson()).toList(),
      'generatedChapters': generatedChapters,
      'progressTracking': progressTracking,
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      name: json['name'],
      outline: json['outline'] ?? '',
      volumePlanning: Map<String, String>.from(json['volumePlanning'] ?? {}),
      scopePlanning: Map<String, String>.from(json['scopePlanning'] ?? {}),
      chapterPlanning: Map<String, String>.from(json['chapterPlanning'] ?? {}),
      chapters: (json['chapters'] as List?)
              ?.map((c) => Chapter.fromJson(c))
              .toList() ??
          [],
      generatedChapters: Map<String, String>.from(json['generatedChapters'] ?? {}),
      progressTracking: json['progressTracking'],
    );
  }

  Project copyWith({
    String? name,
    String? outline,
    Map<String, String>? volumePlanning,
    Map<String, String>? scopePlanning,
    Map<String, String>? chapterPlanning,
    List<Chapter>? chapters,
    Map<String, String>? generatedChapters,
    String? progressTracking,
  }) {
    return Project(
      name: name ?? this.name,
      outline: outline ?? this.outline,
      volumePlanning: volumePlanning ?? Map<String, String>.from(this.volumePlanning),
      scopePlanning: scopePlanning ?? Map<String, String>.from(this.scopePlanning),
      chapterPlanning: chapterPlanning ?? Map<String, String>.from(this.chapterPlanning),
      chapters: chapters ?? List<Chapter>.from(this.chapters),
      generatedChapters: generatedChapters ?? Map<String, String>.from(this.generatedChapters),
      progressTracking: progressTracking ?? this.progressTracking,
    );
  }
}
