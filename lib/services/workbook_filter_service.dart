import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:math_log/services/question_service.dart';
import 'package:math_log/models/question.dart';

class WorkbookFilterService {
  static final WorkbookFilterService _instance = WorkbookFilterService._internal();

  factory WorkbookFilterService() => _instance;

  WorkbookFilterService._internal();

  static const String _storageKey = 'active_workbooks';

  final ValueNotifier<Set<String>> activeWorkbooksNotifier = ValueNotifier<Set<String>>({});

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_storageKey);

    // Ensure questions are loaded
    await QuestionService().loadQuestions();
    final allWorkbooks = QuestionService().questions.map((q) => q.source).toSet();

    if (list == null) {
      // First time launch: default to all workbooks active
      activeWorkbooksNotifier.value = allWorkbooks;
      await prefs.setStringList(_storageKey, allWorkbooks.toList());
    } else {
      // Filter the saved list to only include workbooks that currently exist in QuestionService
      final active = list.toSet().intersection(allWorkbooks);
      activeWorkbooksNotifier.value = active;
    }
  }

  Future<void> setActiveWorkbooks(Set<String> workbooks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, workbooks.toList());
    activeWorkbooksNotifier.value = workbooks;
  }

  bool isActive(String workbookName) {
    return activeWorkbooksNotifier.value.contains(workbookName);
  }

  List<Question> filterQuestions(List<Question> questions) {
    final active = activeWorkbooksNotifier.value;
    return questions.where((q) => active.contains(q.source)).toList();
  }
}
