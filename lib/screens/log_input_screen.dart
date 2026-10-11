import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:math_log/core/theme/app_theme.dart';
import 'package:math_log/domain/entities/unit_achievement.dart';
import 'package:math_log/models/question.dart';
import 'package:math_log/services/database_service.dart';
import 'package:math_log/services/question_service.dart';
import 'package:math_log/screens/source_selection_screen.dart';

class LogInputResult {
  final String unitId;
  final String questionNumber;
  final bool isCorrect;
  final int knowledgeLevel;   // 1 to 4
  final int strategyLevel;    // 1 to 4
  final int calculationLevel; // 1 to 4
  final int readingLevel;    // 1 to 4
  final String? resultType;
  final List<String>? mistakeReasons;

  const LogInputResult({
    required this.unitId,
    required this.questionNumber,
    required this.isCorrect,
    required this.knowledgeLevel,
    required this.strategyLevel,
    required this.calculationLevel,
    required this.readingLevel,
    this.resultType,
    this.mistakeReasons,
  });
}

class LogInputScreen extends StatefulWidget {
  final List<UnitAchievement> units;
  final Question? initialQuestion;

  const LogInputScreen({
    Key? key,
    required this.units,
    this.initialQuestion,
  }) : super(key: key);

  @override
  State<LogInputScreen> createState() => _LogInputScreenState();
}

class _LogInputScreenState extends State<LogInputScreen> with SingleTickerProviderStateMixin {
  String? _selectedSource;
  String? _selectedChapterSection;
  Question? _selectedQuestion;
  String _resultType = 'perfect'; // 'perfect', 'partial', 'defeat'
  final List<String> _selectedReasons = [];
  String? _lastResultText;

  Future<void> _fetchLastResult(String questionId) async {
    try {
      final lastResult = await DatabaseService().getLastResult(questionId);
      if (mounted) {
        setState(() {
          if (lastResult == null) {
            _lastResultText = '初回（未着手）';
          } else if (lastResult.startsWith('partial')) {
            final parts = lastResult.split(':');
            final reasons = parts.length > 1 ? parts[1] : '';
            _lastResultText = '前回結果: △' + (reasons.isNotEmpty ? '（$reasons）' : '');
          } else if (lastResult == 'perfect') {
            _lastResultText = '前回結果: 〇';
          } else if (lastResult == 'defeat') {
            _lastResultText = '前回結果: ✕';
          } else {
            _lastResultText = '前回結果: $lastResult';
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching last result: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialQuestion != null) {
      _selectedQuestion = widget.initialQuestion;
      _fetchLastResult(widget.initialQuestion!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学習ログを入力'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _buildForm(),
      ),
    );
  }

  Widget _buildQuestionSelector() {
    final bool hasSelection = _selectedQuestion != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('取り組んだ問題'),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasSelection ? AppTheme.primaryColor.withOpacity(0.5) : const Color(0xFF334155),
              width: hasSelection ? 1.5 : 1,
            ),
            boxShadow: hasSelection
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final result = await Navigator.push<dynamic>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SourceSelectionScreen(),
                  ),
                );
                if (result != null) {
                  if (result is List<LogInputResult>) {
                    if (mounted) {
                      Navigator.pop(context, result);
                    }
                  } else if (result is Question) {
                    setState(() {
                      _selectedQuestion = result;
                      _lastResultText = null;
                    });
                    _fetchLastResult(result.id);
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: hasSelection 
                            ? AppTheme.primaryColor.withOpacity(0.15) 
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        hasSelection ? Icons.check_circle_outline_rounded : Icons.search_rounded,
                        color: hasSelection ? AppTheme.primaryColor : Colors.white54,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasSelection
                                ? '${_selectedQuestion!.id}: ${_selectedQuestion!.questionNumberAndLabel}'
                                : '問題集から問題を選択',
                            style: TextStyle(
                              color: hasSelection ? Colors.white : Colors.white54,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (hasSelection) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${_selectedQuestion!.source} - ${_selectedQuestion!.chapterSection}',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ] else ...[
                            const SizedBox(height: 4),
                            const Text(
                              'タップして問題を選択してください',
                              style: TextStyle(
                                color: Colors.white30,
                                fontSize: 12,
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                    Icon(
                      hasSelection ? Icons.mode_edit_outline_rounded : Icons.chevron_right_rounded,
                      color: Colors.white38,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionPreview() {
    if (_selectedQuestion == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedQuestion!.source,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            '【${_selectedQuestion!.chapterSection}】 ${_selectedQuestion!.questionNumberAndLabel}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLevelBadge('知識', _selectedQuestion!.knowledgeLevel, AppTheme.knowledgeColor),
              _buildLevelBadge('方針', _selectedQuestion!.strategyLevel, AppTheme.strategyColor),
              _buildLevelBadge('計算', _selectedQuestion!.calculationLevel, AppTheme.calculationColor),
              _buildLevelBadge('読解', _selectedQuestion!.readingLevel, AppTheme.readingColor),
            ],
          ),
          if (_lastResultText != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(color: Color(0xFF334155), height: 16),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _lastResultText == '初回（未着手）'
                        ? Icons.star_border_rounded
                        : _lastResultText!.contains('〇')
                            ? Icons.check_circle_outline_rounded
                            : _lastResultText!.contains('△')
                                ? Icons.help_outline_rounded
                                : Icons.cancel_outlined,
                    color: _lastResultText == '初回（未着手）'
                        ? Colors.white54
                        : _lastResultText!.contains('〇')
                            ? AppTheme.primaryColor
                            : _lastResultText!.contains('△')
                                ? Colors.amberAccent
                                : Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _lastResultText!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLevelBadge(String label, int level, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            'Lv.$level',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildQuestionSelector(),
          _buildQuestionPreview(),
          const SizedBox(height: 24),

          // Result selector (〇 or ✕)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selectedQuestion != null) ...[
                  _buildSectionTitle('結果'),
                  _buildResultSelector(),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),

          // Conditional Cause Analysis (shown only when _resultType is partial)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Column(
              children: [
                if (_resultType == 'partial' && _selectedQuestion != null) ...[
                  _buildSectionTitle('間違えた原因を選択してください（複数選択可）'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        children: ['知識', '方針', '計算', '読解'].map((reason) {
                          final isChecked = _selectedReasons.contains(reason);
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
                            subtitle: Text(
                              reason == '知識'
                                  ? '公式や定義の理解不足'
                                  : reason == '方針'
                                      ? '解法のひらめき・選択ミス'
                                      : reason == '計算'
                                          ? '計算ミス、スピード不足'
                                          : '問題文の誤読・把握ミス',
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedReasons.add(reason);
                                } else {
                                  _selectedReasons.remove(reason);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),

          const SizedBox(height: 40),
          // Save button
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildResultSelector() {
    final bool isEnabled = _selectedQuestion != null;
    final options = [
      {
        'type': 'perfect',
        'label': 'perfect （〇：自力で完璧に解けた）',
        'color': AppTheme.primaryColor,
        'icon': Icons.check_circle_outline_rounded,
      },
      {
        'type': 'partial',
        'label': 'partial （✕：答えが出たが間違えた / 途中で止まった）',
        'color': Colors.amberAccent,
        'icon': Icons.help_outline_rounded,
      },
      {
        'type': 'defeat',
        'label': 'defeat （手も足も出ない・完全敗北）',
        'color': Colors.redAccent,
        'icon': Icons.cancel_outlined,
      },
    ];

    return Column(
      children: options.map((opt) {
        final type = opt['type'] as String;
        final label = opt['label'] as String;
        final color = opt['color'] as Color;
        final icon = opt['icon'] as IconData;
        final isSelected = _resultType == type;

        return GestureDetector(
          onTap: isEnabled ? () => setState(() => _resultType = type) : null,
          child: Opacity(
            opacity: isEnabled ? 1.0 : 0.4,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.15) : AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : const Color(0xFF334155),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: isSelected ? color : Colors.white54,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaveButton() {
    final bool isEnabled = _selectedQuestion != null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: Container(
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
          onPressed: isEnabled ? _submitForm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            '保存する',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _selectedSource = null;
      _selectedChapterSection = null;
      _selectedQuestion = null;
      _resultType = 'perfect';
      _selectedReasons.clear();
      _lastResultText = null;
    });
  }

  void _submitForm() async {
    if (_selectedQuestion != null) {
      final resultType = _resultType;
      final mistakeReasons = List<String>.from(_selectedReasons);

      try {
        await DatabaseService().submitLog(
          question: _selectedQuestion!,
          resultType: resultType,
          mistakeReasons: mistakeReasons,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('保存しました'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          final logResult = LogInputResult(
            unitId: _selectedQuestion!.unitId,
            questionNumber: _selectedQuestion!.questionNumberAndLabel,
            isCorrect: resultType == 'perfect',
            knowledgeLevel: _selectedQuestion!.knowledgeLevel,
            strategyLevel: _selectedQuestion!.strategyLevel,
            calculationLevel: _selectedQuestion!.calculationLevel,
            readingLevel: _selectedQuestion!.readingLevel,
            resultType: resultType,
            mistakeReasons: mistakeReasons,
          );
          if (widget.initialQuestion != null) {
            Navigator.pop(context, logResult);
          } else {
            _resetForm();
          }
        }
      } catch (e) {
        debugPrint('Error saving log to Firestore: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('保存に失敗しました: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}
