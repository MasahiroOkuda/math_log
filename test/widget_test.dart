// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:math_log/main.dart';
import 'package:math_log/models/question.dart';
import 'package:math_log/services/database_service.dart';
import 'package:math_log/services/question_service.dart';

class FakeUser extends Fake implements User {
  @override
  String get uid => 'student_test_01';

  @override
  String get email => 'test@example.com';
}

class FakeUserCredential extends Fake implements UserCredential {
  @override
  User? get user => FakeUser();
}

class FakeDocumentSnapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  bool get exists => true;

  @override
  Map<String, dynamic>? data() => {
    'ratings': {
      'U-01': {
        'knowledge': 500,
        'strategy': 500,
        'calculation': 500,
        'reading': 500,
      }
    }
  };
}

class FakeQuerySnapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
}

class FakeDatabaseService extends DatabaseService {
  FakeDatabaseService() : super.internal();

  @override
  Stream<User?> get authStateChanges => Stream.value(FakeUser());

  @override
  User? get currentUser => FakeUser();

  @override
  Future<void> signOut() async {}

  @override
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    return FakeUserCredential();
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    return FakeUserCredential();
  }

  @override
  Future<void> submitLog({
    required Question question,
    required String resultType,
    required List<String> mistakeReasons,
  }) async {
    // Fake implementation that does nothing
  }

  @override
  Future<String?> getLastResult(String questionId) async {
    return null;
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> getRatingsStream() {
    return Stream.value(FakeDocumentSnapshot());
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> getLogsStream() {
    return Stream.value(FakeQuerySnapshot());
  }
}

class MockAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    String content = '';
    if (key == 'assets/units.json') {
      content = json.encode([
        {
          "id": "U-01",
          "name": "展開・因数分解と実数"
        }
      ]);
    } else {
      throw ArgumentError('Unknown asset: $key');
    }
    
    return ByteData.view(Uint8List.fromList(utf8.encode(content)).buffer);
  }
}

void main() {
  DatabaseService.instance = FakeDatabaseService();
  QuestionService().questions = [
    Question(
      id: 'A-001_1',
      chapterSection: '第01章 数と式',
      questionNumberAndLabel: '001(1)-(2)',
      source: '大学入試 全レベル問題集 数学I+A+II+B+ベクトル 1 基礎レベル 改訂版',
      unitId: 'U-01',
      knowledgeLevel: 1,
      strategyLevel: 1,
      calculationLevel: 2,
      readingLevel: 1,
      difficultyTag: 1,
    ),
  ];

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame with MockAssetBundle.
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: MockAssetBundle(),
        child: const MathLogApp(),
      ),
    );

    // Verify that our math dashboard elements are present.
    expect(find.text('数学学習ダッシュボード'), findsOneWidget);
    expect(find.text('進行中の問題集'), findsOneWidget);

    // Wait for assets to load and button to become active
    await tester.pumpAndSettle();

    // Tap the '学習ログを入力する' button.
    final buttonFinder = find.text('学習ログを入力する');
    expect(buttonFinder, findsOneWidget);
    await tester.tap(buttonFinder);
    
    // Wait for the slide transition to LogInputScreen to finish.
    await tester.pumpAndSettle();

    // Verify that the LogInputScreen elements are shown correctly.
    expect(find.text('取り組んだ問題'), findsOneWidget);
    expect(find.text('問題集から問題を選択'), findsOneWidget);
    expect(find.text('結果'), findsNothing);

    // Tap the selector to open SourceSelectionScreen.
    await tester.tap(find.text('問題集から問題を選択'));
    await tester.pumpAndSettle();

    // Verify SourceSelectionScreen is displayed, tap the source book.
    expect(find.text('問題集を選択'), findsOneWidget);
    final sourceFinder = find.text('大学入試 全レベル問題集 数学I+A+II+B+ベクトル 1 基礎レベル 改訂版');
    expect(sourceFinder, findsOneWidget);
    await tester.tap(sourceFinder);
    await tester.pumpAndSettle();

    // Verify ChapterSelectionScreen is displayed, tap the chapter.
    expect(find.text('章・セクションを選択'), findsOneWidget);
    final chapterFinder = find.text('第01章 数と式');
    expect(chapterFinder, findsOneWidget);
    await tester.tap(chapterFinder);
    await tester.pumpAndSettle();

    // Verify QuestionSelectionScreen is displayed, tap the question.
    expect(find.text('問題を選択'), findsOneWidget);
    final questionFinder = find.text('001(1)-(2)');
    expect(questionFinder, findsOneWidget);
    await tester.tap(questionFinder);
    await tester.pumpAndSettle();

    // Verify we are back on LogInputScreen and selected question details are displayed.
    expect(find.text('A-001_1: 001(1)-(2)'), findsOneWidget);

    // Verify level preview is shown.
    expect(find.text('Lv.1'), findsNWidgets(3));
    expect(find.text('Lv.2'), findsOneWidget);

    expect(find.text('結果'), findsOneWidget);

    // Dynamic cause analysis section should NOT be visible initially.
    expect(find.text('間違えた原因を選択してください（複数選択可）'), findsNothing);

    // Tap on 'partial （✕：答えが出たが間違えた / 途中で止まった）' to show cause analysis.
    final partialBtnFinder = find.text('partial （✕：答えが出たが間違えた / 途中で止まった）');
    expect(partialBtnFinder, findsOneWidget);
    await tester.tap(partialBtnFinder);
    
    // Wait for AnimatedSize animation to complete
    await tester.pumpAndSettle();

    // Now reasons section should be visible.
    expect(find.text('間違えた原因を選択してください（複数選択可）'), findsOneWidget);
    expect(find.text('知識'), findsNWidgets(2));

    // Tap '保存する' button.
    final saveBtnFinder = find.text('保存する');
    expect(saveBtnFinder, findsOneWidget);
    await tester.ensureVisible(saveBtnFinder);
    await tester.pumpAndSettle();
    await tester.tap(saveBtnFinder);

    // Wait for navigation and snackbar animation.
    await tester.pumpAndSettle();

    // Verify snackbar is visible on the input screen.
    expect(find.text('保存しました'), findsOneWidget);

    // Tap back button to go back to the homepage.
    final backBtnFinder = find.byIcon(Icons.arrow_back_ios_new_rounded);
    expect(backBtnFinder, findsOneWidget);
    await tester.tap(backBtnFinder);
    
    // Wait for the transition to finish.
    await tester.pumpAndSettle();

    // Verify we are back on the homepage.
    expect(find.text('数学学習ダッシュボード'), findsOneWidget);
  });
}
