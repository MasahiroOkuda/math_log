import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:math_log/core/theme/app_theme.dart';
import 'package:math_log/domain/entities/unit_achievement.dart';
import 'package:math_log/models/question.dart';
import 'package:math_log/services/database_service.dart';
import 'package:math_log/services/question_service.dart';
import 'package:math_log/screens/log_input_screen.dart';
import 'package:math_log/services/workbook_filter_service.dart';

class UnitDetailScreen extends StatefulWidget {
  final UnitAchievement unit;
  final List<UnitAchievement> allUnits;
  final String selectedSource;
  final String? studentId;
  final bool isReadOnly;

  const UnitDetailScreen({
    Key? key,
    required this.unit,
    required this.allUnits,
    required this.selectedSource,
    this.studentId,
    this.isReadOnly = false,
  }) : super(key: key);

  @override
  State<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends State<UnitDetailScreen> {
  bool _isSaving = false;
  final Map<String, QuestionBatchState> _batchStates = {};
  final List<LogInputResult> _sessionResults = [];
  late List<Question> _filteredQuestions;

  late Stream<DocumentSnapshot<Map<String, dynamic>>> _ratingsStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _logsStream;
  late ValueNotifier<List<QuestionBatchState>> _attemptedQuestionsNotifier;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _ratingsStream = DatabaseService().getRatingsStream(uid: widget.studentId);
    _logsStream = DatabaseService().getLogsStream(uid: widget.studentId);
    _scrollController = ScrollController();

    // filteredQuestions を事前に取得してキャッシュ
    final questions = QuestionService().questions;
    _filteredQuestions = questions
        .where((q) => q.unitId == widget.unit.id && 
                      WorkbookFilterService().isActive(q.source))
        .toList()
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
          resultType: item.resultType,
          mistakeReasons: item.mistakeReasons,
        );
      }).toList();

      // Clear batch states after successful save
      for (var state in attemptedList) {
        state.cycleState = 0;
        state.mistakeReasons.clear();
      }
      _attemptedQuestionsNotifier.value = []; // Notifierもクリア

      setState(() {}); // 画面全体の表示（枠線リセットなど）を反映

      // Add to session results
      _sessionResults.addAll(results);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${batchItems.length}件の学習ログを一括保存しました'),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _sessionResults);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.unit.id}: ${widget.unit.name}'),
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              Navigator.pop(context, _sessionResults);
            },
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // 1. Abilities Radar Chart (Real-time Firestore ratings)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: _ratingsStream,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              );
                            }

                            Map<String, dynamic> ratings = {};
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final data = snapshot.data!.data();
                              ratings = data?['ratings'] as Map<String, dynamic>? ?? {};
                            }

                            final unitRating = ratings[widget.unit.id] as Map<String, dynamic>? ?? {
                              'knowledge': 500,
                              'strategy': 500,
                              'calculation': 500,
                              'reading': 500,
                            };

                            final int knowledge = (unitRating['knowledge'] as num?)?.toInt() ?? 500;
                            final int strategy = (unitRating['strategy'] as num?)?.toInt() ?? 500;
                            final int calculation = (unitRating['calculation'] as num?)?.toInt() ?? 500;
                            final int reading = (unitRating['reading'] as num?)?.toInt() ?? 500;

                            return _buildRadarChartCard(knowledge, strategy, calculation, reading);
                          },
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          children: [
                            Text(
                              '問題一覧',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
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
                                'この単元に対応する問題がありません。',
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

                                return QuestionListItem(
                                  key: ValueKey(question.id),
                                  question: question,
                                  state: state,
                                  latestLog: latestLog,
                                  allUnits: widget.allUnits,
                                  isSaving: _isSaving,
                                  isReadOnly: widget.isReadOnly,
                                  onStateChanged: () {
                                    _attemptedQuestionsNotifier.value = _batchStates.values.where((s) => s.isAttempted).toList();
                                  },
                                  onSessionResultAdded: (result) {
                                    _sessionResults.add(result);
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
      ),
    );
  }

  Widget _buildBatchSaveButton(List<QuestionBatchState> attemptedList) {
    if (widget.isReadOnly) return const SizedBox.shrink();
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

  Widget _buildRadarChartCard(int knowledge, int strategy, int calculation, int reading) {
    return Card(
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF334155), width: 1),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '単元レート分析',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: RadarChart(
                RadarChartData(
                  dataSets: [
                    RadarDataSet(
                      dataEntries: const [
                        RadarEntry(value: 1000),
                        RadarEntry(value: 1000),
                        RadarEntry(value: 1000),
                        RadarEntry(value: 1000),
                      ],
                      borderColor: Colors.transparent,
                      fillColor: Colors.transparent,
                      entryRadius: 0,
                    ),
                    RadarDataSet(
                      dataEntries: const [
                        RadarEntry(value: 1800),
                        RadarEntry(value: 1800),
                        RadarEntry(value: 1800),
                        RadarEntry(value: 1800),
                      ],
                      borderColor: Colors.transparent,
                      fillColor: Colors.transparent,
                      entryRadius: 0,
                    ),
                    RadarDataSet(
                      dataEntries: [
                        RadarEntry(value: knowledge.toDouble()),
                        RadarEntry(value: strategy.toDouble()),
                        RadarEntry(value: calculation.toDouble()),
                        RadarEntry(value: reading.toDouble()),
                      ],
                      borderColor: AppTheme.primaryColor,
                      fillColor: AppTheme.primaryColor.withOpacity(0.2),
                      entryRadius: 4,
                      borderWidth: 2,
                    ),
                  ],
                  getTitle: (index, angle) {
                    switch (index) {
                      case 0:
                        return const RadarChartTitle(text: '知識');
                      case 1:
                        return const RadarChartTitle(text: '方針');
                      case 2:
                        return const RadarChartTitle(text: '計算');
                      case 3:
                        return const RadarChartTitle(text: '読解');
                      default:
                        return const RadarChartTitle(text: '');
                    }
                  },
                  titleTextStyle: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  tickCount: 4,
                  ticksTextStyle: const TextStyle(color: Colors.white30, fontSize: 8),
                  gridBorderData: const BorderSide(color: Color(0xFF334155), width: 1),
                  tickBorderData: const BorderSide(color: Color(0xFF1E293B), width: 1),
                  radarBorderData: const BorderSide(color: Color(0xFF475569), width: 1.5),
                  radarShape: RadarShape.polygon,
                  isMinValueAtCenter: false,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCompactLegend('知識', knowledge, AppTheme.knowledgeColor),
                _buildCompactLegend('方針', strategy, AppTheme.strategyColor),
                _buildCompactLegend('計算', calculation, AppTheme.calculationColor),
                _buildCompactLegend('読解', reading, AppTheme.readingColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactLegend(String label, int value, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}

class QuestionListItem extends StatefulWidget {
  final Question question;
  final QuestionBatchState state;
  final Map<String, dynamic>? latestLog;
  final List<UnitAchievement> allUnits;
  final bool isSaving;
  final bool isReadOnly;
  final VoidCallback onStateChanged;
  final ValueChanged<LogInputResult> onSessionResultAdded;

  const QuestionListItem({
    required Key key,
    required this.question,
    required this.state,
    required this.latestLog,
    required this.allUnits,
    required this.isSaving,
    required this.isReadOnly,
    required this.onStateChanged,
    required this.onSessionResultAdded,
  }) : super(key: key);

  @override
  State<QuestionListItem> createState() => _QuestionListItemState();
}

class _QuestionListItemState extends State<QuestionListItem> {
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
        lastResultColor = const Color(0xFF34D399); // GreenAccent
      } else if (resultType == 'defeat') {
        lastResultText = '前回結果: ✕';
        lastResultColor = const Color(0xFFF87171); // RedAccent
      } else if (resultType == 'partial') {
        final reasons = List<String>.from(latestLog['mistakeReasons'] ?? []);
        lastResultText = '前回結果: △' + (reasons.isNotEmpty ? '（${reasons.join('・')}）' : '');
        lastResultColor = const Color(0xFFFBBF24); // AmberAccent
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
                onTap: widget.isReadOnly || widget.isSaving
                    ? null
                    : () async {
                  final result = await Navigator.push<dynamic>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LogInputScreen(
                        units: widget.allUnits,
                        initialQuestion: question,
                      ),
                    ),
                  );
                  if (result != null && result is LogInputResult) {
                    setState(() {
                      state.cycleState = result.resultType == 'perfect'
                          ? 1
                          : (result.resultType == 'defeat' ? 2 : 3);
                      state.mistakeReasons.clear();
                      if (result.mistakeReasons != null) {
                        state.mistakeReasons.addAll(result.mistakeReasons!);
                      }
                    });
                    widget.onSessionResultAdded(result);
                    widget.onStateChanged();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.questionNumberAndLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        question.source,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
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
      onTap: widget.isReadOnly || widget.isSaving
          ? null
          : () {
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
