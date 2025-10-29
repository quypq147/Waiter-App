import 'package:demodidong/screens/tables/table_screen.dart';
import 'package:flutter/material.dart';
import '../../data/app_repository.dart';
import '../auth/login_screen.dart';
import '../admin/admin_dashboard.dart';
import '../../models/user.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = InheritedApp.of(context);
    return AnimatedBuilder(
      animation: repo,
      builder: (_, __) {
        if (!repo.isLoggedIn) return const LoginScreen();
        if (!repo.isProfileLoaded) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final u = repo.currentUser!;
        return u.role == UserRole.admin
            ? const AdminDashboard()
            : const TableScreen();
      },
    );
  }
}



