import 'package:flutter/material.dart';
import 'package:math_log/domain/entities/skill_progress.dart';

class SkillsBarChart extends StatelessWidget {
  final List<SkillProgress> skills;

  const SkillsBarChart({
    Key? key,
    required this.skills,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '4つの数学能力レーダー',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: skills.map((skill) => _buildBar(context, skill)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(BuildContext context, SkillProgress skill) {
    final int displayValue = (skill.value * 100).toInt();
    const double maxBarHeight = 140.0;
    final double currentBarHeight = skill.value * maxBarHeight;

    return Column(
      children: [
        // Percentage Text above the bar
        Text(
          '$displayValue',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: skill.color,
                fontFamily: 'monospace',
              ),
        ),
        const SizedBox(height: 8),
        // The actual Bar
        Container(
          height: maxBarHeight,
          width: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF334155), // Slate 700
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: currentBarHeight,
                width: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      skill.color,
                      skill.color.withOpacity(0.6),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: skill.color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Skill Label below the bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: skill.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: skill.color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            skill.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }
}
