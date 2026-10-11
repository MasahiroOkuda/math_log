import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'package:math_log/screens/login_screen.dart';
import 'package:math_log/screens/role_redirect_gate.dart';
import 'services/question_service.dart';
import 'services/workbook_filter_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MathLogApp());
}

class MathLogApp extends StatelessWidget {
  const MathLogApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '数学学習ログ (MathLog)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const RoleRedirectGate(),
    );
  }
}
