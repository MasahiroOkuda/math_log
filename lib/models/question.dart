class Question {
  final String id; // Question_ID
  final String chapterSection; // 章・セクション
  final String questionNumberAndLabel; // 問題番号・表記
  final String source; // 収録元
  final String unitId; // Unit_ID
  final int knowledgeLevel; // 知識Lv
  final int strategyLevel; // 方針Lv
  final int calculationLevel; // 計算Lv
  final int readingLevel; // 読解Lv
  final int difficultyTag; // 難易度タグ

  Question({
    required this.id,
    required this.chapterSection,
    required this.questionNumberAndLabel,
    required this.source,
    required this.unitId,
    required this.knowledgeLevel,
    required this.strategyLevel,
    required this.calculationLevel,
    required this.readingLevel,
    required this.difficultyTag,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['Question_ID'] as String? ?? '',
      chapterSection: json['章・セクション'] as String? ?? '',
      questionNumberAndLabel: json['問題番号・表記'] as String? ?? '',
      source: json['収録元'] as String? ?? '',
      unitId: json['Unit_ID'] as String? ?? '',
      knowledgeLevel: json['知識Lv'] as int? ?? 1,
      strategyLevel: json['方針Lv'] as int? ?? 1,
      calculationLevel: json['計算Lv'] as int? ?? 1,
      readingLevel: json['読解Lv'] as int? ?? 1,
      difficultyTag: json['難易度タグ'] as int? ?? 1,
    );
  }
}
