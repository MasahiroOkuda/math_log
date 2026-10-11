import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question.dart';

class QuestionService {
  static final QuestionService _instance = QuestionService._internal();

  factory QuestionService() => _instance;

  QuestionService._internal();

  List<Question> _questions = [];

  List<Question> get questions => _questions;

  set questions(List<Question> list) {
    _questions = list;
  }

  Future<void> loadQuestions({bool forceReload = false}) async {
    if (_questions.isNotEmpty && !forceReload) return;
    try {
      final snapshot = await FirebaseFirestore.instance.collection('questions').get();
      _questions = snapshot.docs.map((doc) => Question.fromJson(doc.data())).toList();
    } catch (e) {
      // In case of error (e.g. no internet, firebase rules, or unit testing environment),
      // keep existing injected questions list if it is not empty.
    }
  }
}
