import 'package:flutter/material.dart';
import 'package:math_log/core/theme/app_theme.dart';
import 'package:math_log/models/question.dart';
import 'package:math_log/services/question_service.dart';
import 'package:math_log/services/workbook_filter_service.dart';
import 'package:math_log/screens/chapter_selection_screen.dart';

class SourceSelectionScreen extends StatelessWidget {
  const SourceSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final questions = QuestionService().questions;
    
    // Extract unique sources in order of appearance
    final Set<String> uniqueSourcesSet = {};
    final List<String> sources = [];
    for (var q in questions) {
      if (uniqueSourcesSet.add(q.source) && WorkbookFilterService().isActive(q.source)) {
        sources.add(q.source);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('問題集を選択'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: sources.isEmpty
            ? const Center(
                child: Text(
                  '問題集データがありません。',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: sources.length,
                itemBuilder: (context, index) {
                  final source = sources[index];
                  final questionCount = questions.where((q) => q.source == source).length;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final result = await Navigator.push<dynamic>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChapterSelectionScreen(source: source),
                            ),
                          );
                          if (result != null && context.mounted) {
                            Navigator.pop(context, result);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.menu_book_rounded,
                                  color: AppTheme.primaryColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      source,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '$questionCount 問収録',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white38,
                                size: 24,
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
