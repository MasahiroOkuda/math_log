import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:math_log/core/theme/app_theme.dart';
import 'package:math_log/screens/home_screen.dart';
import 'package:math_log/screens/login_screen.dart';
import 'package:math_log/screens/teacher_dashboard_screen.dart';

class RoleRedirectGate extends StatelessWidget {
  const RoleRedirectGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        // Listen in real-time to the user document to determine the role
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
              );
            }

            // If user snapshot has error or document doesn't exist, fallback to Student (HomeScreen)
            if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const HomeScreen();
            }

            final data = userSnapshot.data!.data();
            final role = data?['role'] as String? ?? 'student';

            if (role == 'teacher') {
              return const TeacherDashboardScreen();
            } else {
              return const HomeScreen();
            }
          },
        );
      },
    );
  }
}
