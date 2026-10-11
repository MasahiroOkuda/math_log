import 'package:flutter/material.dart';
import 'package:math_log/core/theme/app_theme.dart';
import 'package:math_log/models/question.dart';
import 'package:math_log/models/user_log.dart';

class ReviewQuestionListScreen extends StatelessWidget {
  final String workbookName;
  final String chapterName;
  final List<Question> chapterQuestions;
  final List<UserLog> allLogs;

  const ReviewQuestionListScreen({
    Key? key,
    required this.workbookName,
    required this.chapterName,
    required this.chapterQuestions,
    required this.allLogs,
  }) : super(key: key);

  Widget _buildTimelineChip(int index, UserLog log) {
    Color color;
    String symbol;
    if (log.resultType == 'perfect') {
      color = const Color(0xFF10B981); // Emerald Green (〇)
      symbol = '〇';
    } else if (log.resultType == 'partial') {
      color = const Color(0xFFF59E0B); // Amber (△)
      symbol = '△';
    } else {
      color = const Color(0xFFEF4444); // Red (✕)
      symbol = '✕';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${index}回目: ',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            symbol,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (log.resultType == 'partial' && log.mistakeReasons.isNotEmpty) ...[
            Text(
              ' (${log.mistakeReasons.join('・')})',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sort questions by their ID or number to keep a logical order
    final sortedQuestions = List<Question>.from(chapterQuestions)
      ..sort((a, b) => a.id.compareTo(b.id));

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          key: const PageStorageKey('review_question_list_scroll_key'),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 90.0,
              backgroundColor: AppTheme.backgroundColor,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
                title: Text(
                  chapterName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList(
                key: const PageStorageKey('review_question_sliver_list_key'),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final question = sortedQuestions[index];

                    // Filter logs for this specific question
                    final questionLogs = allLogs.where((log) => log.questionId == question.id).toList();

                    // Sort logs by createdAt ascending (oldest first)
                    questionLogs.sort((a, b) => a.createdAt.compareTo(b.createdAt));

                    // Build timeline widgets
                    final List<Widget> timelineWidgets = [];
                    for (int i = 0; i < questionLogs.length; i++) {
                      if (i > 0) {
                        timelineWidgets.add(
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 12,
                              color: Colors.white24,
                            ),
                          ),
                        );
                      }
                      timelineWidgets.add(_buildTimelineChip(i + 1, questionLogs[i]));
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF334155), width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${question.id}: ${question.questionNumberAndLabel}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // Skill levels indicator row
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '難易度: ${question.difficultyTag}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Show details of the levels
                            Row(
                              children: [
                                _buildSkillBadge('知識', question.knowledgeLevel, AppTheme.knowledgeColor),
                                const SizedBox(width: 6),
                                _buildSkillBadge('方針', question.strategyLevel, AppTheme.strategyColor),
                                const SizedBox(width: 6),
                                _buildSkillBadge('計算', question.calculationLevel, AppTheme.calculationColor),
                                const SizedBox(width: 6),
                                _buildSkillBadge('読解', question.readingLevel, AppTheme.readingColor),
                              ],
                            ),
                            const Divider(color: Color(0xFF334155), height: 24),
                            const Text(
                              '解答履歴',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            timelineWidgets.isEmpty
                                ? const Text(
                                    '解答履歴がありません（未着手）',
                                    style: TextStyle(
                                      color: Colors.white30,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                : Wrap(
                                    spacing: 4,
                                    runSpacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: timelineWidgets,
                                  ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: sortedQuestions.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillBadge(String name, int level, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        '$name Lv.$level',
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
