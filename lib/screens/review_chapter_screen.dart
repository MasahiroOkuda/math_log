import 'package:flutter/material.dart';
import 'package:math_log/core/theme/app_theme.dart';
import 'package:math_log/models/question.dart';
import 'package:math_log/models/user_log.dart';
import 'review_question_list_screen.dart';

class ReviewChapterScreen extends StatelessWidget {
  final String workbookName;
  final List<Question> workbookQuestions;
  final List<UserLog> allLogs;

  const ReviewChapterScreen({
    Key? key,
    required this.workbookName,
    required this.workbookQuestions,
    required this.allLogs,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Group questions by chapterSection
    final Map<String, List<Question>> chapterQuestionsMap = {};
    for (var q in workbookQuestions) {
      chapterQuestionsMap.putIfAbsent(q.chapterSection, () => []).add(q);
    }

    final chapterNames = chapterQuestionsMap.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(workbookName),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: chapterNames.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 64,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '章・セクションが見つかりません。',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: chapterNames.length,
                itemBuilder: (context, index) {
                  final chapterName = chapterNames[index];
                  final questions = chapterQuestionsMap[chapterName] ?? [];
                  final totalQuestions = questions.length;

                  // Calculate progress for this chapter
                  final chapterQuestionIds = questions.map((q) => q.id).toSet();
                  final chapterLogs = allLogs.where((log) => chapterQuestionIds.contains(log.questionId)).toList();
                  final perfectQuestionIds = chapterLogs
                      .where((log) => log.resultType == 'perfect')
                      .map((log) => log.questionId)
                      .toSet();

                  final perfectCount = perfectQuestionIds.length;
                  final double progressPercent = totalQuestions > 0 ? perfectCount / totalQuestions : 0.0;
                  final String percentText = (progressPercent * 100).toStringAsFixed(0);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155), width: 1),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReviewQuestionListScreen(
                                workbookName: workbookName,
                                chapterName: chapterName,
                                chapterQuestions: questions,
                                allLogs: allLogs,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      chapterName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.white38,
                                    size: 24,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '習得率: $perfectCount / $totalQuestions 問完璧 ($percentText%)',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0F172A),
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: progressPercent.clamp(0.0, 1.0),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          gradient: AppTheme.progressGradient,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
