import 'package:flutter/material.dart';
import 'package:math_log/core/theme/app_theme.dart';
import 'package:math_log/models/question.dart';
import 'package:math_log/services/question_service.dart';
import 'package:math_log/services/database_service.dart';
import 'package:math_log/screens/log_input_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionSelectionScreen extends StatefulWidget {
  final String source;
  final String chapterSection;

  const QuestionSelectionScreen({
    Key? key,
    required this.source,
    required this.chapterSection,
  }) : super(key: key);

  @override
  State<QuestionSelectionScreen> createState() => _QuestionSelectionScreenState();
}

class _QuestionSelectionScreenState extends State<QuestionSelectionScreen> {
  bool _isSaving = false;
  final Map<String, QuestionBatchState> _batchStates = {};
  late List<Question> _filteredQuestions;
  late final ScrollController _scrollController;
  late ValueNotifier<List<QuestionBatchState>> _attemptedQuestionsNotifier;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _logsStream;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _logsStream = DatabaseService().getLogsStream();

    final questions = QuestionService().questions;
    _filteredQuestions = questions.where((q) {
      return q.source == widget.source && q.chapterSection == widget.chapterSection;
    }).toList()
      ..sort((a, b) {
        final sourceCmp = a.source.compareTo(b.source);
        if (sourceCmp != 0) return sourceCmp;
        return a.id.compareTo(b.id);
      });

    List<QuestionBatchState> initialAttempted = [];
    for (var q in _filteredQuestions) {
      final state = QuestionBatchState(question: q);
      _batchStates[q.id] = state;
      if (state.isAttempted) {
        initialAttempted.add(state);
      }
    }

    _attemptedQuestionsNotifier = ValueNotifier<List<QuestionBatchState>>(initialAttempted);
  }

  @override
  void dispose() {
    _attemptedQuestionsNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submitBatch() async {
    final attemptedList = _attemptedQuestionsNotifier.value;
    if (attemptedList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('変更された問題がありません。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final List<BatchLogItem> batchItems = attemptedList.map((state) {
        return BatchLogItem(
          question: state.question,
          resultType: state.resultType,
          mistakeReasons: List<String>.from(state.mistakeReasons),
        );
      }).toList();

      // Submit logs sequentially through DatabaseService
      await DatabaseService().submitBatchLogs(batchItems);

      // Create List<LogInputResult> sorted by Question ID in ascending order
      batchItems.sort((a, b) => a.question.id.compareTo(b.question.id));

      final results = batchItems.map((item) {
        return LogInputResult(
          unitId: item.question.unitId,
          questionNumber: item.question.questionNumberAndLabel,
          isCorrect: item.resultType == 'perfect',
          knowledgeLevel: item.question.knowledgeLevel,
          strategyLevel: item.question.strategyLevel,
          calculationLevel: item.question.calculationLevel,
          readingLevel: item.question.readingLevel,
        );
      }).toList();

      // Clear batch states after successful save
      for (var state in attemptedList) {
        state.cycleState = 0;
        state.mistakeReasons.clear();
      }
      _attemptedQuestionsNotifier.value = []; // Notifierもクリア
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${batchItems.length}件の学習ログを一括保存しました'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, results);
      }
    } catch (e) {
      debugPrint('Error saving batch logs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('一括保存に失敗しました: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('問題を選択'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Selected path info card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.menu_book_rounded, color: AppTheme.primaryColor, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.source,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.folder_open_rounded, color: AppTheme.secondaryColor, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.chapterSection,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _logsStream,
                    builder: (context, logsSnapshot) {
                      if (logsSnapshot.connectionState == ConnectionState.waiting) {
                        return const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      Map<String, Map<String, dynamic>> latestLogs = {};
                      if (logsSnapshot.hasData) {
                        for (var doc in logsSnapshot.data!.docs) {
                          final data = doc.data();
                          final questionId = data['questionId'] as String?;
                          if (questionId == null) continue;
                          final createdAt = data['createdAt'] as Timestamp?;
                          
                          final existing = latestLogs[questionId];
                          if (existing == null) {
                            latestLogs[questionId] = data;
                          } else {
                            final existingCreatedAt = existing['createdAt'] as Timestamp?;
                            if (createdAt == null) {
                              latestLogs[questionId] = data;
                            } else if (existingCreatedAt == null) {
                              // Keep existing
                            } else if (createdAt.compareTo(existingCreatedAt) > 0) {
                              latestLogs[questionId] = data;
                            }
                          }
                        }
                      }

                      if (_filteredQuestions.isEmpty) {
                        return const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              '該当する問題がありません。',
                              style: TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final question = _filteredQuestions[index];
                              final state = _batchStates[question.id]!;
                              final latestLog = latestLogs[question.id];

                              return QuestionSelectionListItem(
                                key: ValueKey(question.id),
                                question: question,
                                state: state,
                                latestLog: latestLog,
                                isSaving: _isSaving,
                                onStateChanged: () {
                                  _attemptedQuestionsNotifier.value = _batchStates.values.where((s) => s.isAttempted).toList();
                                },
                              );
                            },
                            childCount: _filteredQuestions.length,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<List<QuestionBatchState>>(
              valueListenable: _attemptedQuestionsNotifier,
              builder: (context, attemptedList, child) {
                return _buildBatchSaveButton(attemptedList);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchSaveButton(List<QuestionBatchState> attemptedList) {
    final bool isEnabled = attemptedList.isNotEmpty && !_isSaving;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        border: Border(
          top: BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isEnabled ? AppTheme.primaryGradient : null,
            color: isEnabled ? null : const Color(0xFF1E293B),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: ElevatedButton(
            onPressed: isEnabled ? _submitBatch : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    '変更された ${attemptedList.length} 問を一括保存',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class QuestionSelectionListItem extends StatefulWidget {
  final Question question;
  final QuestionBatchState state;
  final Map<String, dynamic>? latestLog;
  final bool isSaving;
  final VoidCallback onStateChanged;

  const QuestionSelectionListItem({
    required Key key,
    required this.question,
    required this.state,
    required this.latestLog,
    required this.isSaving,
    required this.onStateChanged,
  }) : super(key: key);

  @override
  State<QuestionSelectionListItem> createState() => _QuestionSelectionListItemState();
}

class _QuestionSelectionListItemState extends State<QuestionSelectionListItem> {
  void _showMistakeReasonsBottomSheet(QuestionBatchState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${state.question.questionNumberAndLabel} の原因分析',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...['知識', '方針', '計算', '読解'].map((reason) {
                    final isChecked = state.mistakeReasons.contains(reason);
                    Color checkboxColor;
                    switch (reason) {
                      case '知識':
                        checkboxColor = AppTheme.knowledgeColor;
                        break;
                      case '方針':
                        checkboxColor = AppTheme.strategyColor;
                        break;
                      case '計算':
                        checkboxColor = AppTheme.calculationColor;
                        break;
                      case '読解':
                        checkboxColor = AppTheme.readingColor;
                        break;
                      default:
                        checkboxColor = AppTheme.primaryColor;
                    }
                    return CheckboxListTile(
                      value: isChecked,
                      activeColor: checkboxColor,
                      title: Text(
                        reason,
                        style: TextStyle(
                          color: isChecked ? Colors.white : Colors.white70,
                          fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      onChanged: (bool? val) {
                        setSheetState(() {
                          if (val == true) {
                            if (!state.mistakeReasons.contains(reason)) {
                              state.mistakeReasons.add(reason);
                            }
                          } else {
                            state.mistakeReasons.remove(reason);
                          }
                        });
                        setState(() {});
                        widget.onStateChanged();
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('決定'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    final state = widget.state;
    final latestLog = widget.latestLog;

    String lastResultText = '初回';
    Color lastResultColor = Colors.white54;

    if (latestLog != null) {
      final resultType = latestLog['resultType'] as String?;
      if (resultType == 'perfect') {
        lastResultText = '前回結果: 〇';
        lastResultColor = const Color(0xFF34D399);
      } else if (resultType == 'defeat') {
        lastResultText = '前回結果: ✕';
        lastResultColor = const Color(0xFFF87171);
      } else if (resultType == 'partial') {
        final reasons = List<String>.from(latestLog['mistakeReasons'] ?? []);
        lastResultText = '前回結果: △' + (reasons.isNotEmpty ? '（${reasons.join('・')}）' : '');
        lastResultColor = const Color(0xFFFBBF24);
      }
    }

    Color borderColor = const Color(0xFF334155);
    if (state.cycleState == 1) {
      borderColor = const Color(0xFF34D399).withOpacity(0.5);
    } else if (state.cycleState == 2) {
      borderColor = const Color(0xFFF87171).withOpacity(0.5);
    } else if (state.cycleState == 3) {
      borderColor = const Color(0xFFFBBF24).withOpacity(0.5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: state.cycleState != 0 ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                onTap: () {
                  if (widget.isSaving) return;
                  Navigator.pop(context, question);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              question.questionNumberAndLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: lastResultColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: lastResultColor.withOpacity(0.3), width: 0.5),
                            ),
                            child: Text(
                              lastResultText,
                              style: TextStyle(
                                color: lastResultColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildCompactMetric('知識', question.knowledgeLevel, AppTheme.knowledgeColor),
                          _buildCompactMetric('方針', question.strategyLevel, AppTheme.strategyColor),
                          _buildCompactMetric('計算', question.calculationLevel, AppTheme.calculationColor),
                          _buildCompactMetric('読解', question.readingLevel, AppTheme.readingColor),
                        ],
                      ),
                      if (state.cycleState == 3 && state.mistakeReasons.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amberAccent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amberAccent.withOpacity(0.2)),
                          ),
                          child: Text(
                            '分析結果: ${state.mistakeReasons.join('・')}',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          Container(
            width: 1,
            height: 52,
            color: const Color(0xFF334155),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStateButton(state, 0, '未', Colors.grey.shade500),
                const SizedBox(width: 6),
                _buildStateButton(state, 1, '〇', const Color(0xFF34D399)),
                const SizedBox(width: 6),
                _buildStateButton(state, 3, '△', const Color(0xFFFBBF24)),
                const SizedBox(width: 6),
                _buildStateButton(state, 2, '✕', const Color(0xFFF87171)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateButton(QuestionBatchState state, int code, String label, Color activeColor) {
    final bool isSelected = state.cycleState == code;
    return GestureDetector(
      onTap: () {
        if (widget.isSaving) return;
        setState(() {
          state.cycleState = code;
          if (code == 3) {
            _showMistakeReasonsBottomSheet(state);
          } else {
            state.mistakeReasons.clear();
          }
        });
        widget.onStateChanged();
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.15) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFF475569),
            width: isSelected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : const Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMetric(String label, int level, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: TextStyle(color: color.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 2),
        Text(
          'Lv.$level',
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class QuestionBatchState {
  final Question question;
  int cycleState; // 0: unattempted, 1: perfect, 2: defeat, 3: partial
  final List<String> mistakeReasons;

  QuestionBatchState({
    required this.question,
    this.cycleState = 0,
    List<String>? mistakeReasons,
  }) : mistakeReasons = mistakeReasons ?? [];

  bool get isAttempted => cycleState != 0;

  String get resultType {
    if (cycleState == 1) return 'perfect';
    if (cycleState == 2) return 'defeat';
    if (cycleState == 3) return 'partial';
    return '';
  }
}
