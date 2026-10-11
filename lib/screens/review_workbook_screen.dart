import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:math_log/core/theme/app_theme.dart';
import 'package:math_log/models/question.dart';
import 'package:math_log/models/user_log.dart';
import 'package:math_log/services/question_service.dart';
import 'review_chapter_screen.dart';
import 'package:math_log/services/workbook_filter_service.dart';

class ReviewWorkbookScreen extends StatefulWidget {
  final String? studentId;
  const ReviewWorkbookScreen({Key? key, this.studentId}) : super(key: key);

  @override
  State<ReviewWorkbookScreen> createState() => _ReviewWorkbookScreenState();
}

class _ReviewWorkbookScreenState extends State<ReviewWorkbookScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<UserLog> _allLogs = [];
  Map<String, List<Question>> _workbookQuestionsMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Ensure questions are loaded
      await QuestionService().loadQuestions();
      final questions = QuestionService().questions;

      // Group questions by workbook (source)
      final Map<String, List<Question>> workbookQuestionsMap = {};
      for (var q in questions) {
        workbookQuestionsMap.putIfAbsent(q.source, () => []).add(q);
      }

      // 2. Load all user logs from Firestore
      final targetUid = widget.studentId ?? FirebaseAuth.instance.currentUser?.uid;
      if (targetUid == null) {
        throw StateError('ログインユーザーが見つかりません。');
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('logs')
          .where('uid', isEqualTo: targetUid)
          .get();

      final logs = snapshot.docs.map((doc) => UserLog.fromFirestore(doc)).toList();

      if (mounted) {
        setState(() {
          _allLogs = logs;
          _workbookQuestionsMap = workbookQuestionsMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'データの読み込み中にエラーが発生しました: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学習履歴'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      );
    }

    if (_workbookQuestionsMap.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 64,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            const Text(
              '問題データが見つかりません。',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final workbooks = _workbookQuestionsMap.keys
        .where((src) => WorkbookFilterService().isActive(src))
        .toList()
      ..sort();

    if (workbooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 64,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            const Text(
              '有効になっている問題集がありません。',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: workbooks.length,
      itemBuilder: (context, index) {
        final workbookName = workbooks[index];
        final questions = _workbookQuestionsMap[workbookName] ?? [];
        final totalQuestions = questions.length;

        // Calculate progress for this workbook
        final workbookQuestionIds = questions.map((q) => q.id).toSet();
        final workbookLogs = _allLogs.where((log) => workbookQuestionIds.contains(log.questionId)).toList();
        final perfectQuestionIds = workbookLogs
            .where((log) => log.resultType == 'perfect')
            .map((log) => log.questionId)
            .toSet();

        final perfectCount = perfectQuestionIds.length;
        final double progressPercent = totalQuestions > 0 ? perfectCount / totalQuestions : 0.0;
        final String percentText = (progressPercent * 100).toStringAsFixed(0);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF334155), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReviewChapterScreen(
                      workbookName: workbookName,
                      workbookQuestions: questions,
                      allLogs: _allLogs,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            workbookName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                          '習得状況: $perfectCount / $totalQuestions 問完璧 ($percentText%)',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 8,
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
    );
  }
}
