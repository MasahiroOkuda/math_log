import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:math_log/core/theme/app_theme.dart';
import 'package:math_log/models/question.dart';
import 'package:math_log/services/question_service.dart';
import 'package:math_log/services/database_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate().toLocal();
    final year = dt.year;
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$year/$month/$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final user = DatabaseService().currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('学習履歴'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: user == null
              ? Stream.error(StateError('User not logged in'))
              : FirebaseFirestore.instance
                  .collection('logs')
                  .where('uid', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'エラーが発生しました: ${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      size: 64,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '学習履歴がまだありません。',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final logData = docs[index].data();
                final createdAt = logData['createdAt'] as Timestamp?;
                final questionId = logData['questionId'] as String? ?? '';
                final resultType = logData['resultType'] as String? ?? '';
                final mistakeReasons = List<String>.from(logData['mistakeReasons'] ?? []);

                // Find question info
                final question = QuestionService().questions.firstWhere(
                      (q) => q.id == questionId,
                      orElse: () => Question(
                        id: questionId,
                        chapterSection: '不明なセクション',
                        questionNumberAndLabel: '不明な問題',
                        source: '不明な問題集',
                        unitId: '',
                        knowledgeLevel: 1,
                        strategyLevel: 1,
                        calculationLevel: 1,
                        readingLevel: 1,
                        difficultyTag: 1,
                      ),
                    );

                // Set up result visual parameters
                IconData resultIcon;
                Color resultColor;
                String resultSymbol;
                String resultText;

                if (resultType == 'perfect') {
                  resultIcon = Icons.check_circle_outline_rounded;
                  resultColor = AppTheme.primaryColor;
                  resultSymbol = '〇';
                  resultText = '完璧に解けた';
                } else if (resultType == 'defeat') {
                  resultIcon = Icons.cancel_outlined;
                  resultColor = Colors.redAccent;
                  resultSymbol = '✕';
                  resultText = '完全敗北';
                } else { // partial
                  resultIcon = Icons.help_outline_rounded;
                  resultColor = Colors.amberAccent;
                  resultSymbol = '△';
                  resultText = mistakeReasons.isNotEmpty
                      ? '間違えた（${mistakeReasons.join('・')}）'
                      : '間違えた';
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row containing date and result badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatTimestamp(createdAt),
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: resultColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: resultColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    resultIcon,
                                    color: resultColor,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    resultSymbol,
                                    style: TextStyle(
                                      color: resultColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Question description
                        Text(
                          '${question.id}: ${question.questionNumberAndLabel}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Source and chapter info
                        Text(
                          '${question.source}  -  ${question.chapterSection}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (resultType == 'partial') ...[
                          const SizedBox(height: 8),
                          Text(
                            resultText,
                            style: TextStyle(
                              color: resultColor.withOpacity(0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
