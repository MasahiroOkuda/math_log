import 'package:flutter/material.dart';
import 'package:math_log/core/theme/app_theme.dart';
import 'package:math_log/services/question_service.dart';
import 'package:math_log/services/workbook_filter_service.dart';

class WorkbookSelectionScreen extends StatefulWidget {
  const WorkbookSelectionScreen({Key? key}) : super(key: key);

  @override
  State<WorkbookSelectionScreen> createState() => _WorkbookSelectionScreenState();
}

class _WorkbookSelectionScreenState extends State<WorkbookSelectionScreen> {
  final _filterService = WorkbookFilterService();
  final List<String> _allWorkbooks = [];
  final Map<String, int> _workbookQuestionCounts = {};

  @override
  void initState() {
    super.initState();
    _loadWorkbooks();
  }

  void _loadWorkbooks() {
    final questions = QuestionService().questions;
    final Set<String> uniqueSet = {};
    for (var q in questions) {
      if (uniqueSet.add(q.source)) {
        _allWorkbooks.add(q.source);
      }
      _workbookQuestionCounts[q.source] = (_workbookQuestionCounts[q.source] ?? 0) + 1;
    }
    _allWorkbooks.sort();
  }

  void _toggleWorkbook(String name, bool isActive) {
    final current = Set<String>.from(_filterService.activeWorkbooksNotifier.value);
    if (isActive) {
      current.add(name);
    } else {
      current.remove(name);
    }
    _filterService.setActiveWorkbooks(current);
    setState(() {});
  }

  void _selectAll() {
    _filterService.setActiveWorkbooks(_allWorkbooks.toSet());
    setState(() {});
  }

  void _deselectAll() {
    _filterService.setActiveWorkbooks(<String>{});
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('問題集の選択設定'),
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
            // Information Card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'チェックを外した問題集は、ダッシュボードや学習ログの入力、学習履歴の振り返りから除外されます。',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bulk Selection Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectAll,
                      icon: const Icon(Icons.select_all_rounded, size: 18),
                      label: const Text('すべて選択'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF334155)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _deselectAll,
                      icon: const Icon(Icons.deselect_rounded, size: 18),
                      label: const Text('すべて解除'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF334155)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Workbook list
            Expanded(
              child: _allWorkbooks.isEmpty
                  ? const Center(
                      child: Text(
                        '問題集がありません。',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    )
                  : ValueListenableBuilder<Set<String>>(
                      valueListenable: _filterService.activeWorkbooksNotifier,
                      builder: (context, activeWorkbooks, _) {
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          itemCount: _allWorkbooks.length,
                          itemBuilder: (context, index) {
                            final name = _allWorkbooks[index];
                            final isSelected = activeWorkbooks.contains(name);
                            final count = _workbookQuestionCounts[name] ?? 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected 
                                      ? AppTheme.primaryColor.withOpacity(0.5) 
                                      : const Color(0xFF334155),
                                ),
                              ),
                              child: CheckboxListTile(
                                value: isSelected,
                                onChanged: (value) {
                                  if (value != null) {
                                    _toggleWorkbook(name, value);
                                  }
                                },
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    '$count 問収録',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                activeColor: AppTheme.primaryColor,
                                checkColor: Colors.white,
                                controlAffinity: ListTileControlAffinity.trailing,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
