import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum SkillType {
  knowledge,   // 知識
  strategy,    // 方針
  calculation, // 計算
  reading      // 読解
}

class SkillProgress {
  final SkillType type;
  final String label;
  final double value; // Value between 0.0 and 1.0
  final Color color;

  const SkillProgress({
    required this.type,
    required this.label,
    required this.value,
    required this.color,
  });

  // Helper to generate default dummy skills
  static List<SkillProgress> get defaultSkills => [
        const SkillProgress(
          type: SkillType.knowledge,
          label: '知識',
          value: 0.75,
          color: AppTheme.knowledgeColor,
        ),
        const SkillProgress(
          type: SkillType.strategy,
          label: '方針',
          value: 0.60,
          color: AppTheme.strategyColor,
        ),
        const SkillProgress(
          type: SkillType.calculation,
          label: '計算',
          value: 0.85,
          color: AppTheme.calculationColor,
        ),
        const SkillProgress(
          type: SkillType.reading,
          label: '読解',
          value: 0.50,
          color: AppTheme.readingColor,
        ),
      ];
}
