import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/question.dart';

class DatabaseService {
  static DatabaseService _instance = DatabaseService.internal();

  factory DatabaseService() => _instance;

  // Internal constructor for singleton and subclassing in testing
  DatabaseService.internal();

  // Allow overriding the instance in tests
  static set instance(DatabaseService mockInstance) {
    _instance = mockInstance;
  }

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => FirebaseAuth.instance.authStateChanges();
  User? get currentUser => FirebaseAuth.instance.currentUser;

  Future<void> signOut() => FirebaseAuth.instance.signOut();

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) {
    return FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
    final user = credential.user;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email ?? '',
        'role': 'student',
        'ratings': {},
        'last_played_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return credential;
  }

  Future<void> submitLog({
    required Question question,
    required String resultType,
    required List<String> mistakeReasons,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('User must be logged in to submit learning logs.');
    }
    final uid = user.uid;

    final questionId = question.id;
    final unitId = question.unitId;

    // 1. Add log to 'logs' collection
    await _firestore.collection('logs').add({
      'questionId': questionId,
      'unitId': unitId,
      'resultType': resultType,
      'mistakeReasons': mistakeReasons,
      'createdAt': FieldValue.serverTimestamp(),
      'uid': uid,
    });

    // 2. Fetch or create users/[uid] document
    final userDocRef = _firestore.collection('users').doc(uid);
    final userDoc = await userDocRef.get();

    Map<String, dynamic> ratings;
    bool exists = userDoc.exists;
    if (!exists) {
      ratings = {};
      for (int i = 1; i <= 48; i++) {
        final unitIdStr = 'U-${i.toString().padLeft(2, '0')}';
        ratings[unitIdStr] = {
          'knowledge': 500,
          'strategy': 500,
          'calculation': 500,
          'reading': 500,
        };
      }
    } else {
      final data = userDoc.data();
      ratings = data?['ratings'] as Map<String, dynamic>? ?? {};
    }

    // 3. Get or initialize the specific unit's ratings
    final unitRating = ratings[unitId] as Map<String, dynamic>? ?? {
      'knowledge': 500,
      'strategy': 500,
      'calculation': 500,
      'reading': 500,
    };

    int currentKnowledge = (unitRating['knowledge'] as num?)?.toInt() ?? 500;
    int currentStrategy = (unitRating['strategy'] as num?)?.toInt() ?? 500;
    int currentCalculation = (unitRating['calculation'] as num?)?.toInt() ?? 500;
    int currentReading = (unitRating['reading'] as num?)?.toInt() ?? 500;

    // Helper to get anchor rate based on level
    double getAnchorRate(int level) {
      switch (level) {
        case 1: return 1000.0;
        case 2: return 1200.0;
        case 3: return 1500.0;
        case 4: return 1900.0;
        default: return 1000.0;
      }
    }

    final double anchorKnowledge = getAnchorRate(question.knowledgeLevel);
    final double anchorStrategy = getAnchorRate(question.strategyLevel);
    final double anchorCalculation = getAnchorRate(question.calculationLevel);
    final double anchorReading = getAnchorRate(question.readingLevel);

    // K-factors
    const double kKnowledge = 40.0;
    const double kStrategy = 40.0;
    const double kReading = 20.0;
    const double kCalculation = 10.0;

    // Expected scores (expectedScore = 1.0 / (1.0 + pow(10.0, (anchorRate - userCurrentRate) / 400.0)))
    final double expKnowledge = 1.0 / (1.0 + math.pow(10.0, (anchorKnowledge - currentKnowledge) / 400.0));
    final double expStrategy = 1.0 / (1.0 + math.pow(10.0, (anchorStrategy - currentStrategy) / 400.0));
    final double expCalculation = 1.0 / (1.0 + math.pow(10.0, (anchorCalculation - currentCalculation) / 400.0));
    final double expReading = 1.0 / (1.0 + math.pow(10.0, (anchorReading - currentReading) / 400.0));

    // W (Actual Outcomes)
    double wKnowledge;
    double wStrategy;
    double wCalculation;
    double wReading;

    if (resultType == 'perfect') {
      wKnowledge = 1.0;
      wStrategy = 1.0;
      wCalculation = 1.0;
      wReading = 1.0;
    } else if (resultType == 'defeat') {
      wKnowledge = 0.0;
      wStrategy = 0.0;
      wCalculation = 0.0;
      wReading = 0.0;
    } else { // partial
      wKnowledge = mistakeReasons.contains('知識') ? 0.0 : 1.0;
      wStrategy = mistakeReasons.contains('方針') ? 0.0 : 1.0;
      wCalculation = mistakeReasons.contains('計算') ? 0.0 : 1.0;
      wReading = mistakeReasons.contains('読解') ? 0.0 : 1.0;
    }

    // Calculate new ratings (newRate = userCurrentRate + (kFactor * (W - expectedScore)))
    final int newKnowledge = (currentKnowledge + (kKnowledge * (wKnowledge - expKnowledge))).round();
    final int newStrategy = (currentStrategy + (kStrategy * (wStrategy - expStrategy))).round();
    final int newCalculation = (currentCalculation + (kCalculation * (wCalculation - expCalculation))).round();
    final int newReading = (currentReading + (kReading * (wReading - expReading))).round();

    final updatedUnitRating = {
      'knowledge': newKnowledge,
      'strategy': newStrategy,
      'calculation': newCalculation,
      'reading': newReading,
    };

    if (!exists) {
      ratings[unitId] = updatedUnitRating;
      await userDocRef.set({
        'ratings': ratings,
        'last_played_at': FieldValue.serverTimestamp(),
      });
    } else {
      await userDocRef.update({
        'ratings.$unitId': updatedUnitRating,
        'last_played_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<String?> getLastResult(String questionId, {String? uid}) async {
    final targetUid = uid ?? currentUser?.uid;
    if (targetUid == null) {
      throw StateError('No UID available to get last results.');
    }

    final snapshot = await _firestore
        .collection('logs')
        .where('uid', isEqualTo: targetUid)
        .where('questionId', isEqualTo: questionId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final data = snapshot.docs.first.data();
    final resultType = data['resultType'] as String?;
    if (resultType == 'partial') {
      final reasons = List<String>.from(data['mistakeReasons'] ?? []);
      if (reasons.isNotEmpty) {
        return '$resultType:${reasons.join(',')}';
      }
    }
    return resultType;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getRatingsStream({String? uid}) {
    final targetUid = uid ?? currentUser?.uid;
    if (targetUid == null) {
      return Stream.error(StateError('No UID available to stream ratings.'));
    }
    return _firestore.collection('users').doc(targetUid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getLogsStream({String? uid}) {
    final targetUid = uid ?? currentUser?.uid;
    if (targetUid == null) {
      return Stream.error(StateError('No UID available to stream logs.'));
    }
    return _firestore
        .collection('logs')
        .where('uid', isEqualTo: targetUid)
        .snapshots();
  }

  Future<void> submitBatchLogs(List<BatchLogItem> items) async {
    // Sort in ascending order of Question ID
    items.sort((a, b) => a.question.id.compareTo(b.question.id));

    for (final item in items) {
      await submitLog(
        question: item.question,
        resultType: item.resultType,
        mistakeReasons: item.mistakeReasons,
      );
    }
  }
}

class BatchLogItem {
  final Question question;
  final String resultType;
  final List<String> mistakeReasons;

  BatchLogItem({
    required this.question,
    required this.resultType,
    required this.mistakeReasons,
  });
}
